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

# 使用仍在维护期的 Debian 11 (Bullseye) 作为基础镜像，可避免软件源失效的问题
FROM python:3.11-slim-bullseye

# 设置环境变量，防止Python生成pyc文件并在输出中缓冲日志
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=80 \
    IOPAINT_MODEL=lama \
    IOPAINT_DEVICE=cpu

# 设置 pip 使用国内镜像源，加速依赖下载
RUN pip config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple

# 安装 IOPaint 运行所需的系统库和 IOPaint 本身
# 这里将两个 RUN 命令合并，可以减少最终镜像的层数
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir iopaint

# 暴露服务端口
EXPOSE 80

# 使用 iopaint 命令启动服务，保留你需要的所有插件
CMD ["/bin/sh", "-c", "exec iopaint start --host=0.0.0.0 --port=\"${PORT:-80}\" --model=\"${IOPAINT_MODEL:-lama}\" --device=\"${IOPAINT_DEVICE:-cpu}\" --enable-realesrgan --realesrgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-gfpgan --gfpgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-restoreformer --restoreformer-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-remove-bg --remove-bg-device=\"${IOPAINT_DEVICE:-cpu}\" --no-half"]