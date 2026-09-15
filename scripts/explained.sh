#!/bin/sh
# hidane explained.sh — 解説を求めたことを 1 行残す(<root>/explained.md)。状態や色には一切影響しない。
#
# 使い方: explained.sh [--root DIR] [--repo NAME] "<対象>" "<概念1, 概念2>"
#   対象 = 求めた解説の題(printf、排他制御、この設計でいいか、など自由文)
#   概念 = 地図にある概念名から 1〜2 個(index.md の一覧から選ぶ)。地図に無い名前は捨てて stderr に出す。空でもよい
# 次回の解説で「最近求めた解説」として index.md に出る。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --help|-h) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; break ;;
    -*) echo "explained.sh: unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
. "$HERE/lang.sh"
[ $# -ge 1 ] || { echo "explained.sh: $(L x_usage)" >&2; exit 2; }
if [ -z "$REPO" ]; then top=$(git rev-parse --show-toplevel 2>/dev/null) && REPO=$(hidane_repo_key "$top") || REPO="-"; fi
clean() { printf '%s' "$1" | tr '\n\t' '  ' | sed 's/|/｜/g; s/^ *//; s/ *$//'; }
topic=$(clean "$1"); [ -n "$topic" ] || { echo "explained.sh: $(L x_usage)" >&2; exit 2; }
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
sh "$HERE/map.sh" --root "$ROOT" --tsv 2>/dev/null | cut -f1 > "$tmp" || true
printf '%s' "${2:-}" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' | while IFS= read -r c; do
  if grep -qxF "$c" "$tmp"; then printf '%s\n' "$c"; else echo "explained.sh: $(L x_unknown): $c" >&2; fi
done > "$tmp.kept"
kept=$(paste -sd, "$tmp.kept" | sed 's/,/, /g'); rm -f "$tmp.kept"
f="$ROOT/explained.md"; mkdir -p "$ROOT"
[ -f "$f" ] || printf '# hidane — %s\n\n%s\n|---|---|---|---|\n' "$(L x_title)" "$(L x_header)" > "$f"
line=$(printf '| %s | %s | %s | %s |' "$(date '+%Y-%m-%d %H:%M')" "$REPO" "$topic" "$kept")
printf '%s\n' "$line" >> "$f"
echo "$line"
sh "$HERE/pages.sh" --root "$ROOT" >/dev/null 2>&1 || true
