# IOPaint HTTP（REST `/api/v1/*`），供 tuying-tools 通过 IOPAINT_BASE_URL 调用。
#
# 勿用仅 `lama-cleaner` 的旧镜像（无 /api/v1，tools 会 HTTP 404）。须 `iopaint start`（iopaint>=1.3）。
#
# 构建优化：用预装 PyTorch CPU 的官方底包，避免在 `pip install iopaint` 时再从 PyPI 拉完整 torch
#（云托管上该步骤极易触发构建超时）。底镜像较胖但层可缓存；真正耗时的是大 wheel 的重复下载。

FROM pytorch/pytorch:2.1.0-cpu

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1

# 底镜像为科研栈，补 IOPaint / OpenCV 链常见系统库
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 与 tools 中 iopaint 的 Pillow 版本一致；腾讯云 PyPI 镜像
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
