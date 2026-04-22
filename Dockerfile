# IOPaint HTTP（REST `/api/v1/*`），供 tuying-tools 通过 IOPAINT_BASE_URL 调用。
#
# 勿使用仅启动旧版 `lama-cleaner` 可执行文件的镜像：该服务无 `/api/v1/server-config`，
# tools 探活会 HTTP 404。必须用 PyPI 包 iopaint>=1.3 的 `iopaint start`。
# 与 tools/ 分离构建，避免主 tools 镜像内装 iopaint+torch。

FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 与 tools 中 iopaint 的 Pillow 版本一致
RUN pip config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple \
    && pip config set global.trusted-host mirrors.cloud.tencent.com \
    && pip install --upgrade pip \
    && pip install --no-cache-dir "Pillow==9.5.0" "iopaint>=1.3.0,<2"

# 与微信云托管/K8s 常注入的 PORT=8080 一致；控制台「服务端口」须与此相同。
ENV PORT=8080 \
    IOPAINT_MODEL=lama \
    IOPAINT_DEVICE=cpu

EXPOSE 8080

# 探活: GET /api/v1/server-config
CMD ["/bin/sh", "-c", "exec iopaint start --host=0.0.0.0 --port=\"${PORT:-8080}\" --model=\"${IOPAINT_MODEL:-lama}\" --device=\"${IOPAINT_DEVICE:-cpu}\" --enable-realesrgan --realesrgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-gfpgan --gfpgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-restoreformer --restoreformer-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-remove-bg --remove-bg-device=\"${IOPAINT_DEVICE:-cpu}\" --no-half"]
