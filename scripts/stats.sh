#!/bin/sh
# hidane stats.sh — 数字だけの要約。関数名・ファイル名・概念名は出さない(フィードバックに貼るため)。
# 使い方: stats.sh [--root DIR]
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"
[ "${1:-}" = "--root" ] && ROOT="$2"
. "$HERE/lang.sh"
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
sh "$HERE/map.sh" --root "$ROOT" --tsv > "$tmp" 2>/dev/null || true
repos=0; fns=0; q=0
for d in "$ROOT"/*/; do
  [ -f "$d/log.md" ] || [ -f "$d/functions.md" ] || continue
  repos=$((repos+1))
  [ -f "$d/functions.md" ] && fns=$((fns + $(grep -c '^| 20' "$d/functions.md" || true)))
  [ -f "$d/log.md" ] && q=$((q + $(grep -c '^| 20' "$d/log.md" || true)))
done
echo "hidane stats ($(date +%Y-%m-%d), lang=$LANGX, $(uname -s))"
echo "repos: $repos  tagged functions: $fns  questions answered: $q"
for d in "$ROOT"/*/; do [ -f "$d/log.md" ] && grep '^| 20' "$d/log.md"; done 2>/dev/null | awk -F'|' '
  function t(s) { gsub(/^ +| +$/, "", s); return s }
  { ty[t($6)]++; rs[t($8)]++; d = substr(t($2), 1, 10); if (d != "") days[d] = 1 }
  END { printf("by type:"); for (k in ty) printf(" %s %d", k, ty[k]); printf("\n")
        printf("by result:"); for (k in rs) printf(" %s %d", k, rs[k]); printf("\n")
        n = 0; for (k in days) n++; printf("days with answers: %d\n", n) }'
awk -F'\t' '{ st[$5]++; n++ } END { printf("concepts: %d  by state:", n); for (k in st) printf(" %s %d", k, st[k]); printf("\n") }' "$tmp"
[ -f "$ROOT/aliases.md" ] && echo "merged names: $(grep -c '^| 20' "$ROOT/aliases.md" || true)"
exit 0
