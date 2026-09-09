#!/bin/sh
# hidane migrate.sh — 記録の形式が変わったとき、古い記録を新しい形に直す。何度回しても同じ結果(冪等)。
# 使い方: migrate.sh [--root DIR]
#   <root>/.version に「どこまで直したか」を残す。install.sh --update から呼ばれる。手で回してもよい。
# 一次記録(log.md)を書き換える唯一のスクリプト。各段は必ず退避(<file>.bak-<段>)を残す。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"
[ "${1:-}" = "--root" ] && ROOT="$2"
[ -d "$ROOT" ] || { echo "migrate.sh: no records at $ROOT"; exit 0; }
have=$(cat "$ROOT/.version" 2>/dev/null || echo 0)
done_=0

# 段 1 (2026-09-09): 型と結果を日本語から記号に(追う→trace, 当たり→hit …)
if [ "$have" -lt 1 ]; then
  for f in "$ROOT"/*/log.md; do
    [ -f "$f" ] || continue
    if grep -q '| 追う\(([^)]*)\)\{0,1\} |\|| 要約 |\|| 当たり |\|| 一致 |\|| ズレ |\|| 外れ |\|| 分からない |\|| 未回答 |' "$f"; then
      cp "$f" "$f.bak-1"
      sed 's/| 追う(境界・変異) |/| edge |/g; s/| 追う |/| trace |/g; s/| 要約 |/| summary |/g; s/| 当たり |/| hit |/g; s/| 一致 |/| hit |/g; s/| ズレ |/| miss |/g; s/| 外れ |/| miss |/g; s/| 分からない |/| dunno |/g; s/| 未回答 |/| skip |/g' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
      echo "migrate.sh: 1: $f"
    fi
  done
  rm -f "$ROOT"/*/pending "$ROOT"/*/keys
  done_=1
fi

echo 1 > "$ROOT/.version"
[ "$done_" = 1 ] && echo "migrate.sh: up to date (1)" || echo "migrate.sh: nothing to do (1)"
