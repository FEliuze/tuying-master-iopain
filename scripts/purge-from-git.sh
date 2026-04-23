#!/usr/bin/env bash
# 从 Git **索引**中移除 iopaint 大路径（本地文件会保留）。
# 若 push 仍报 GH001，说明大对象在**历史**里，须用 git filter-repo 清历史（见文末）。
#
# 用法：在仓库根目录执行
#   bash iopaint-service/scripts/purge-from-git.sh
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "错误：请在 git 仓库根目录执行本脚本"
  exit 1
}
cd "$ROOT"

echo "== 从索引移除 iopaint_packages 与 iopaint-local.tar.gz 的已跟踪文件"
any=0
for f in $(git ls-files | grep -E '(/|^)iopaint_packages/|iopaint-local\.tar\.gz$' || true); do
  [ -n "$f" ] || continue
  any=1
  echo "  git rm --cached: $f"
  git rm --cached -- "$f"
done

if [ "$any" -eq 0 ]; then
  echo "  （无匹配；可能已清过，或需直接走「清历史」）"
fi

echo
echo "== 请检查并提交"
echo "  git status"
echo "  git commit -m 'chore: 停止跟踪 iopaint 大文件'"
echo
echo "== 若仍无法 push"
echo "  大文件在**历史**中，在仓库根执行（需已安装 git-filter-repo）："
echo
echo "    git filter-repo --force --invert-paths \\"
echo "      --path iopaint_packages --path iopaint-local.tar.gz"
echo
echo "  若大文件在 iopaint-service/ 下，改为："
echo "    --path iopaint-service/iopaint_packages --path iopaint-service/iopaint-local.tar.gz"
echo
echo "  然后: git push --force origin <你的分支>"
