#!/bin/sh
# ask.sh(問いの検査)と record.sh --dispute(異議)の L0 検査。
set -u
cd "$(dirname "$0")/.." || exit 2
export HIDANE_LANG=ja
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/root"; mkdir -p "$ROOT/p"; export HIDANE_VAULT="$TMP/vault"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }
K="sh scripts/keys.sh --root $ROOT --repo p"; A="sh scripts/ask.sh --root $ROOT --repo p"; R="sh scripts/record.sh --root $ROOT --repo p"
pend() { printf 'src/a.c:10-20\tf\t境界条件\tedge\t境界条件\n' > "$ROOT/p/pending"; }
keys() { $K "呼び出し: wake_all を呼ぶ @12" "順序: unlock の前に呼ぶ @13" "分岐: n が 0 なら呼ばない @11" >/dev/null; }
GOOD="src/a.c f。
待ち手が 1 人もいないとき、ロックを放すまでにどの関数がどの順で呼ばれますか。そうなる条件も添えてください。"

$A "x" >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 5 ] && ok "A01 pending が無ければ exit 5" || ng "A01" "rc=$rc"
pend; $A "x" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 5 ] && grep -q 'keys.sh' "$TMP/e"; } && ok "A02 鍵が無ければ exit 5" || ng "A02" "rc=$rc $(cat "$TMP/e")"
keys; [ -f "$ROOT/p/keys.end" ] && ok "A03 keys.sh は結びを keys.end に残す" || ng "A03"
o=$($A "$GOOD"); rc=$?; { [ $rc = 0 ] && [ "$o" = "$GOOD" ] && [ "$(cat "$ROOT/p/question")" = "$GOOD" ]; } && ok "A04 通れば問いをそのまま出し、question に保存する" || ng "A04" "rc=$rc $o"
$A "src/a.c f。
11 行の条件で n が 0 のとき、どの関数がどの順で呼ばれますか。そうなる条件も添えてください" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 2 ] && grep -q '行番号' "$TMP/e"; } && ok "A05 行番号を含む問いは exit 2" || ng "A05" "rc=$rc $(cat "$TMP/e")"
$A "src/a.c f。
n == 0 のとき、どの関数がどの順で呼ばれますか。そうなる条件も添えてください" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 2 ] && grep -q '式' "$TMP/e"; } && ok "A06 式(==)を含む問いは exit 2" || ng "A06" "rc=$rc"
$A "src/a.c f。
n が 0 のとき、wake_all の前にどの関数がどの順で呼ばれますか。そうなる条件も添えてください" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 2 ] && grep -q 'wake_all' "$TMP/e"; } && ok "A07 呼び出しの鍵にある関数名を含む問いは exit 2" || ng "A07" "rc=$rc"
$A "src/a.c f。
n が 0 のとき、何を返しますか" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 2 ] && grep -q '結び' "$TMP/e"; } && ok "A08 結びで終わらない問いは exit 2" || ng "A08" "rc=$rc"
$A "src/a.c f。
1
2
3
4 どの関数がどの順で呼ばれますか。そうなる条件も添えてください" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 2 ] && grep -q '4 行以内' "$TMP/e"; } && ok "A09 5 行の問いは exit 2" || ng "A09" "rc=$rc"
$A "src/b.c g。
x のとき、どの関数がどの順で呼ばれますか。そうなる条件も添えてください" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 2 ] && grep -q '1 行目' "$TMP/e"; } && ok "A10 1 行目に場所と関数名が無ければ exit 2" || ng "A10" "rc=$rc"
HIDANE_LANG=en $K "call: wake_all @12" "order: before unlock @13" "branch: n is 0 @11" >/dev/null
o=$(HIDANE_LANG=en $A "src/a.c f.
Given no waiters, which functions are called, in what order? Include the condition that makes it so."); rc=$?; [ $rc = 0 ] && ok "A11 en の鍵と結びでも通る" || ng "A11" "rc=$rc $o"
pend; keys
# record.sh は question が無いと書かない
pend; keys; $R "src/a.c:10-20" f "境界条件" edge "q" --verdict "yes,no,contra" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 2 ] && grep -q 'ask.sh' "$TMP/e" && [ ! -f "$ROOT/p/log.md" ]; } && ok "A12 ask.sh を通っていなければ record.sh は exit 2" || ng "A12" "rc=$rc $(cat "$TMP/e")"
$R "src/a.c:10-20" f "境界条件" edge "q" dunno >/dev/null 2>&1; rc=$?; [ $rc = 2 ] && ok "A13 dunno も同じ" || ng "A13" "rc=$rc"
$A "$GOOD" >/dev/null; o=$($R "src/a.c:10-20" f "境界条件" edge "q" --verdict "yes,no,contra"); rc=$?
{ [ $rc = 0 ] && [ ! -f "$ROOT/p/question" ] && [ -f "$ROOT/p/keys.last" ] && [ ! -f "$ROOT/p/keys" ]; } && ok "A14 記録すると question と keys は消え、keys.last が残る" || ng "A14" "rc=$rc $(ls "$ROOT/p")"

# 異議
$R --dispute >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 2 ] && ok "D01 番号と理由が無ければ exit 2" || ng "D01" "rc=$rc"
$R --dispute 9 "x" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 2 ] && grep -q '鍵 9 は無い(1〜3)' "$TMP/e"; } && ok "D02 無い番号は exit 2" || ng "D02" "rc=$rc $(cat "$TMP/e")"
o=$($R --dispute 3 "n が 0 でも呼ぶので分岐ではない"); rc=$?
{ [ $rc = 0 ] && echo "$o" | sed -n 1p | grep -q '^異議を記録した' && echo "$o" | grep -q '| src/a.c:10-20 | f | \*境界条件 | edge | 鍵 3: 分岐: n が 0 なら呼ばない @11 | dispute | n が 0 でも呼ぶので分岐ではない | 20' && [ "$(grep -c '| dispute |' "$ROOT/p/log.md")" = 1 ]; } && ok "D03 異議は log.md に 1 行追記(場所・関数・概念・型は直前の記録から、鍵の文と理由、元の日時)" || ng "D03" "rc=$rc $o"
m=$(sh scripts/map.sh --root "$ROOT" --today "$(date +%Y-%m-%d)"); echo "$m" | grep -q '^| 境界条件 | -2 | 1 |' && ok "D04 map.sh は異議を値にも証拠にも数えない(-2 / 1 のまま)" || ng "D04" "$m"
grep -q '^- 異議: n が 0 でも呼ぶので分岐ではない(p, ' "$HIDANE_VAULT/concepts/境界条件.md" && ok "D05 概念ページのズレに「異議:」として出る" || ng "D05" "$(cat "$HIDANE_VAULT/concepts/境界条件.md")"
printf '| 日付 | 場所 | 関数 | 概念 | commit | 備考 |\n|---|---|---|---|---|---|\n| 2026-09-01 | src/a.c:30-40 | g | 境界条件 | abc | |\n' > "$ROOT/p/functions.md"
o=$(sh scripts/next.sh --root "$ROOT" --repo p 2>&1 || true); echo "$o" | grep -q '異議: n が 0 でも呼ぶので分岐ではない' && ok "D06 next.sh は過去のズレに異議も見せる(次の鍵作りの参考)" || ng "D06" "$o"
$R --free "src/a.c:10-20" f "境界条件" edge "q" hit >/dev/null 2>&1; rm -f "$ROOT/p/keys.last"
$R --dispute 1 "x" >/dev/null 2>"$TMP/e"; rc=$?; { [ $rc = 2 ] && grep -q '直前' "$TMP/e"; } && ok "D07 keys.last が無ければ異議は付けられない(直前の記録だけ)" || ng "D07" "rc=$rc $(cat "$TMP/e")"

echo; echo "PASS $pass / FAIL $fail"
[ $fail -eq 0 ]
