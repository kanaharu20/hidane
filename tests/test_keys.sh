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
fourkeys() { $K "状態: stopped を立てる @ 26" "呼び出し: wake_all を呼ぶ @ 27" "順序: 作った分だけ join する @ 28-29" "返り値: 1 を返す" >/dev/null; }

$K "x" "y" >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 5 ] && grep -q 'pending' "$TMP/e" && ok "K01 pending が無ければ鍵を置けない(exit 5)" || ng "K01" "rc=$rc"
pend; $K "x" >/dev/null 2>&1; rc=$?; [ $rc = 2 ] && [ ! -f "$ROOT/p/keys" ] && ok "K02 鍵 1 個は exit 2" || ng "K02" "rc=$rc"
$K "a" "b" "c" "d" "e" "f" >/dev/null 2>&1; rc=$?; [ $rc = 2 ] && ok "K03 鍵 6 個は exit 2" || ng "K03" "rc=$rc"
fourkeys; [ "$(sed -n 3p "$ROOT/p/keys")" = "$(printf '3\t順序: 作った分だけ join する @ 28-29')" ] && ok "K04 鍵は番号と種別つきで保存される" || ng "K04" "$(cat "$ROOT/p/keys")"
[ "$($K --show | wc -l | tr -d ' ')" = 4 ] && ok "K05 --show で 4 行" || ng "K05"
$K "返り値: a|b" "分岐: c" >/dev/null; grep -q 'a｜b' "$ROOT/p/keys" && ok "K06 鍵の | は ｜ に" || ng "K06"
$K "分岐: 59 行は is_done だけを見るので終わらない @59" "返り値: 1 を返す" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 2 ] && grep -q '鍵 1 は理由を含む' "$TMP/e" && [ ! -f "$ROOT/p/keys" ]; } && ok "K07 「ので」を含む鍵は exit 2、鍵は残らない" || ng "K07" "rc=$rc $(cat "$TMP/e")"
$K "branch: loop continues because is_done is false" "return: returns 1" >/dev/null 2>&1; rc=$?; [ $rc = 2 ] && ok "K08 because を含む鍵も exit 2" || ng "K08" "rc=$rc"
$K "stopped を立てる @ 26" "返り値: 1 を返す" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 2 ] && grep -q '鍵 1 に種別が無い' "$TMP/e" && [ ! -f "$ROOT/p/keys" ]; } && ok "K09 種別の無い鍵は exit 2" || ng "K09" "rc=$rc $(cat "$TMP/e")"
o=$($K "返り値: {start: 0} を返す @59" "分岐: 49 行で 1 回だけ取り出す @49" "分岐: 53 行の for は回らない @53" "状態: queue が空で while を抜ける @48")
{ echo "$o" | sed -n 2p | grep -q '^答えに含めるもの: 返り値 1、分岐 2、状態 1$' && echo "$o" | sed -n 3p | grep -q '問いの最後の行'; } && ok "K10 2 行目に種別と数だけの「答えに含めるもの」(中身と行は出ない)" || ng "K10" "$o"
o=$($K "return: 1 @5" "branch: x > 0 @3"); { grep -q '^1	返り値: 1 @5$' "$ROOT/p/keys" && echo "$o" | grep -q '^答えに含めるもの: 返り値 1、分岐 1$'; } && ok "K11 英語の種別も受け、表示言語の語で保存する" || ng "K11" "$o $(cat "$ROOT/p/keys")"
o=$(HIDANE_LANG=en $K "return: 1 @5" "branch: x > 0 @3" "branch: y @4"); echo "$o" | grep -q '^Include in your answer: return value 1, branch 2$' && ok "K12 en の答えに含めるもの" || ng "K12" "$o"

# --verdict → 結果
fourkeys
o=$($R "a.c:1-9" f "境界条件" edge "q" --verdict "yes,yes,yes,yes"); rc=$?
{ [ $rc = 0 ] && echo "$o" | sed -n 1p | grep -q '^当たり(鍵 4 / 4)$' && echo "$o" | grep -q '| hit |  |  |$' && [ ! -f "$ROOT/p/keys" ] && [ ! -f "$ROOT/p/pending" ]; } && ok "V01 全部 yes → hit、鍵と pending は消える" || ng "V01" "rc=$rc $o"
[ "$(echo "$o" | wc -l | tr -d ' ')" = 2 ] && ok "V01b hit のときは案内を出さない(2 行だけ)" || ng "V01b" "$o"
pend; fourkeys
o=$($R "a.c:1-9" f "境界条件" edge "q" --verdict "yes,yes,no,yes")
{ echo "$o" | sed -n 1p | grep -q '^部分(鍵 3 / 4) — 触れていない: 順序 L28-29$' && echo "$o" | grep -q '| partial | 触れていない: 順序: 作った分だけ join する @28-29 |'; } && ok "V02 no が 1 つ → partial。ユーザーには種別と行番号、log には鍵の文" || ng "V02" "$o"
echo "$o" | sed -n 3p | grep -q '^解説が要るなら「/hidane ' && ok "V02b partial のとき 3 行目に解説の案内" || ng "V02b hint" "$o"
pend; fourkeys
o=$($R "a.c:1-9" f "境界条件" edge "q" --verdict "yes,contra,no,no")
{ echo "$o" | sed -n 1p | grep -q '^ズレ(鍵 1 / 4) — 触れていない: 順序 L28-29, 返り値 #4 — 逆: 呼び出し L27$' && echo "$o" | grep -q '| miss | 逆: 呼び出し: wake_all を呼ぶ @27; 触れていない: 順序: 作った分だけ join する @28-29; 触れていない: 返り値: 1 を返す |'; } && ok "V03 contra があれば miss。行の無い鍵は #番号" || ng "V03" "$o"
pend; fourkeys
$R "a.c:1-9" f "境界条件" edge "q" --verdict "yes,yes,no" >/dev/null 2>"$TMP/e"; rc=$?
{ [ $rc = 2 ] && grep -q '3 / 4' "$TMP/e" && [ -f "$ROOT/p/keys" ] && [ "$(grep -c '^| 20' "$ROOT/p/log.md")" = 3 ]; } && ok "V04 判定の個数が鍵と違えば exit 2、書かない、鍵は残る" || ng "V04" "rc=$rc $(cat "$TMP/e")"
$R "a.c:1-9" f "境界条件" edge "q" --verdict "yes,yes,maybe,yes" >/dev/null 2>&1; rc=$?; [ $rc = 2 ] && ok "V05 yes/no/contra 以外は exit 2" || ng "V05" "rc=$rc"
rm -f "$ROOT/p/keys"; $R "a.c:1-9" f "境界条件" edge "q" --verdict "yes,yes,yes,yes" >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 2 ] && grep -q 'keys.sh' "$TMP/e" && ok "V06 鍵が無ければ --verdict は exit 2" || ng "V06" "rc=$rc"
$R "a.c:1-9" f "境界条件" edge "q" hit >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 2 ] && ok "V07 hit を直接渡すのは exit 2(--free 以外)" || ng "V07" "rc=$rc"
o=$($R "a.c:1-9" f "境界条件" edge "q" dunno); echo "$o" | grep -q '| dunno |  |  |$' && ok "V08 dunno は鍵なしで書ける" || ng "V08" "$o"
o=$($R --free "b.c:1-2" g "x" trace "q" partial "手で"); echo "$o" | grep -q '| partial | 手で |' && ok "V09 --free なら partial を直接書ける" || ng "V09" "$o"
# V11 鍵の文にバッククォートや $( ) があっても実行されない(eval を使わない)
pend; $K "返り値: \`touch $TMP/INJECTED\` を返す @ 5" "分岐: \$(touch $TMP/INJ2) @ 6" >/dev/null
o=$($R "a.c:1-9" f "境界条件" edge "q" --verdict "no,no" "")
{ [ ! -e "$TMP/INJECTED" ] && [ ! -e "$TMP/INJ2" ] && echo "$o" | grep -q 'touch' ; } && ok "V11 鍵の文は実行されず、そのまま log に残る" || ng "V11 eval" "$o"
# V12 鍵が別の問いのもの(鍵を置いた後に next.sh の決定が変わった)なら exit 7
pend; fourkeys; printf 'b.c:1-9\tg\t境界条件\tedge\n' > "$ROOT/p/pending"
$R "b.c:1-9" g "境界条件" edge "q" --verdict "yes,yes,yes,yes" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 7 ] && grep -q '別の問い' "$TMP/e"; } && ok "V12 鍵が今の pending のものでなければ exit 7" || ng "V12 stale keys" "rc=$rc $(cat "$TMP/e")"
# V13 pending が無ければ dunno も書かない(--free は書ける)
rm -f "$ROOT/p/pending" "$ROOT/p/keys" "$ROOT/p/keys.pending"
$R "zzz.c:1-2" nope x summary "q" dunno >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 7 ] && grep -q 'pending' "$TMP/e" && ok "V13 pending 無しの dunno は exit 7" || ng "V13" "rc=$rc $(cat "$TMP/e")"
# V14 --path は問い合わせだけ。ディレクトリも path も作らない
rm -rf "$TMP/rootq"; (cd "$TMP" && git init -q q >/dev/null 2>&1 && cd q && sh "$OLDPWD/scripts/record.sh" --root "$TMP/rootq" --path >/dev/null); [ ! -d "$TMP/rootq" ] && ok "V14 --path は何も作らない" || ng "V14 side effect" "$(ls -R "$TMP/rootq")"
# map: partial は証拠だが値は動かない
o=$(sh scripts/map.sh --root "$ROOT" --today "$(date +%Y-%m-%d)"); echo "$o" | grep -q '^| 境界条件 | -2 | 5 |' && ok "V10 map: partial は証拠に数えるが値は動かない(hit+2, partial 0, miss-2, dunno-2, partial 0 → -2 / 5)" || ng "V10 map" "$(echo "$o" | grep 境界条件)"
echo; echo "PASS $pass / FAIL $fail"; [ $fail -eq 0 ]
