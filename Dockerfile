# # 仅运行 IOPaint HTTP 服务，供 tuying-tools（Flask）通过 IOPAINT_BASE_URL 调用。
# # 与 tools/ 分离构建，避免单镜像装 iopaint+torch 导致云托管构建超时。
# # 云托管：「服务端口」与 EXPOSE/监听一致，环境变量 PORT 由平台注入。

# FROM python:3.11-slim-bookworm

# ENV PYTHONDONTWRITEBYTECODE=1 \
#     PYTHONUNBUFFERED=1 \
#     DEBIAN_FRONTEND=noninteractive

# RUN apt-get update && apt-get install -y --no-install-recommends \
#     ca-certificates \
#     curl \
#     libgl1 \
#     libglib2.0-0 \
#     && rm -rf /var/lib/apt/lists/*

# WORKDIR /app

# # 与 tools 中 iopaint 依赖的 Pillow 版本一致
# RUN pip config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple \
#     && pip config set global.trusted-host mirrors.cloud.tencent.com \
#     && pip install --upgrade pip \
#     && pip install --no-cache-dir "Pillow==9.5.0" "iopaint>=1.3.0,<2"

# # 云托管常注入 PORT=8080；需对外监听 0.0.0.0，且与控制台服务端口一致
# EXPOSE 8080

# ENV PORT=8080 \
#     IOPAINT_MODEL=lama \
#     IOPAINT_DEVICE=cpu

# # 探活可用: GET /api/v1/server-config
# CMD ["/bin/sh", "-c", "exec iopaint start --host=0.0.0.0 --port=\"${PORT:-8080}\" --model=\"${IOPAINT_MODEL:-lama}\" --device=\"${IOPAINT_DEVICE:-cpu}\" --enable-realesrgan --realesrgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-gfpgan --gfpgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-restoreformer --restoreformer-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-remove-bg --remove-bg-device=\"${IOPAINT_DEVICE:-cpu}\" --no-half"]

# 使用社区预构建的 IOPaint 基础镜像（CPU 版本）
FROM cwq1913/lama-cleaner:cpu-0.26.1

# 默认 8080：与微信云托管/K8s 常注入的 PORT=8080 一致；控制台「服务端口」须与此相同。
# 若写死 80 而平台注入 PORT=8080，进程会监听 8080、探活仍打 80，则 Readiness 报 connection refused。
ENV PORT=8080 \
    IOPAINT_MODEL=lama \
    IOPAINT_DEVICE=cpu

EXPOSE 8080

# 直接启动服务，保留你之前的所有插件参数
# 注意：基础镜像的可执行文件是 lama-cleaner
CMD ["/bin/sh", "-c", "exec lama-cleaner --host=0.0.0.0 --port=\"${PORT:-8080}\" --model=\"${IOPAINT_MODEL:-lama}\" --device=\"${IOPAINT_DEVICE:-cpu}\" --enable-realesrgan --realesrgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-gfpgan --gfpgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-restoreformer --restoreformer-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-remove-bg --remove-bg-device=\"${IOPAINT_DEVICE:-cpu}\" --no-half"]