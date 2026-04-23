#!/bin/sh
# 启动前打印到 stdout，云托管「运行日志」里可直接看到（免费版通常无进容器 shell）
set -e
PORT="${PORT:-8080}"
echo "========================================"
echo "[iopaint-service] start $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "[iopaint-service] PORT=$PORT host=0.0.0.0 model=${IOPAINT_MODEL:-lama} device=${IOPAINT_DEVICE:-cpu}"
# 发行名在 PyPI 上多为 iopaint
if command -v pip >/dev/null 2>&1; then
  pip show iopaint 2>/dev/null | sed -n 's/^Version: /[iopaint-service] iopaint version /p' || true
fi
echo "[iopaint-service] after listen, expect HTTP 200: /api/v1/server-config /api/v1/model /docs"
echo "========================================"
exec iopaint start \
  --host=0.0.0.0 \
  --port="$PORT" \
  --model="${IOPAINT_MODEL:-lama}" \
  --device="${IOPAINT_DEVICE:-cpu}" \
  --enable-realesrgan --realesrgan-device="${IOPAINT_DEVICE:-cpu}" \
  --enable-gfpgan --gfpgan-device="${IOPAINT_DEVICE:-cpu}" \
  --enable-restoreformer --restoreformer-device="${IOPAINT_DEVICE:-cpu}" \
  --enable-remove-bg --remove-bg-device="${IOPAINT_DEVICE:-cpu}" \
  --no-half
