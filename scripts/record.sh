#!/bin/sh
# hidane record.sh — 問いと答えを log.md に 1 行追記する。唯一の一次記録への書き込み口。
#
# 使い方:
#   record.sh [--root DIR] [--repo NAME] 場所 関数 概念 型 問い --verdict "yes,no,contra,..." [備考]
#       鍵(keys.sh で先に固定したもの)ごとの判定から結果を決める:
#         contra が 1 つでも → miss / 全部 yes → hit / それ以外 → partial
#       足りない鍵は log の「ズレ」列に文で残し、ユーザーには行番号だけを見せる
#   record.sh [--root DIR] [--repo NAME] 場所 関数 概念 型 問い dunno|skip [備考]
#   record.sh --free 場所 関数 概念 型 問い hit|partial|miss|dunno|skip [ズレ] [備考]   手で記録する(照合なし)
#   record.sh --path                                                              log.md の場所
#   型 trace | edge | summary。next.sh の pending と場所・関数・概念・型が一致しないと exit 7。
# 追記後、その行が読めることを確かめ(読めなければ exit 6 で取り消す)、pending と keys を消し、vault を作り直す。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REPO=""; PATHONLY=""; FREE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --path) PATHONLY=1; shift ;;
    --free) FREE=1; shift ;;
    --help|-h) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; break ;;
    -*) echo "record.sh: unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
. "$HERE/lang.sh"
if [ -z "$REPO" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "record.sh: $(L r_norepo)" >&2; exit 3; }
  REPO=$(basename "$top")
fi
log="$ROOT/$REPO/log.md"; pending="$ROOT/$REPO/pending"; keys="$ROOT/$REPO/keys"
if [ -n "$PATHONLY" ]; then echo "$log"; exit 0; fi
[ $# -ge 6 ] || { echo "record.sh: $(L r_usage) ($#)" >&2; exit 2; }

clean() { printf '%s' "$1" | tr '\n\t' '  ' | sed 's/|/｜/g; s/^ *//; s/ *$//'; }
rlabel() { case "$1" in hit) L rs_hit ;; partial) L rs_partial ;; miss) L rs_miss ;; dunno) L rs_dunno ;; skip) L rs_skip ;; *) echo "$1" ;; esac; }
place=$(clean "$1"); func=$(clean "$2"); concepts=$(clean "$3"); type=$(clean "$4"); q=$(clean "$5")
case "$type" in trace|edge|summary) ;; *) echo "record.sh: $(L r_type): $type" >&2; exit 2 ;; esac
printf '%s' "$place" | grep -Eq '^[^ ]+:[0-9]+-[0-9]+$' || { echo "record.sh: $(L r_place): $place" >&2; exit 2; }
[ -n "$concepts" ] || { echo "record.sh: $(L r_concepts)" >&2; exit 2; }

result=""; zure=""; note=""; usermsg=""
if [ "$6" = "--verdict" ]; then
  [ -n "${7:-}" ] || { echo "record.sh: $(L r_verdict)" >&2; exit 2; }
  verdict=$(printf '%s' "$7" | tr -d ' '); note=$(clean "${8:-}")
  [ -f "$keys" ] && [ -s "$keys" ] || { echo "record.sh: $(L r_nokeys)" >&2; exit 2; }
  nkeys=$(wc -l < "$keys" | tr -d ' ')
  nv=$(printf '%s\n' "$verdict" | tr ',' '\n' | wc -l | tr -d ' ')
  [ "$nv" -eq "$nkeys" ] || { echo "record.sh: $(L r_verdict) ($nv / $nkeys)" >&2; exit 2; }
  eval "$(printf '%s\n' "$verdict" | tr ',' '\n' | paste "$keys" - | awk -F'\t' -v l_missing="$(L r_missing)" -v l_contra="$(L r_contra)" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    { v = trim($3); t = $2; ref = ""; if (match(t, /@ *[0-9]+(-[0-9]+)?[ ]*$/)) { ref = substr(t, RSTART); sub(/^@ */, "", ref); t = trim(substr(t, 1, RSTART - 1)) }
      if (v == "yes") { yes++; next }
      if (v == "no") { no++; z = z (z == "" ? "" : "; ") l_missing ": " t (ref != "" ? " @" ref : ""); u = u (u == "" ? "" : ", ") (ref != "" ? "L" ref : "#" $1); next }
      if (v == "contra") { contra++; z = z (z == "" ? "" : "; ") l_contra ": " t (ref != "" ? " @" ref : ""); uc = uc (uc == "" ? "" : ", ") (ref != "" ? "L" ref : "#" $1); next }
      bad = 1 }
    END { if (bad) { print "BAD=1"; exit }
      r = (contra > 0 ? "miss" : no > 0 ? "partial" : "hit")
      printf("result=%s\nyes=%d\nzure=\"%s\"\nmissing=\"%s\"\ncontras=\"%s\"\n", r, yes, z, u, uc) }' )"
  [ "${BAD:-}" = "" ] || { echo "record.sh: $(L r_verdict): $verdict" >&2; exit 2; }
  usermsg=$(printf "%s($(L r_keys_of))" "$(rlabel "$result")" "$yes" "$nkeys")
  [ -n "$missing" ] && usermsg="$usermsg — $(L r_missing): $missing"
  [ -n "$contras" ] && usermsg="$usermsg — $(L r_contra): $contras"
else
  result=$(clean "$6"); zure=$(clean "${7:-}"); note=$(clean "${8:-}")
  if [ -n "$FREE" ]; then
    case "$result" in hit|partial|miss|dunno|skip) ;; *) echo "record.sh: $(L r_result): $result" >&2; exit 2 ;; esac
  else
    case "$result" in dunno|skip) ;; *) echo "record.sh: $(L r_result): $result" >&2; exit 2 ;; esac
  fi
fi

if [ -z "$FREE" ] && [ -f "$pending" ]; then
  want=$(cat "$pending"); got=$(printf '%s\t%s\t%s\t%s' "$place" "$func" "$concepts" "$type")
  if [ "$want" != "$got" ]; then
    printf 'record.sh: %s\n  %s: %s\n  %s: %s\n  %s\n' "$(L r_pending)" "$(L r_decided)" "$(printf '%s' "$want" | tr '\t' '|')" "$(L r_given)" "$(printf '%s' "$got" | tr '\t' '|')" "$(L r_free)" >&2
    exit 7
  fi
fi

mkdir -p "$(dirname "$log")"
[ -f "$log" ] || printf '# hidane — %s\n\n%s\n|---|---|---|---|---|---|---|---|---|\n' "$REPO" "$(L log_header)" > "$log"
before=$(grep -c '^| 20' "$log" || true)
line=$(printf '| %s | %s | %s | %s | %s | %s | %s | %s | %s |' "$(date '+%Y-%m-%d %H:%M')" "$place" "$func" "$concepts" "$type" "$q" "$result" "$zure" "$note")
printf '%s\n' "$line" >> "$log"
after=$(grep -c '^| 20' "$log" || true)
cols=$(printf '%s' "$line" | tr -cd '|' | wc -c | tr -d ' ')
if [ "$after" -ne $((before + 1)) ] || [ "$cols" -ne 10 ]; then
  sed '$d' "$log" > "$log.tmp" && mv "$log.tmp" "$log"
  echo "record.sh: $(L r_undo) ($cols)" >&2; exit 6
fi
[ -n "$usermsg" ] && echo "$usermsg"
echo "$line"
if [ -z "$FREE" ]; then rm -f "$pending" "$keys"; fi
sh "$HERE/pages.sh" --root "$ROOT" >/dev/null 2>&1 || true
