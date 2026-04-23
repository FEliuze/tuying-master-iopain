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

## 部署排错：Readiness `connection refused`

进程监听端口 = 环境变量 **`PORT`**（镜像默认 **80**；若平台注入 `PORT=8080` 则以注入为准）。**探活/服务端口**须与之一致：若探活连 **80** 而进程只在 **8080** 监听（或相反），会出现 `connection refused`。在控制台统一 **容器端口、健康检查端口、环境变量 PORT**。

## 资源

建议 CPU/内存配足；GPU 时可将 `IOPAINT_DEVICE` 等改为 `cuda`（需平台支持并自行评估镜像）。

## 无容器 Shell 时如何确认服务

免费版云托管常不能 `exec` 进容器。可用：

- **运行日志 / 标准输出**：镜像内 `docker-entrypoint.sh` 启动时会打印 `PORT`、包版本与探活路径说明，部署后在控制台看**实例日志**即可。
- **公网自测**：本机浏览器或 `curl` 访问 `https://<服务域名>/docs`、`/api/v1/server-config`（需已开放公网并配置合法域名，或先关域名校验）。
- **与 tuying-tools 同 VPC 时**：在 tools 里配对的 `IOPAINT_BASE_URL` 能通即表示网络可达（仍须 URL 指到 **IOPint 服务** 的根域名）。
