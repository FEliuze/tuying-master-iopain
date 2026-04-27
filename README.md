# IOPaint 独立服务

与仓库内 `tools/`（Flask）**分开部署**在同一微信云托管环境，减轻主 tools 镜像体积与构建时间。

## 与 Node / tools 的协作关系

- **不新增消息队列**：仍由 **Node Worker** 调 `TOOLS_BASE_URL`（Flask `POST /internal/process`），业务逻辑不变。
- **Flask** 在 AI 修图等流程里用 HTTP 调本服务：`${IOPAINT_BASE_URL}/api/v1/...`。
- 在 **tuying-tools 云托管服务** 环境变量中配置：`IOPAINT_BASE_URL=https://<本服务在控制台显示的访问域名>`（**无尾斜杠**），且 **同机** 起 IOPaint 时可删或设 `IOPAINT_ENABLED=0`。

## 构建与发布

在云托管中新建服务，**构建目录**选本目录（仅含本 Dockerfile 即可，无需拷贝整个 monorepo 时可将本目录单独上传/子模块）；或与主仓库同源时**构建子目录**指定为 `iopaint-service`（以控制台是否支持「子目录 Docker」为准；不支持则只上传本目录）。

Dockerfile 为**多阶段**：**默认**用 PyPI 装 `iopaint`（**无需** `iopaint-offline.tar.gz`），避免云构建报 `not found`。**离线包**：用 `scripts/package-offline.sh` 生成且小于 100MB 的 `iopaint-offline.tar.gz` 后，以 `docker build --target offline` 构建，或在云托管中把**构建目标**设为 `offline`。**勿**把 `torch-*.whl` 等大文件提交进 Git。若**构建仍超时**，请调大构建时限/资源，或本机打镜像后推 TCR/CCR。

## 健康检查

`GET /api/v1/server-config` 返回 200 即就绪。首次拉模型可能较久，探活需适当超时。

**微信云托管 / 默认识别端口**：平台常对容器的 **:80** 做 **TCP 存活/就绪** 探测。本镜像 **默认 `PORT=80`、EXPOSE 80**（`docker-entrypoint.sh` 中 `iopaint` 监听 `0.0.0.0:$PORT`），与默认识别一致。若你改为 **8080**，须同时在控制台将 **容器端口、健康检查端口** 改为 **8080**，**或** 仅设环境变量 **`PORT=80`** 保持与平台默认识别一致。

**若日志里仍出现 `socat` 连 `127.0.0.1:8080`**：说明**还有实例在跑旧镜像**（曾用 socat 转发）；**当前仓库**已不再使用 socat。请**全量发布新镜像**并结束旧版本/旧 Pod，避免混跑。首启阶段若插件在拉权重，旧方案下会长时间 **Connection refused**；本仓库已在构建中预拉 **lama、Bria RMBG、Real-ESRGAN realesr-general-x4v3** 等以缩短该窗口；**GFPGAN、RestoreFormer** 等若仍首下，可再收紧 `--enable-*` 或按同样方式预置权重。

## 部署排错：云托管「云端调试」里 /api/v1/server-config 为 404

`iopaint start` 启动的 FastAPI 应用**确实注册**了 `GET /api/v1/server-config`（与「接口不存在」无矛盾时，问题在**请求没进到 IOPaint 进程**或**路径写错**）。请按序核对：

1. **路径只写相对服务根的一截**：在「路径」里填 **`/api/v1/server-config`**（**以 `/` 开头**），不要带域名、不要多写一段如 `/flask-xxx`、不要少写 `/v1`。
2. **根地址与当前 IOPaint 服务一致**：调试目标必须是**本 IOPaint 云托管服务**控制台里展示的**访问域名**；若用错成 **tuying-tools / 其它服务** 的根，必然 404（那些不是 IOPaint API）。
3. **确认进程是 `iopaint start`**：服务「启动命令」是否被平台覆盖成 `gunicorn` / 样例应用；应使用镜像内默认命令或等价 `iopaint start --host=0.0.0.0 --port=$PORT ...`。查看**运行日志**中是否有 **uvicorn** 监听、请求进入时是否出现 `GET /api/v1/...`。
4. **对比验证**：同一域名在浏览器或 `curl` 访问 `https://<域名>/docs`（FastAPI 文档页）。若 **`/docs` 能 200** 而仅某路径 404，再查路径是否拼写错误；若 **`/docs` 也 404**，则流量未到 IOPaint 或根 URL 不是该服务。
5. **备用探活路径**：`GET /api/v1/model` 在正式 IOPaint 中同样为 **200**；tuying-tools 侧已支持多路径探活（见 `tools` 中 `IOPAINT_PROBE_PATHS`）。

## 部署排错：tuying-tools 探活 `HTTP 404`（/api/v1/server-config）

说明对方进程**不是** IOPaint 1.3+ 的 HTTP API。常见原因：曾用仅含旧命令 `lama-cleaner` 的社区镜像，其路由与 `tools` 中 `iopaint>=1.3` 的 `/api/v1/*` 不兼容。请**按本目录当前 Dockerfile 重建**（`iopaint start`），并确保 `IOPAINT_BASE_URL` 指向该服务，而非其他 Flask/静态站点。

本镜像在预装 PyTorch 的底包上 `pip install iopaint`；与「纯 slim + 全量 pip 装 torch」相比，**构建阶段**明显更短。若 pip 因版本约束仍升级 torch，可在控制台**调大构建超时**，或改成本地打镜像后推送。

## 部署排错：Readiness / Liveness `connection refused: dial ... :80`（或 :8080）

**（1）探针端口与 `PORT` 不一致**（最常见）：日志如 `dial tcp ... :80: connection refused`，而应用实际监听 **8080**（或相反）。**处理**：在控制台将 **容器端口、存活/就绪探测端口** 与镜像 **`PORT` 环境变量** 三处对齐；或**不设自定义**时保持镜像默认 **`PORT=80`** 与平台默认识别。

**（2）首启未就绪**：探针在连的是正确 `PORT`，但 **iopaint 尚未 `listen`（首启、拉模型很慢）**，也会 **connection refused**。

**本仓库**：`docker-entrypoint.sh` 用 **`iopaint start --host=0.0.0.0 --port=$PORT`**，默认 **`PORT=80`**。

**若使用 HTTP/路径类探活**（如 `GET /api/v1/server-config`）：须等 **iopaint** 在 `PORT` 上就绪，必要时**拉长 initialDelay/超时**。

**若探活仍失败**：看运行日志里 **uvicorn** 是否已报监听、**iopaint** 是否报错或 OOM。

## 部署排错：HTTP 502（首启拉模型或插件权重未就绪）

- **与 pip 没装完无关**；多数情况是：**默认擦除模型（lama 等）或某插件权重在首次拉取完之前**，Uvicorn **尚未**在 **`PORT`** 上 `listen`，网关侧可能 **502**。
- **本仓库 Dockerfile 已在构建阶段**用 `XDG_CACHE_HOME`（固定为 `/opt/iopaint-cache`）**预拉 lama**，使容器启动后尽量**很快**可连、减轻长时间 502。
- 若日志里**仍有**大体积进度条（`196M/196M` 等）且 502 持续较久：多为 **`docker-entrypoint.sh` 中开启的扩图/去背景等插件**（`--enable-realesrgan` 等）在**首启**时继续下载权重。可**等待**完成，或**按需**收紧入口脚本里的 `--enable-*` 以换首启时间（会牺牲对应能力，请与业务需求权衡）。
- 若出现 **`ModuleNotFoundError: No module named 'rembg'`**：入口脚本启用了 **`--enable-remove-bg`**，需在镜像里 **`pip install onnxruntime rembg`**（本仓库 Dockerfile 已包含）；勿依赖 iopaint 主包自动装上全部可选依赖。
- 若启动时 **`huggingface.co`、Connection、Network is unreachable、`briaai/RMBG-1.4/.../model.pth`**：默认识别 RemoveBG 会**向 HuggingFace 拉 Bria 模型**；**运行实例无外网/不能访问 HF** 时会失败。本仓库已在**构建阶段**用 **`HF_HOME=/opt/iopaint-cache/huggingface`** 预下该文件；请**重新构建并发布**镜像。若**构建机**也拉不到，可在构建时设 **`HF_ENDPOINT`**（如国内 HF 镜像）或本机有网打镜像后推 TCR。其它插件（Real-ESRGAN 等）首次调用仍可能下权重，可等待或关对应 `--enable-*`。
- 云构建/运行需能拉取**构建阶段**所依赖的模型；**完全无外网**时改自制离线层或关插件。

## 资源

建议 CPU/内存配足；GPU 时可将 `IOPAINT_DEVICE` 等改为 `cuda`（需平台支持并自行评估镜像）。

## 无容器 Shell 时如何确认服务

免费版云托管常不能 `exec` 进容器。可用：

- **运行日志 / 标准输出**：`iopaint`/uvicorn 的日志在控制台**实例/运行日志**中查看；确认无崩溃且已报告监听地址。
- **公网自测**：本机浏览器或 `curl` 访问 `https://<服务域名>/docs`、`/api/v1/server-config`（需已开放公网并配置合法域名，或先关域名校验）。
- **与 tuying-tools 同 VPC 时**：在 tools 里配对的 `IOPAINT_BASE_URL` 能通即表示网络可达（仍须 URL 指到 **IOPint 服务** 的根域名）。
