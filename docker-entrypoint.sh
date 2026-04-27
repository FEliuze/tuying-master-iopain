#!/bin/sh
# 微信云托管默认识别/存活就绪探针多为 :80；默认 PORT=80。若需 8080：环境变量 PORT=8080，且控制台「容器端口+健康检查」改为 8080。
set -e
PORT="${PORT:-80}"
IODEV="${IOPAINT_DEVICE:-cpu}"
MODEL="${IOPAINT_MODEL:-lama}"

export PYTHONUNBUFFERED=1
echo "[iopaint-service] $(date -u) listening 0.0.0.0:$PORT  model=$MODEL  device=$IODEV"

exec iopaint start \
  --host=0.0.0.0 \
  --port="$PORT" \
  --model="$MODEL" \
  --device="$IODEV" \
  --enable-realesrgan --realesrgan-device="$IODEV" \
  --enable-gfpgan --gfpgan-device="$IODEV" \
  --enable-restoreformer --restoreformer-device="$IODEV" \
  --enable-remove-bg --remove-bg-device="$IODEV" \
  --no-half
