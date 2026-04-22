# IOPaint HTTP（REST `/api/v1/*`），供 tuying-tools 通过 IOPAINT_BASE_URL 调用。
#
# 勿用仅 `lama-cleaner` 的旧镜像（无 /api/v1，tools 会 HTTP 404）。须 `iopaint start`（iopaint>=1.3）。
#
# PyTorch 官方 Docker Hub 长期**无**稳定的 `pytorch/pytorch:x.y.z-cpu` 公网标签，勿使用不存在的 tag。
# 先装 CPU 版 torch（官方 wheel 源），再装 iopaint，避免 iopaint 从 PyPI 再拉一份体积巨大的 torch。

FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 1) 腾讯云 PyPI 加速常规包；2) 官方 PyTorch **CPU** wheel（与 CUDA 底包不同，适合云托管纯 CPU）
RUN pip config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple \
    && pip config set global.trusted-host mirrors.cloud.tencent.com \
    && pip install --upgrade pip \
    && pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir "Pillow==9.5.0" "iopaint>=1.3.0,<2"

# 与微信云托管/K8s 常注入的 PORT=8080 一致；控制台「服务端口」须与此相同。
ENV PORT=8080 \
    IOPAINT_MODEL=lama \
    IOPAINT_DEVICE=cpu

EXPOSE 8080

# 探活: GET /api/v1/server-config
CMD ["/bin/sh", "-c", "exec iopaint start --host=0.0.0.0 --port=\"${PORT:-8080}\" --model=\"${IOPAINT_MODEL:-lama}\" --device=\"${IOPAINT_DEVICE:-cpu}\" --enable-realesrgan --realesrgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-gfpgan --gfpgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-restoreformer --restoreformer-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-remove-bg --remove-bg-device=\"${IOPAINT_DEVICE:-cpu}\" --no-half"]
