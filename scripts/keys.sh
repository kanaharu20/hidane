#!/bin/sh
# hidane keys.sh — 答えを聞く前に、正解の要素(鍵)を固定する。
#
# 使い方: keys.sh [--root DIR] [--repo NAME] "鍵 1 @ a-b" "鍵 2 @ a-b" ... (2〜5 個)
#         keys.sh [--root DIR] [--repo NAME] --show
#   鍵 = 具体的で確かめられる事実 1 つ(返り値、呼ばれる関数、実行の順序、通る分岐)。理由は書かない(「ので」「because」を含む鍵は exit 2)。
#   末尾の「@ a-b」はその事実がある行(任意)。partial / miss のとき、ユーザーには行番号だけを見せる。
# next.sh が決めた pending が無いと書かない(exit 5)。鍵は <root>/<repo>/keys に置き、record.sh が消す。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REPO=""; SHOW=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --show) SHOW=1; shift ;;
    --help|-h) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; break ;;
    -*) echo "keys.sh: unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
. "$HERE/lang.sh"
if [ -z "$REPO" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "keys.sh: $(L r_norepo)" >&2; exit 3; }
  REPO=$(basename "$top")
fi
kf="$ROOT/$REPO/keys"
if [ -n "$SHOW" ]; then [ -f "$kf" ] && cat "$kf"; exit 0; fi
[ -f "$ROOT/$REPO/pending" ] || { echo "keys.sh: $(L k_nopending)" >&2; exit 5; }
[ $# -ge 2 ] && [ $# -le 5 ] || { echo "keys.sh: $(L k_count) ($#)" >&2; exit 2; }
: > "$kf"
i=0
for k in "$@"; do
  i=$((i+1))
  k=$(printf '%s' "$k" | tr '\n\t' '  ' | sed 's/|/｜/g; s/^ *//; s/ *$//')
  [ -n "$k" ] || { rm -f "$kf"; echo "keys.sh: $(L k_empty) ($i)" >&2; exit 2; }
  case "$k" in *ので*|*なぜなら*|*[Bb]ecause*) rm -f "$kf"; printf "keys.sh: $(L k_reason)\n" "$i" >&2; exit 2 ;; esac
  printf '%d\t%s\n' "$i" "$k" >> "$kf"
done
printf "keys.sh: $(L k_saved)\n" "$i"
