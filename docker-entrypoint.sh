#!/bin/sh
# 云托管探针常打固定「容器端口」（多为 80）。iopaint 冷启较慢时，直连 iopaint 的 listen 会晚，TCP 易 connection refused。
# 由 socat 在 PORT（默认 80）上先监听，K8S TCP 探活易过；再转发到 127.0.0.1:8080 上的 iopaint。
set -e
OUT="${PORT:-80}"
INNER=8080
IODEV="${IOPAINT_DEVICE:-cpu}"
MODEL="${IOPAINT_MODEL:-lama}"

export PYTHONUNBUFFERED=1
echo "[iopaint-service] $(date -u) probes: :$OUT  ->  iopaint 127.0.0.1:$INNER"
echo "[iopaint-service] starting iopaint in background (pid TBD)..."

iopaint start \
  --host=127.0.0.1 \
  --port="$INNER" \
  --model="$MODEL" \
  --device="$IODEV" \
  --enable-realesrgan --realesrgan-device="$IODEV" \
  --enable-gfpgan --gfpgan-device="$IODEV" \
  --enable-restoreformer --restoreformer-device="$IODEV" \
  --enable-remove-bg --remove-bg-device="$IODEV" \
  --no-half &

sleep 1
echo "[iopaint-service] starting socat (foreground) -> exec"

exec socat TCP-LISTEN:"$OUT",fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:"$INNER"
