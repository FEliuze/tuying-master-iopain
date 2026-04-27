# IOPaint HTTP（REST `/api/v1/*`），供 tuying-tools 通过 IOPAINT_BASE_URL 调用。
# 多阶段：默认 `pypi` 无需 iopaint-offline.tar.gz；`offline` 需同目录有该包且 --target offline
#
# 云托管「create_build_image : creating」会长时间无新日志：多为下面某条 RUN 在装 torch（可达数十分钟），属正常。
# 已拆成多条 RUN 并带 echo，便于在支持「按层/按步」的构建日志里看到卡在哪一步。

FROM python:3.11-slim-bookworm AS base

# 模型与缓存目录；构建中预拉 lama，减轻首启长时间无监听致 502
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    XDG_CACHE_HOME=/opt/iopaint-cache

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 由 docker-entrypoint.sh 直接 iopaint listen 0.0.0.0:PORT，默认 8080；与云托管「容器端口」一致即可。

COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

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
# docker-entrypoint 开了 --enable-remove-bg，需 rembg + onnxruntime，否则启动期 import 失败、8080 永不 listen
RUN set -eux; echo "[iopaint-service build] $$(date -u) rembg + onnxruntime (RemoveBG)..."; \
    pip install --no-cache-dir onnxruntime rembg

RUN set -eux; echo "[iopaint-service build] $$(date -u) pre-downloading lama to $$XDG_CACHE_HOME (首启 8080 监听更快)..."; \
    mkdir -p /opt/iopaint-cache; \
    python -c "from iopaint.download import cli_download_model; cli_download_model('lama')"

ENV PORT=8080 \
    IOPAINT_MODEL=lama \
    IOPAINT_DEVICE=cpu
EXPOSE 8080
CMD ["/entrypoint.sh"]

# ---------- 2) 默认：PyPI 安装 iopaint（无离线包，云构建常用）----------
FROM base AS pypi
RUN pip config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple \
    && pip config set global.trusted-host mirrors.cloud.tencent.com \
    && pip install --upgrade pip
RUN set -eux; echo "[iopaint-service build] $$(date -u) installing torch+torchvision (CPU), 本步通常最慢..."; \
    pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu
RUN set -eux; echo "[iopaint-service build] $$(date -u) installing Pillow + iopaint..."; \
    pip install --no-cache-dir "Pillow==9.5.0" "iopaint>=1.3.0,<2"
# docker-entrypoint 开了 --enable-remove-bg，需 rembg + onnxruntime
RUN set -eux; echo "[iopaint-service build] $$(date -u) rembg + onnxruntime (RemoveBG)..."; \
    pip install --no-cache-dir onnxruntime rembg

RUN set -eux; echo "[iopaint-service build] $$(date -u) pre-downloading lama to $$XDG_CACHE_HOME (首启 8080 监听更快)..."; \
    mkdir -p /opt/iopaint-cache; \
    python -c "from iopaint.download import cli_download_model; cli_download_model('lama')"

ENV PORT=8080 \
    IOPAINT_MODEL=lama \
    IOPAINT_DEVICE=cpu
EXPOSE 8080
CMD ["/entrypoint.sh"]
