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

# # 云托管常注入 PORT=80 或 8080；需对外监听 0.0.0.0
# EXPOSE 80

# ENV PORT=80 \
#     IOPAINT_MODEL=lama \
#     IOPAINT_DEVICE=cpu

# # 探活可用: GET /api/v1/server-config
# CMD ["/bin/sh", "-c", "exec iopaint start --host=0.0.0.0 --port=\"${PORT:-80}\" --model=\"${IOPAINT_MODEL:-lama}\" --device=\"${IOPAINT_DEVICE:-cpu}\" --enable-realesrgan --realesrgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-gfpgan --gfpgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-restoreformer --restoreformer-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-remove-bg --remove-bg-device=\"${IOPAINT_DEVICE:-cpu}\" --no-half"]

# 使用社区预构建的 IOPaint 基础镜像（CPU 版本，适合云托管环境）
# 该镜像已包含 iopaint 及所有依赖，无需本地构建
FROM cwq1913/lama-cleaner:cpu-latest

# ========== 以下保留你原有的环境变量配置 ==========
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# 安装额外系统依赖（基础镜像可能已包含部分，但保留以确保完整）
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ========== 保留你原有的环境变量（云托管端口等）==========
ENV PORT=80 \
    IOPAINT_MODEL=lama \
    IOPAINT_DEVICE=cpu

# 探活端点: GET /api/v1/server-config（基础镜像已支持）
# 注意：预构建镜像默认暴露 8080 端口，需改为云托管注入的 PORT（通常为 80）
EXPOSE 80

# ========== 保留你原有的启动命令（插件全开）==========
# 使用 exec 形式确保信号正确传递
# 注意：预构建镜像的可执行文件是 lama-cleaner，不是 iopaint
CMD ["/bin/sh", "-c", "exec lama-cleaner --host=0.0.0.0 --port=\"${PORT:-80}\" --model=\"${IOPAINT_MODEL:-lama}\" --device=\"${IOPAINT_DEVICE:-cpu}\" --enable-realesrgan --realesrgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-gfpgan --gfpgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-restoreformer --restoreformer-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-remove-bg --remove-bg-device=\"${IOPAINT_DEVICE:-cpu}\" --no-half"]
