#!/bin/sh
# hidane record.sh — 問いと答えを log.md に 1 行追記する。唯一の一次記録への書き込み口。
#
# 使い方: record.sh [--root DIR] [--repo NAME] 場所 関数 概念 型 問い 結果 [ズレ] [備考]
#         record.sh [--root DIR] [--repo NAME] --path        log.md の場所を出す
#   場所   file:a-b        関数   関数名        概念   "A, B"(既存名を優先。無ければ新設可)
#   型     追う | 追う(境界・変異) | 要約
#   結果   当たり | ズレ | 分からない | 未回答
#   ズレ   何がどう違ったか(結果がズレのとき。行番号を含めてよい)
# next.sh が決めた内容(<root>/<repo>/pending)があるときは、場所・関数・概念・型がそれと一致しないと exit 7 で書かない。
# 手で記録するときは --free で照合を飛ばす。
# 追記後、その行が読めることを確かめ(読めなければ exit 6 で取り消す)、vault を作り直す。
# | とタブと改行は列を壊すので、｜ と空白に置き換える。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REPO=""; PATHONLY=""; FREE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --path) PATHONLY=1; shift ;;
    --free) FREE=1; shift ;;
    --help|-h) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; break ;;
    -*) echo "record.sh: unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
if [ -z "$REPO" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "record.sh: git リポジトリの中で実行するか --repo を付けてください" >&2; exit 3; }
  REPO=$(basename "$top")
fi
log="$ROOT/$REPO/log.md"
if [ -n "$PATHONLY" ]; then echo "$log"; exit 0; fi
[ $# -ge 6 ] || { echo "record.sh: 引数は 場所 関数 概念 型 問い 結果 [ズレ] [備考] の 6〜8 個(今 $# 個)" >&2; exit 2; }

clean() { printf '%s' "$1" | tr '\n\t' '  ' | sed 's/|/｜/g; s/^ *//; s/ *$//'; }
place=$(clean "$1"); func=$(clean "$2"); concepts=$(clean "$3"); type=$(clean "$4"); q=$(clean "$5"); result=$(clean "$6")
zure=$(clean "${7:-}"); note=$(clean "${8:-}")
case "$type" in 追う|"追う(境界・変異)"|要約) ;; *) echo "record.sh: 型は 追う / 追う(境界・変異) / 要約 のどれか(今: $type)" >&2; exit 2 ;; esac
case "$result" in 当たり|ズレ|分からない|未回答) ;; *) echo "record.sh: 結果は 当たり / ズレ / 分からない / 未回答 のどれか(今: $result)" >&2; exit 2 ;; esac
printf '%s' "$place" | grep -Eq '^[^ ]+:[0-9]+-[0-9]+$' || { echo "record.sh: 場所は file:a-b の形(今: $place)" >&2; exit 2; }
[ -n "$concepts" ] || { echo "record.sh: 概念が空" >&2; exit 2; }

pending="$ROOT/$REPO/pending"
if [ -z "$FREE" ] && [ -f "$pending" ]; then
  want=$(cat "$pending"); got=$(printf '%s\t%s\t%s\t%s' "$place" "$func" "$concepts" "$type")
  if [ "$want" != "$got" ]; then
    printf 'record.sh: next.sh が決めた内容と違うので書かない(exit 7)。\n  決定: %s\n  今回: %s\n  手で記録するなら --free\n' "$(printf '%s' "$want" | tr '\t' '|')" "$(printf '%s' "$got" | tr '\t' '|')" >&2
    exit 7
  fi
fi

mkdir -p "$(dirname "$log")"
[ -f "$log" ] || printf '# hidane — %s\n\n| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | ズレ | 備考 |\n|---|---|---|---|---|---|---|---|---|\n' "$REPO" > "$log"
before=$(grep -c '^| 20' "$log" || true)
line=$(printf '| %s | %s | %s | %s | %s | %s | %s | %s | %s |' "$(date '+%Y-%m-%d %H:%M')" "$place" "$func" "$concepts" "$type" "$q" "$result" "$zure" "$note")
printf '%s\n' "$line" >> "$log"
after=$(grep -c '^| 20' "$log" || true)
cols=$(printf '%s' "$line" | tr -cd '|' | wc -c | tr -d ' ')
if [ "$after" -ne $((before + 1)) ] || [ "$cols" -ne 10 ]; then
  # 取り消す(最後の 1 行を落とす)
  sed -i '' '$d' "$log" 2>/dev/null || sed -i '$d' "$log"
  echo "record.sh: 追記した行が読めないので取り消した(列 $cols)" >&2; exit 6
fi
echo "$line"
[ -f "$pending" ] && [ -z "$FREE" ] && rm -f "$pending"
sh "$HERE/pages.sh" --root "$ROOT" >/dev/null 2>&1 || true
