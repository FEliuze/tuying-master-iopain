#!/usr/bin/env bash
# 在 iopaint-service/ 下生成可提交到 Git 的 iopaint-offline.tar.gz（需单文件 <100MB 以符合 GitHub）
#
# 说明：.whl 本质是 zip，再压缩体积几乎不会明显变小；GitHub 限制 100MB，大依赖应「不打包进 git」
# 由 Dockerfile 在构建时用 PyTorch 官方 CPU 源安装 torch，勿把 torch-*.whl 放进包。
# 使用：
#   chmod +x scripts/package-offline.sh
#   ./scripts/package-offline.sh /path/to/IOPaint [ /path/to/pip/downloaded/wheels ]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?请传入 IOPaint 仓库根目录（含 pyproject.toml）}"
WHEELS_DIR="${2:-}"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/iopaint_local"
rsync -a \
  --exclude='.git/' \
  --exclude='__pycache__/' \
  --exclude='.mypy_cache' \
  --exclude='.venv' \
  --exclude='venv' \
  --exclude='node_modules' \
  --exclude='htmlcov' \
  --exclude='.pytest_cache' \
  --exclude='dist/' \
  --exclude='build/' \
  --exclude='*.pyc' \
  --exclude='.eggs' \
  --exclude='*.egg-info' \
  --exclude='iopaint_packages' \
  --exclude='**/*.pth' \
  --exclude='**/models' \
  "$SRC/" "$STAGE/iopaint_local/"

if [[ -n "$WHEELS_DIR" && -d "$WHEELS_DIR" ]]; then
  mkdir -p "$STAGE/iopaint_packages/packages"
  for f in "$WHEELS_DIR"/*.whl; do
    [[ -e "$f" ]] || continue
    base=$(basename "$f")
    case "$base" in
    torch-*.whl|torchvision-*.whl|torchaudio-*.whl|triton*.whl|nvidia_*.whl|nvidia-*.whl)
      echo "跳过大包/由镜像现装: $base" >&2
      continue
      ;;
    esac
    cp -a "$f" "$STAGE/iopaint_packages/packages/"
  done
else
  mkdir -p "$STAGE/iopaint_packages/packages"
fi

OUT="$ROOT/iopaint-offline.tar.gz"
( cd "$STAGE" && tar c iopaint_local iopaint_packages | gzip -9 -n >"$OUT" )

BYTES=$(wc -c <"$OUT" | tr -d ' ')
echo "已生成: $OUT ($(du -h "$OUT" | cut -f1))"

if (( BYTES > 104857600 )); then
  echo "错误: 仍超过 GitHub 单文件 100MB。请从第二参数目录中删除 opencv-*.whl 等大件（让构建走 PyPI/镜像线装），并确认 iopaint_local 中未含 venv/模型/无关 wheel。" >&2
  exit 1
fi
