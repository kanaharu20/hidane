#!/bin/sh
# keys.sh と record.sh --verdict の L0 検査(鍵で結果を決める)。
set -u
cd "$(dirname "$0")/.." || exit 2
export HIDANE_LANG=ja
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/root"; mkdir -p "$ROOT/p"; export HIDANE_VAULT="$TMP/vault"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }
K="sh scripts/keys.sh --root $ROOT --repo p"; R="sh scripts/record.sh --root $ROOT --repo p"
pend() { printf 'a.c:1-9\tf\t境界条件\tedge\n' > "$ROOT/p/pending"; }
fourkeys() { $K "stopped を立てる @ 26" "wake_all を呼ぶ @ 27" "作った分だけ join する @ 28-29" "1 を返す" >/dev/null; }

$K "x" "y" >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 5 ] && grep -q 'pending' "$TMP/e" && ok "K01 pending が無ければ鍵を置けない(exit 5)" || ng "K01" "rc=$rc"
pend; $K "x" >/dev/null 2>&1; rc=$?; [ $rc = 2 ] && [ ! -f "$ROOT/p/keys" ] && ok "K02 鍵 1 個は exit 2" || ng "K02" "rc=$rc"
$K "a" "b" "c" "d" "e" "f" >/dev/null 2>&1; rc=$?; [ $rc = 2 ] && ok "K03 鍵 6 個は exit 2" || ng "K03" "rc=$rc"
fourkeys; [ "$(sed -n 3p "$ROOT/p/keys")" = "$(printf '3\t作った分だけ join する @ 28-29')" ] && ok "K04 鍵は番号つきで保存される" || ng "K04" "$(cat "$ROOT/p/keys")"
[ "$($K --show | wc -l | tr -d ' ')" = 4 ] && ok "K05 --show で 4 行" || ng "K05"
$K "a|b" "c" >/dev/null; grep -q 'a｜b' "$ROOT/p/keys" && ok "K06 鍵の | は ｜ に" || ng "K06"

# --verdict → 結果
fourkeys
o=$($R "a.c:1-9" f "境界条件" edge "q" --verdict "yes,yes,yes,yes"); rc=$?
{ [ $rc = 0 ] && echo "$o" | sed -n 1p | grep -q '^当たり(鍵 4 / 4)$' && echo "$o" | grep -q '| hit |  |  |$' && [ ! -f "$ROOT/p/keys" ] && [ ! -f "$ROOT/p/pending" ]; } && ok "V01 全部 yes → hit、鍵と pending は消える" || ng "V01" "rc=$rc $o"
[ "$(echo "$o" | wc -l | tr -d ' ')" = 2 ] && ok "V01b hit のときは案内を出さない(2 行だけ)" || ng "V01b" "$o"
pend; fourkeys
o=$($R "a.c:1-9" f "境界条件" edge "q" --verdict "yes,yes,no,yes")
{ echo "$o" | sed -n 1p | grep -q '^部分(鍵 3 / 4) — 触れていない: L28-29$' && echo "$o" | grep -q '| partial | 触れていない: 作った分だけ join する @28-29 |'; } && ok "V02 no が 1 つ → partial。ユーザーには行番号、log には鍵の文" || ng "V02" "$o"
echo "$o" | sed -n 3p | grep -q '^解説が要るなら /hidane --explain' && ok "V02b partial のとき 3 行目に --explain への案内" || ng "V02b hint" "$o"
pend; fourkeys
o=$($R "a.c:1-9" f "境界条件" edge "q" --verdict "yes,contra,no,no")
{ echo "$o" | sed -n 1p | grep -q '^ズレ(鍵 1 / 4) — 触れていない: L28-29, #4 — 逆: L27$' && echo "$o" | grep -q '| miss | 逆: wake_all を呼ぶ @27; 触れていない: 作った分だけ join する @28-29; 触れていない: 1 を返す |'; } && ok "V03 contra があれば miss。行の無い鍵は #番号" || ng "V03" "$o"
pend; fourkeys
$R "a.c:1-9" f "境界条件" edge "q" --verdict "yes,yes,no" >/dev/null 2>"$TMP/e"; rc=$?
{ [ $rc = 2 ] && grep -q '3 / 4' "$TMP/e" && [ -f "$ROOT/p/keys" ] && [ "$(grep -c '^| 20' "$ROOT/p/log.md")" = 3 ]; } && ok "V04 判定の個数が鍵と違えば exit 2、書かない、鍵は残る" || ng "V04" "rc=$rc $(cat "$TMP/e")"
$R "a.c:1-9" f "境界条件" edge "q" --verdict "yes,yes,maybe,yes" >/dev/null 2>&1; rc=$?; [ $rc = 2 ] && ok "V05 yes/no/contra 以外は exit 2" || ng "V05" "rc=$rc"
rm -f "$ROOT/p/keys"; $R "a.c:1-9" f "境界条件" edge "q" --verdict "yes,yes,yes,yes" >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 2 ] && grep -q 'keys.sh' "$TMP/e" && ok "V06 鍵が無ければ --verdict は exit 2" || ng "V06" "rc=$rc"
$R "a.c:1-9" f "境界条件" edge "q" hit >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 2 ] && ok "V07 hit を直接渡すのは exit 2(--free 以外)" || ng "V07" "rc=$rc"
o=$($R "a.c:1-9" f "境界条件" edge "q" dunno); echo "$o" | grep -q '| dunno |  |  |$' && ok "V08 dunno は鍵なしで書ける" || ng "V08" "$o"
o=$($R --free "b.c:1-2" g "x" trace "q" partial "手で"); echo "$o" | grep -q '| partial | 手で |' && ok "V09 --free なら partial を直接書ける" || ng "V09" "$o"
# map: partial は証拠だが値は動かない
o=$(sh scripts/map.sh --root "$ROOT" --today "$(date +%Y-%m-%d)"); echo "$o" | grep -q '^| 境界条件 | -2 | 4 |' && ok "V10 map: partial は証拠に数えるが値は動かない(hit+2, partial 0, miss-2, dunno-2 → -2 / 4)" || ng "V10 map" "$(echo "$o" | grep 境界条件)"
echo; echo "PASS $pass / FAIL $fail"; [ $fail -eq 0 ]
