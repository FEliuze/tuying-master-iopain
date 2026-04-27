#!/bin/sh
# 云托管「容器端口」与下面 PORT（默认 8080）保持一致；iopaint 直接对外监听，无 socat（避免与 8080 双占）。
set -e
PORT="${PORT:-8080}"
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
