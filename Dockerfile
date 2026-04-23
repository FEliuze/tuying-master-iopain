# IOPaint HTTP（REST `/api/v1/*`），供 tuying-tools 通过 IOPAINT_BASE_URL 调用。
# 多阶段：默认 `pypi` 无需本目录的 iopaint-offline.tar.gz，避免云构建 COPY 报 not found。
# 使用本地 tar 时：构建参数指定 target=offline，且同目录有 iopaint-offline.tar.gz
#
# 勿用仅 `lama-cleaner` 的旧镜像。须 iopaint>=1.3。
# 先装 CPU 版 torch（官方 wheel），再装 iopaint，避免 PyPI 再拉一份大体积 torch。

FROM python:3.11-slim-bookworm AS base

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

# ---------- 1) 离线包（有 iopaint-offline.tar.gz 时：docker build --target offline）----------
FROM base AS offline
# 由 scripts/package-offline.sh 生成，单文件须 <100MB
COPY iopaint-offline.tar.gz /build/
RUN set -eux; \
    mkdir -p /build/work; \
    tar -xzf /build/iopaint-offline.tar.gz -C /build/work; \
    pip config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple; \
    pip config set global.trusted-host mirrors.cloud.tencent.com; \
    pip install --upgrade pip; \
    pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu; \
    pip install --no-cache-dir "Pillow==9.5.0"; \
    if [ -d /build/work/iopaint_packages/packages ] && [ -n "$$(find /build/work/iopaint_packages/packages -name '*.whl' -print -quit)" ]; then \
        pip install --no-cache-dir -f /build/work/iopaint_packages/packages /build/work/iopaint_local; \
    else \
        pip install --no-cache-dir /build/work/iopaint_local; \
    fi; \
    rm -rf /build/work /build/iopaint-offline.tar.gz

ENV PORT=8080 \
    IOPAINT_MODEL=lama \
    IOPAINT_DEVICE=cpu
EXPOSE 8080
CMD ["/bin/sh", "-c", "exec iopaint start --host=0.0.0.0 --port=\"${PORT:-8080}\" --model=\"${IOPAINT_MODEL:-lama}\" --device=\"${IOPAINT_DEVICE:-cpu}\" --enable-realesrgan --realesrgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-gfpgan --gfpgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-restoreformer --restoreformer-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-remove-bg --remove-bg-device=\"${IOPAINT_DEVICE:-cpu}\" --no-half"]

# ---------- 2) 默认：PyPI 安装 iopaint（无离线包、云构建推荐）----------
FROM base AS pypi
RUN pip config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple \
    && pip config set global.trusted-host mirrors.cloud.tencent.com \
    && pip install --upgrade pip \
    && pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir "Pillow==9.5.0" "iopaint>=1.3.0,<2"

# 无 COPY；「最后一个 FROM」为默认构建目标，需 offline 时显式 --target offline
ENV PORT=8080 \
    IOPAINT_MODEL=lama \
    IOPAINT_DEVICE=cpu
EXPOSE 8080
CMD ["/bin/sh", "-c", "exec iopaint start --host=0.0.0.0 --port=\"${PORT:-8080}\" --model=\"${IOPAINT_MODEL:-lama}\" --device=\"${IOPAINT_DEVICE:-cpu}\" --enable-realesrgan --realesrgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-gfpgan --gfpgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-restoreformer --restoreformer-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-remove-bg --remove-bg-device=\"${IOPAINT_DEVICE:-cpu}\" --no-half"]
