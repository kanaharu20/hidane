#!/bin/sh
# hidane ask.sh — 問いの全文を検査して保存する。keys.sh の後、ユーザーに見せる前に通す。
#
# 使い方: ask.sh [--root DIR] [--repo NAME] "<問いの全文>"
#   検査(SKILL の文の規則を機械に移したもの):
#     1. 空でない行が 4 行以内
#     2. 1 行目に next.sh の場所のファイル名と関数名がある
#     3. 2 行目以降に式(== != <= >= && || -> ; ` { } と 識別子( )や行番号(N 行 / line N / L12)が無い
#     4. 呼び出しの鍵にある識別子(4 文字以上)が 2 行目以降に無い(呼ぶ関数の名前を問いに書かない)
#     5. 最後の行が keys.sh の「問いの結び」で終わる(句読点は無視)
#   通れば <root>/<repo>/question に保存し、問いをそのまま出力する(それをユーザーに見せる)。
#   通らなければ理由を stderr に出して exit 2。pending と keys は残るので、問いを直して再実行する。
# record.sh は question が無いと --verdict / dunno / skip を書かない(--free を除く)。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --help|-h) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; break ;;
    -*) echo "ask.sh: unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
. "$HERE/lang.sh"
if [ -z "$REPO" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "ask.sh: $(L r_norepo)" >&2; exit 3; }
  REPO=$(hidane_repo_key "$top")
fi
d="$ROOT/$REPO"; kf="$d/keys"
[ -f "$d/pending" ] || { echo "ask.sh: $(L k_nopending)" >&2; exit 5; }
[ -f "$kf" ] && [ -f "$kf.end" ] || { echo "ask.sh: $(L a_nokeys)" >&2; exit 5; }
[ $# -eq 1 ] && [ -n "$1" ] || { echo "ask.sh: $(L a_usage)" >&2; exit 2; }
q=$(printf '%s' "$1" | tr '\t' ' ' | sed 's/[[:space:]]*$//')
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$q" | grep -v '^[[:space:]]*$' > "$tmp" || true
n=$(wc -l < "$tmp" | tr -d ' ')
fail() { printf "ask.sh: $1\n" "$2" >&2; exit 2; }
# 1. 行数
[ "$n" -ge 1 ] && [ "$n" -le 4 ] || fail "$(L a_lines)" "$n"
# 2. 1 行目に場所と関数名
place=$(cut -f1 "$d/pending"); fn=$(cut -f2 "$d/pending"); file=${place%%:*}; base=${file##*/}
head -1 "$tmp" | grep -Fq "$base" && head -1 "$tmp" | grep -Fq "$fn" || fail "$(L a_head)" "$base $fn"
# 3. 2 行目以降に式・行番号が無い
body=$(sed -n '2,$p' "$tmp")
hit=$(printf '%s\n' "$body" | grep -nE '==|!=|<=|>=|&&|\|\||->|;|`|\{|\}|[A-Za-z_][A-Za-z0-9_]*\(' | head -1 || true)
[ -z "$hit" ] || fail "$(L a_code)" "$hit"
hit=$(printf '%s\n' "$body" | grep -nE '[0-9]+ ?行|行 ?[0-9]+|[Ll]ine ?[0-9]+|(^|[^A-Za-z0-9_])L[0-9]+|:[0-9]+-[0-9]+' | head -1 || true)
[ -z "$hit" ] || fail "$(L a_lineno)" "$hit"
# 4. 呼び出しの鍵の識別子(呼ぶ関数の名前)が無い
for id in $(grep -E "^[0-9]+	($(L k_c_call)): " "$kf" | cut -f2 | grep -oE '[A-Za-z_][A-Za-z0-9_]{3,}' | sort -u); do
  [ "$id" = "$fn" ] && continue
  printf '%s\n' "$body" | grep -Eq "(^|[^A-Za-z0-9_])$id([^A-Za-z0-9_]|$)" && fail "$(L a_callee)" "$id"
done
# 5. 最後の行が結びで終わる
last=$(tail -1 "$tmp" | sed 's/[[:space:]。．.?？!！」]*$//'); end=$(sed 's/[[:space:]。．.?？!！」]*$//' "$kf.end")
case "$last" in *"$end") ;; *) fail "$(L a_end)" "$end" ;; esac
printf '%s\n' "$q" > "$d/question"
printf '%s\n' "$q"
