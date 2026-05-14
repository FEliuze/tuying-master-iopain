# IOPaint 独立服务

把 IOPaint 从 `tools/`（Flask）剥离出来 **独立部署在同一微信云托管环境**，专门跑 LaMa / RMBG / Real-ESRGAN / GFPGAN / RestoreFormer 等模型，减轻主 `tools` 镜像体积与构建时间，也便于按需独立扩容 / 切 GPU。

> 仓库内同时存在 [`iopaint-service-wx-cloud/`](../iopaint-service-wx-cloud)：默认与本目录同源；当云托管侧需要不同的 Dockerfile / 端口 / 启动命令时，作为「微信云托管副本」单独维护即可。**二选一**部署，不要同时跑两份占资源。

## 服务边界

| 责任方 | 行为 |
| --- | --- |
| `service`（Node） | 不直接访问 IOPaint；只编排 `async_jobs` 与解锁凭据 |
| `tools`（Python Flask） | **唯一调用方**：在 AI 修图任务里通过 `${IOPAINT_BASE_URL}/api/v1/...` 调本服务 |
| `iopaint-service`（本目录） | 跑 IOPaint HTTP（基于 FastAPI），提供 `/api/v1/*` 推理接口 |

环境变量约定（在 **tuying-tools 云托管服务** 上配置）：

```
IOPAINT_BASE_URL=https://<本服务在控制台显示的访问域名>   # 无尾斜杠
IOPAINT_ENABLED=0                                          # 同机起 IOPaint 时关闭以避端口冲突
```

## 健康检查 / 端口约定

- **探活路径**：`GET /api/v1/server-config` 返回 200 即就绪；备选 `GET /api/v1/model`、`GET /docs`（FastAPI 文档页）。
- **首次拉模型可能较久**，探针请适当拉长 `initialDelay` / 超时。
- **微信云托管默认识别端口**：平台常对容器的 **:80** 做 TCP 存活 / 就绪探测。本镜像 **默认 `PORT=80`、EXPOSE 80**（`docker-entrypoint.sh` 中 `iopaint` 监听 `0.0.0.0:$PORT`），与平台默认一致。
- 若你改为 **8080**，须同时在控制台将 **容器端口、健康检查端口** 改为 8080，**或** 仅设环境变量 **`PORT=80`** 保持与平台默认识别一致。

## 资源建议

- CPU / 内存配足；GPU 时把 `IOPAINT_DEVICE` 等改为 `cuda`（需平台支持并自行评估镜像）。
- 仅 CPU 时建议至少 **4 vCPU / 8 GB**；并发处理多模型链时再上浮。

## 构建与发布

在云托管中新建服务，**构建目录**选本目录（仅含本 Dockerfile 即可，无需拷贝整个 monorepo 时可将本目录单独上传 / 子模块）；或与主仓库同源时**构建子目录**指定为 `iopaint-service`（以控制台是否支持「子目录 Docker」为准；不支持则只上传本目录）。

Dockerfile 为**多阶段**：

- **默认**：用 PyPI 装 `iopaint`（**无需** `iopaint-offline.tar.gz`），避免云构建报 `not found`。
- **离线包**：用 `scripts/package-offline.sh` 生成且小于 100 MB 的 `iopaint-offline.tar.gz` 后，以 `docker build --target offline` 构建，或在云托管中把**构建目标**设为 `offline`。**勿**把 `torch-*.whl` 等大文件提交进 Git。

若**构建仍超时**，请调大构建时限/资源，或本机打镜像后推 TCR/CCR。

## 本地 Docker 启动

```bash
docker build -t iopaint-service:local .
docker run --rm -p 18081:80 --name iopaint-local iopaint-service:local
```

## 本地 HTTPS 反代联调

```bash
cloudflared tunnel --url http://localhost:18081
# 拿到 https://xxx.trycloudflare.com 后，修改 service 与 tools 中的 IOPAINT_BASE_URL
```

## 使用预构建的 Docker 镜像

### 推到腾讯云 TCR

腾讯云容器镜像服务（TCR）个人版，先在 [console.cloud.tencent.com/tcr/namespace](https://console.cloud.tencent.com/tcr/namespace) 新建命名空间（例：`tcb-100048124295-trcc`），再查看；服务名（例：`flask-1g8z`）来自云托管服务列表。

```bash
docker tag iopaint-local:latest ccr.ccs.tencentyun.com/<命名空间>/<服务名>:latest
docker login ccr.ccs.tencentyun.com --username=<腾讯云账号>
docker push        ccr.ccs.tencentyun.com/<命名空间>/<服务名>:latest
```

在微信云托管选择「镜像仓库」部署。

### **推荐**：使用 Docker Hub 等公共仓库

把 IOPaint 镜像推到 **Docker Hub 公共仓库**，再让微信云托管 / 其他平台直接 **从公网地址拉取** 部署，绕开「构建超时 / 私有仓库授权」等问题。

```bash
# 1) 登录 Docker Hub（首次需要；登录态存在 ~/.docker/config.json）
docker login

# 2) 浏览器登录 Docker Hub 控制台，新建一个 Public 仓库，例如 iopaint-service-tuying
```

```bash
# 3) 给本地镜像打远端 tag 并推送
docker tag iopaint-service:local <用户名>/<仓库名>:latest
docker push <用户名>/<仓库名>:latest
```

在微信云托管「**从地址拉取镜像**」部署：

- 镜像地址：`docker.io/<用户名>/<仓库名>:latest`
- **容器端口**：`80`（与镜像 `EXPOSE 80` / 默认 `PORT=80` 对齐）

### 跨架构镜像（推荐：buildx 一次推 amd64 + arm64）

> 微信云托管节点多为 **linux/amd64**；Apple Silicon（arm64）用 `docker build` 直接推上去的镜像在云端会因架构不一致跑不起来。

```bash
docker buildx rm mybuilder        # 可选清理
docker buildx create --name mybuilder --driver docker-container --use
docker buildx inspect --bootstrap

cd iopaint-service
docker buildx build --platform linux/amd64,linux/arm64 \
  -t <用户名>/<仓库名>:latest \
  --push .
```

完成后回到云托管，选「**从地址拉取镜像**」并重新部署即可；后续更新代码 → 重跑上面命令 → 控制台「重新部署」。

---

## 部署排错

> 以下排错条目均为线上踩坑实录，按现象分类。

### 1）云托管「云端调试」`/api/v1/server-config` 返回 404

`iopaint start` 启动的 FastAPI 应用**确实注册**了 `GET /api/v1/server-config`；返回 404 通常是**请求没进到 IOPaint 进程**或**路径写错**。按序核对：

1. **路径只写相对服务根的一截**：在「路径」里填 **`/api/v1/server-config`**（以 `/` 开头），不要带域名、不要多写一段如 `/flask-xxx`、不要少写 `/v1`。
2. **根地址与当前 IOPaint 服务一致**：调试目标必须是 **本 IOPaint 云托管服务** 控制台里的访问域名；用错成 tuying-tools / 其它服务的根，必然 404。
3. **确认进程是 `iopaint start`**：服务「启动命令」是否被平台覆盖成 `gunicorn` / 样例应用；应使用镜像内默认命令或等价 `iopaint start --host=0.0.0.0 --port=$PORT ...`。查看**运行日志**是否有 **uvicorn** 监听、请求是否出现 `GET /api/v1/...`。
4. **对比验证**：同一域名访问 `https://<域名>/docs`（FastAPI 文档页）。若 `/docs` 能 200 而仅某路径 404，再查路径拼写；若 `/docs` 也 404，则流量未到 IOPaint 或根 URL 不是该服务。
5. **备用探活路径**：`GET /api/v1/model` 在正式 IOPaint 中同样为 200；tuying-tools 侧已支持多路径探活（见 `tools` 中 `IOPAINT_PROBE_PATHS`）。

### 2）tuying-tools 探活报 `HTTP 404`（/api/v1/server-config）

说明对方进程**不是** IOPaint 1.3+ 的 HTTP API。常见原因：曾用仅含旧命令 `lama-cleaner` 的社区镜像，其路由与 `iopaint>=1.3` 的 `/api/v1/*` 不兼容。请**按本目录当前 Dockerfile 重建**（`iopaint start`），并确保 `IOPAINT_BASE_URL` 指向该服务，而非其他 Flask / 静态站点。

本镜像在预装 PyTorch 的底包上 `pip install iopaint`；与「纯 slim + 全量 pip 装 torch」相比，**构建阶段**明显更短。若 pip 因版本约束仍升级 torch，可在控制台**调大构建超时**，或改成本地打镜像后推送。

### 3）`socat` 日志：连 `127.0.0.1:8080`

说明**还有实例在跑旧镜像**（曾用 socat 转发）；**当前仓库**已不再使用 socat。请**全量发布新镜像**并结束旧版本 / 旧 Pod，避免混跑。

首启阶段若插件在拉权重，旧方案下会长时间 **Connection refused**；本仓库已在构建中预拉 **LaMa、Bria RMBG、Real-ESRGAN realesr-general-x4v3** 等以缩短该窗口；**GFPGAN / RestoreFormer** 等若仍首下，可再收紧 `--enable-*` 或按同样方式预置权重。

### 4）Readiness / Liveness `connection refused: dial ... :80`（或 :8080）

- **探针端口与 `PORT` 不一致**（最常见）：日志如 `dial tcp ... :80: connection refused`，但应用实际监听 8080（或相反）。**处理**：在控制台将 **容器端口、存活 / 就绪探测端口** 与镜像 **`PORT` 环境变量** 三处对齐；或保持镜像默认 `PORT=80` 与平台默认识别。
- **首启未就绪**：探针在连正确 `PORT`，但 **iopaint 尚未 `listen`（拉模型很慢）**，也会 connection refused。

本仓库 `docker-entrypoint.sh` 用 **`iopaint start --host=0.0.0.0 --port=$PORT`**，默认 **`PORT=80`**。**HTTP / 路径类探活**（如 `GET /api/v1/server-config`）须等 iopaint 在 `PORT` 上就绪，必要时**拉长 initialDelay / 超时**。

### 5）HTTP 502（首启拉模型或插件权重未就绪）

- **与 pip 没装完无关**；多数情况是默认擦除模型（LaMa 等）或某插件权重在首次拉取完之前，Uvicorn 尚未在 `PORT` 上 `listen`，网关侧可能 502。
- 本仓库 Dockerfile 已在构建阶段用 `XDG_CACHE_HOME=/opt/iopaint-cache` **预拉 LaMa**，使容器启动后尽量很快可连。
- 若日志里**仍有**大体积进度条（`196M/196M` 等）且 502 持续较久：多为 `docker-entrypoint.sh` 中开启的扩图 / 去背景等插件（`--enable-realesrgan` 等）在首启时继续下载权重。可**等待**完成，或**按需**收紧入口脚本里的 `--enable-*`。
- 若出现 **`ModuleNotFoundError: No module named 'rembg'`**：入口脚本启用了 `--enable-remove-bg`，需在镜像里 `pip install onnxruntime rembg`（本仓库 Dockerfile 已包含）。
- 若启动时 **`huggingface.co` / Connection / Network is unreachable / `briaai/RMBG-1.4/.../model.pth`**：默认识别 RemoveBG 会向 HuggingFace 拉 Bria 模型；**运行实例无外网 / 不能访问 HF** 时会失败。本仓库已在**构建阶段**用 `HF_HOME=/opt/iopaint-cache/huggingface` 预下该文件；**请重新构建并发布**镜像。若**构建机**也拉不到，可在构建时设 `HF_ENDPOINT`（如国内 HF 镜像）或本机有网打镜像后推 TCR。其它插件（Real-ESRGAN 等）首次调用仍可能下权重，可等待或关对应 `--enable-*`。
- 云构建 / 运行需能拉取**构建阶段**所依赖的模型；**完全无外网**时改自制离线层或关插件。

## 无容器 Shell 时如何确认服务

免费版云托管常不能 `exec` 进容器。可用：

- **运行日志 / 标准输出**：在控制台「实例 / 运行日志」查看 `iopaint` / uvicorn 是否报告监听地址、无崩溃。
- **公网自测**：本机浏览器或 `curl` 访问 `https://<服务域名>/docs`、`/api/v1/server-config`（需已开放公网并配合法域名，或先关域名校验）。
- **与 tuying-tools 同 VPC 时**：在 tools 里配的 `IOPAINT_BASE_URL` 能通即表示网络可达（仍须 URL 指到本 IOPaint 服务的根域名）。
