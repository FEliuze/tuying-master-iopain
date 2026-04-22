# IOPaint 独立服务

与仓库内 `tools/`（Flask）**分开部署**在同一微信云托管环境，减轻主 tools 镜像体积与构建时间。

## 与 Node / tools 的协作关系

- **不新增消息队列**：仍由 **Node Worker** 调 `TOOLS_BASE_URL`（Flask `POST /internal/process`），业务逻辑不变。
- **Flask** 在 AI 修图等流程里用 HTTP 调本服务：`${IOPAINT_BASE_URL}/api/v1/...`。
- 在 **tuying-tools 云托管服务** 环境变量中配置：`IOPAINT_BASE_URL=https://<本服务在控制台显示的访问域名>`（**无尾斜杠**），且 **同机** 起 IOPaint 时可删或设 `IOPAINT_ENABLED=0`。

## 构建与发布

在云托管中新建服务，**构建目录**选本目录（仅含本 Dockerfile 即可，无需拷贝整个 monorepo 时可将本目录单独上传/子模块）；或与主仓库同源时**构建子目录**指定为 `iopaint-service`（以控制台是否支持「子目录 Docker」为准；不支持则只上传本目录）。

## 健康检查

`GET /api/v1/server-config` 返回 200 即就绪。首次拉模型可能较久，探活需适当超时。

## 部署排错：tuying-tools 探活 `HTTP 404`（/api/v1/server-config）

说明对方进程**不是** IOPaint 1.3+ 的 HTTP API。常见原因：曾用仅含旧命令 `lama-cleaner` 的社区镜像，其路由与 `tools` 中 `iopaint>=1.3` 的 `/api/v1/*` 不兼容。请**按本目录当前 Dockerfile 重建**（`iopaint start`），并确保 `IOPAINT_BASE_URL` 指向该服务，而非其他 Flask/静态站点。

本镜像基于 `pip install iopaint`，**首次构建**会拉取 PyTorch 等依赖，云托管构建时间可能较长，请在控制台**适当调大构建超时/资源**。

## 部署排错：Readiness `connection refused :80`

云托管会向容器注入 `PORT`（多为 **8080**）。若服务仍按模板使用**服务端口 80** 做探活，而进程按 `PORT` 监听 **8080**，会出现 `dial tcp ...:80: connection refused`。请在控制台将**容器/服务端口**改为与 `PORT` 一致（默认 **8080**），或与运维确认环境变量中的 `PORT` 值。

## 资源

建议 CPU/内存配足；GPU 时可将 `IOPAINT_DEVICE` 等改为 `cuda`（需平台支持并自行评估镜像）。
