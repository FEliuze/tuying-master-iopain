# IOPaint HTTP（REST `/api/v1/*`），供 tuying-tools 通过 IOPAINT_BASE_URL 调用。
# 多阶段：默认 `pypi` 无需 iopaint-offline.tar.gz；`offline` 需同目录有该包且 --target offline
#
# 云托管「create_build_image : creating」会长时间无新日志：多为下面某条 RUN 在装 torch（可达数十分钟），属正常。
# 已拆成多条 RUN 并带 echo，便于在支持「按层/按步」的构建日志里看到卡在哪一步。

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

# 监听端口：以环境变量 PORT 为准（与云托管控制台「容器端口/探活」一致）。
# 镜像默认 PORT=80；若平台注入 PORT=8080 等，会覆盖下方 ENV，无需改 Dockerfile。

# ---------- 1) 离线包：docker build --target offline，且目录含 iopaint-offline.tar.gz ----------
FROM base AS offline
COPY iopaint-offline.tar.gz /build/
RUN set -eux; \
    mkdir -p /build/work; \
    tar -xzf /build/iopaint-offline.tar.gz -C /build/work; \
    pip config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple; \
    pip config set global.trusted-host mirrors.cloud.tencent.com; \
    pip install --upgrade pip
RUN set -eux; echo "[iopaint-service build] $$(date -u) installing torch+torchvision (CPU)..."; \
    pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu
RUN set -eux; echo "[iopaint-service build] $$(date -u) installing Pillow + iopaint_local..."; \
    pip install --no-cache-dir "Pillow==9.5.0"; \
    if [ -d /build/work/iopaint_packages/packages ] && [ -n "$$(find /build/work/iopaint_packages/packages -name '*.whl' -print -quit)" ]; then \
        pip install --no-cache-dir -f /build/work/iopaint_packages/packages /build/work/iopaint_local; \
    else \
        pip install --no-cache-dir /build/work/iopaint_local; \
    fi; \
    rm -rf /build/work /build/iopaint-offline.tar.gz

ENV PORT=80 \
    IOPAINT_MODEL=lama \
    IOPAINT_DEVICE=cpu
EXPOSE 80
CMD ["/bin/sh", "-c", "exec iopaint start --host=0.0.0.0 --port=\"${PORT:-80}\" --model=\"${IOPAINT_MODEL:-lama}\" --device=\"${IOPAINT_DEVICE:-cpu}\" --enable-realesrgan --realesrgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-gfpgan --gfpgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-restoreformer --restoreformer-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-remove-bg --remove-bg-device=\"${IOPAINT_DEVICE:-cpu}\" --no-half"]

# ---------- 2) 默认：PyPI 安装 iopaint（无离线包，云构建常用）----------
FROM base AS pypi
RUN pip config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple \
    && pip config set global.trusted-host mirrors.cloud.tencent.com \
    && pip install --upgrade pip
RUN set -eux; echo "[iopaint-service build] $$(date -u) installing torch+torchvision (CPU), 本步通常最慢..."; \
    pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu
RUN set -eux; echo "[iopaint-service build] $$(date -u) installing Pillow + iopaint..."; \
    pip install --no-cache-dir "Pillow==9.5.0" "iopaint>=1.3.0,<2"

ENV PORT=80 \
    IOPAINT_MODEL=lama \
    IOPAINT_DEVICE=cpu
EXPOSE 80
CMD ["/bin/sh", "-c", "exec iopaint start --host=0.0.0.0 --port=\"${PORT:-80}\" --model=\"${IOPAINT_MODEL:-lama}\" --device=\"${IOPAINT_DEVICE:-cpu}\" --enable-realesrgan --realesrgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-gfpgan --gfpgan-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-restoreformer --restoreformer-device=\"${IOPAINT_DEVICE:-cpu}\" --enable-remove-bg --remove-bg-device=\"${IOPAINT_DEVICE:-cpu}\" --no-half"]
