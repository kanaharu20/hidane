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
#   型 trace | edge(summary は 0.5.1 で廃止。旧行は map.sh が重み 3 で読む)。next.sh の pending が無い、pending と場所・関数・概念・型が違う、鍵が今の pending のものでない、のどれでも exit 7(--free 以外)。
# 追記後、その行が読めることを確かめ(読めなければ exit 6 で取り消す)、pending と keys を消し、vault を作り直す。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REPO=""; PATHONLY=""; FREE=""; DISPUTE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --path) PATHONLY=1; shift ;;
    --free) FREE=1; shift ;;
    --dispute) DISPUTE=1; shift ;;
    --help|-h) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; break ;;
    -*) echo "record.sh: unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
. "$HERE/lang.sh"
top=""
if [ -z "$REPO" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "record.sh: $(L r_norepo)" >&2; exit 3; }
  REPO=$(hidane_repo_key "$top")
fi
log="$ROOT/$REPO/log.md"; pending="$ROOT/$REPO/pending"; keys="$ROOT/$REPO/keys"
if [ -n "$PATHONLY" ]; then echo "$log"; exit 0; fi   # 問い合わせ。何も書かない
# 異議: 直前の記録の鍵 N に「間違い」を 1 行追記する。値・状態は変えない(map.sh は dispute 行を読まない)
if [ -n "$DISPUTE" ]; then
  [ $# -ge 2 ] && [ -n "$2" ] || { echo "record.sh: $(L r_dispute_usage)" >&2; exit 2; }
  kl="$ROOT/$REPO/keys.last"
  [ -f "$kl" ] && [ -s "$kl" ] && [ -f "$log" ] || { echo "record.sh: $(L r_nolast)" >&2; exit 2; }
  nk=$(wc -l < "$kl" | tr -d ' '); n=$(printf '%s' "$1" | tr -d ' ')
  printf '%s' "$n" | grep -Eq '^[0-9]+$' && [ "$n" -ge 1 ] && [ "$n" -le "$nk" ] || { printf "record.sh: $(L r_nokeyn)\n" "$1" "$nk" >&2; exit 2; }
  ktext=$(sed -n "${n}p" "$kl" | cut -f2)
  last=$(grep '^| 20' "$log" | grep -v '| dispute |' | tail -1)
  [ -n "$last" ] || { echo "record.sh: $(L r_nolast)" >&2; exit 2; }
  lp=$(printf '%s' "$last" | awk -F'|' '{ gsub(/^ +| +$/, "", $3); print $3 }'); lf=$(printf '%s' "$last" | awk -F'|' '{ gsub(/^ +| +$/, "", $4); print $4 }')
  lc=$(printf '%s' "$last" | awk -F'|' '{ gsub(/^ +| +$/, "", $5); print $5 }'); lt=$(printf '%s' "$last" | awk -F'|' '{ gsub(/^ +| +$/, "", $6); print $6 }')
  ld=$(printf '%s' "$last" | awk -F'|' '{ gsub(/^ +| +$/, "", $2); print $2 }')
  reason=$(printf '%s' "$2" | tr '\n\t' '  ' | sed 's/|/｜/g; s/^ *//; s/ *$//')
  line=$(printf '| %s | %s | %s | %s | %s | %s %s: %s | dispute | %s | %s |' "$(date '+%Y-%m-%d %H:%M')" "$lp" "$lf" "$lc" "$lt" "$(L h_key)" "$n" "$ktext" "$reason" "$ld")
  printf '%s\n' "$line" >> "$log"
  echo "$(L r_disputed)"; echo "$line"
  sh "$HERE/pages.sh" --root "$ROOT" >/dev/null 2>&1 || true
  exit 0
fi
[ $# -ge 6 ] || { echo "record.sh: $(L r_usage) ($#)" >&2; exit 2; }
if [ -z "$FREE" ]; then [ -f "$pending" ] || { echo "record.sh: $(L r_nopending)" >&2; exit 7; }; [ -f "$ROOT/$REPO/question" ] || { echo "record.sh: $(L r_noquestion)" >&2; exit 2; }; fi

clean() { printf '%s' "$1" | tr '\n\t' '  ' | sed 's/|/｜/g; s/^ *//; s/ *$//'; }
rlabel() { case "$1" in hit) L rs_hit ;; partial) L rs_partial ;; miss) L rs_miss ;; dunno) L rs_dunno ;; skip) L rs_skip ;; *) echo "$1" ;; esac; }
place=$(clean "$1"); func=$(clean "$2"); concepts=$(clean "$3"); type=$(clean "$4"); q=$(clean "$5")
case "$type" in trace|edge) ;; *) echo "record.sh: $(L r_type): $type" >&2; exit 2 ;; esac
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
  # 鍵が今の pending のものか(keys.sh が pending の写しを keys.pending に残す)
  if [ -z "$FREE" ] && ! cmp -s "$keys.pending" "$pending" 2>/dev/null; then echo "record.sh: $(L r_keysstale)" >&2; exit 7; fi
  # 判定は awk が一時ファイルに 1 行 1 項目で書く。eval は使わない(鍵の文にバッククォートや $( ) があっても実行されない)
  pf=$(mktemp); trap 'rm -f "$pf"' EXIT
  printf '%s\n' "$verdict" | tr ',' '\n' | paste "$keys" - | awk -F'\t' -v l_missing="$(L r_missing)" -v l_contra="$(L r_contra)" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    { v = trim($3); t = $2; ref = ""; if (match(t, /@ *[0-9]+(-[0-9]+)?[ ]*$/)) { ref = substr(t, RSTART); sub(/^@ */, "", ref); t = trim(substr(t, 1, RSTART - 1)) }
      kind = ""; if (match(t, /^[^:]+: /)) { kind = substr(t, 1, RSTART + RLENGTH - 3) " " }
      loc = (ref != "" ? "L" ref : "#" $1)
      if (v == "yes") { yes++; next }
      if (v == "no") { no++; z = z (z == "" ? "" : "; ") l_missing ": " t (ref != "" ? " @" ref : ""); u = u (u == "" ? "" : ", ") kind loc; next }
      if (v == "contra") { contra++; z = z (z == "" ? "" : "; ") l_contra ": " t (ref != "" ? " @" ref : ""); uc = uc (uc == "" ? "" : ", ") kind loc; next }
      bad = 1 }
    END { if (bad) { print "bad\t1"; exit }
      r = (contra > 0 ? "miss" : no > 0 ? "partial" : "hit")
      printf("result\t%s\nyes\t%d\nzure\t%s\nmissing\t%s\ncontras\t%s\n", r, yes, z, u, uc) }' > "$pf"
  pick() { awk -F'\t' -v k="$1" '$1 == k { print substr($0, length(k) + 2) }' "$pf"; }
  [ -z "$(pick bad)" ] || { echo "record.sh: $(L r_verdict): $verdict" >&2; exit 2; }
  result=$(pick result); yes=$(pick yes); zure=$(pick zure); missing=$(pick missing); contras=$(pick contras)
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

lead=""
if [ -z "$FREE" ] && [ -f "$pending" ]; then
  want=$(cut -f1-4 "$pending"); got=$(printf '%s\t%s\t%s\t%s' "$place" "$func" "$concepts" "$type"); lead=$(cut -f5 "$pending")
  if [ "$want" != "$got" ]; then
    printf 'record.sh: %s\n  %s: %s\n  %s: %s\n  %s\n' "$(L r_pending)" "$(L r_decided)" "$(printf '%s' "$want" | tr '\t' '|')" "$(L r_given)" "$(printf '%s' "$got" | tr '\t' '|')" "$(L r_free)" >&2
    exit 7
  fi
fi

# 代表概念(next.sh が狙った概念)に * を付ける。map.sh はそれを満額、他を半分で数える
if [ -n "$lead" ]; then concepts=$(printf '%s' "$concepts" | awk -F', ' -v l="$lead" '{ for (i = 1; i <= NF; i++) printf("%s%s%s", (i > 1 ? ", " : ""), ($i == l ? "*" : ""), $i) }'); fi
mkdir -p "$(dirname "$log")"; [ -z "$top" ] || printf '%s\n' "$top" > "$ROOT/$REPO/path"
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
case "$result" in partial|miss) if [ -n "$usermsg" ]; then
  # 答えの後にだけ鍵を全部見せる(どれが当たり・触れていない・逆か)
  echo "$(L r_keys_show)"
  printf '%s\n' "$verdict" | tr ',' '\n' | paste "$keys" - | awk -F'\t' -v y="$(L rs_hit)" -v n="$(L r_missing)" -v c="$(L r_contra)" '{ v = $3; gsub(/^ +| +$/, "", v); printf("  %s. %s [%s]\n", $1, $2, (v == "yes" ? y : v == "no" ? n : c)) }'
  echo "$(L r_hint)"
fi ;; esac
if [ -z "$FREE" ]; then [ ! -f "$keys" ] || cp "$keys" "$keys.last"; rm -f "$pending" "$keys" "$keys.pending" "$keys.end" "$ROOT/$REPO/question"; fi   # keys.last は --dispute 用
# 集中モードの残りを 1 つ減らす。0 になれば終わりを告げて消す
ff="$ROOT/$REPO/focus"
if [ -z "$FREE" ] && [ -f "$ff" ]; then
  fc=$(cut -f1 "$ff"); fleft=$(( $(cut -f2 "$ff") - 1 ))
  if [ "$fleft" -le 0 ]; then rm -f "$ff"; printf "$(L r_focus_done)\n" "$fc" "${HIDANE_FOCUS_N:-3}"; else printf '%s\t%s\n' "$fc" "$fleft" > "$ff"; fi
fi
sh "$HERE/pages.sh" --root "$ROOT" >/dev/null 2>&1 || true
