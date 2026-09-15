#!/bin/sh
set -u
cd "$(dirname "$0")/.." || exit 2
export HIDANE_LANG=ja
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/root"; export HIDANE_VAULT="$TMP/vault"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }
R="sh scripts/record.sh --root $ROOT --repo proj"
prepq() { sh scripts/keys.sh --root "$ROOT" --repo proj "返り値: 1 @2" "分岐: x @3" >/dev/null; sh scripts/ask.sh --root "$ROOT" --repo proj "src/c.c cc。
x のとき、何を返しますか。そうなる条件も添えてください" >/dev/null; }
log="$ROOT/proj/log.md"

out=$($R --free "src/a.c:3-10" clamp "境界条件, 早期リターン" "trace" "v=hi のとき" "hit" 2>&1); rc=$?
{ [ $rc = 0 ] && [ -f "$log" ] && [ "$(grep -c '^| 20' "$log")" = 1 ] && grep -q '^| 日時 | 場所' "$log" && echo "$out" | grep -q '| src/a.c:3-10 | clamp | 境界条件, 早期リターン | trace | v=hi のとき | hit |  |  |'; } \
  && ok "R01 見出しを作って 1 行追記、その行を出す" || ng "R01" "rc=$rc $out"
$R --free "src/a.c:12-20" make_buf "部分失敗の巻き戻し" "edge" "何をする" "miss" "malloc 失敗 | NULL を返す
2 行目" >/dev/null 2>&1
{ [ "$(grep -c '^| 20' "$log")" = 2 ] && grep -q '| malloc 失敗 ｜ NULL を返す 2 行目 |' "$log"; } && ok "R02 | と改行は列を壊さない(｜ と空白に)" || ng "R02 escape" "$(tail -1 "$log")"
$R --free "src/a.c:1-2" f "x" "記述" "q" "hit" >/dev/null 2>"$TMP/e"; rc=$?
{ [ $rc = 2 ] && [ "$(grep -c '^| 20' "$log")" = 2 ] && grep -q '型は' "$TMP/e"; } && ok "R03 型が不正なら exit 2 で書かない" || ng "R03 型" "rc=$rc"
$R --free "src/a.c:1-2" f "x" "trace" "q" "だいたい" >/dev/null 2>&1; rc=$?
[ $rc = 2 ] && [ "$(grep -c '^| 20' "$log")" = 2 ] && ok "R04 結果が不正なら exit 2" || ng "R04 結果" "rc=$rc"
$R --free "src/a.c" f "x" "trace" "q" "hit" >/dev/null 2>&1; rc=$?
[ $rc = 2 ] && ok "R05 場所が file:a-b でなければ exit 2" || ng "R05 場所" "rc=$rc"
[ "$($R --path)" = "$log" ] && ok "R06 --path" || ng "R06 --path" "$($R --path)"
m=$(sh scripts/map.sh --root "$ROOT" --today 2026-09-08); echo "$m" | grep -q '読んだ行 2 / 使えた行 2' && echo "$m" | grep -q '| 部分失敗の巻き戻し | -2 |' && ok "R07 追記した行を map.sh が全部読める(要約 ズレ = -3)" || ng "R07 map" "$m"
[ -f "$TMP/vault/concepts/境界条件.md" ] && ok "R08 記録のあと vault が更新される" || ng "R08 vault"
# pending との照合
printf 'src/c.c:1-9\tcc\t境界条件\tedge\n' > "$ROOT/proj/pending"; prepq
$R "src/c.c:1-9" cc "境界条件" "trace" "q" "dunno" >/dev/null 2>"$TMP/e"; rc=$?
{ [ $rc = 7 ] && [ "$(grep -c '^| 20' "$log")" = 2 ] && grep -q '決定:' "$TMP/e" && [ -f "$ROOT/proj/pending" ]; } && ok "R09 型が next.sh の決定と違えば exit 7、書かない、pending は残る" || ng "R09 型不一致" "rc=$rc $(cat "$TMP/e")"
$R "src/c.c:1-9" cc "境界条件, 何か" "edge" "q" "dunno" >/dev/null 2>&1; rc=$?
[ $rc = 7 ] && ok "R10 概念が違えば exit 7" || ng "R10 概念不一致" "rc=$rc"
$R "src/c.c:1-9" cc "境界条件" "edge" "n=1 のとき" "dunno" >/dev/null 2>&1; rc=$?
{ [ $rc = 0 ] && [ "$(grep -c '^| 20' "$log")" = 3 ] && [ ! -f "$ROOT/proj/pending" ]; } && ok "R11 一致すれば書けて pending が消える" || ng "R11 一致" "rc=$rc"
printf 'src/c.c:1-9\tcc\t境界条件\ttrace\n' > "$ROOT/proj/pending"; prepq
$R --free "src/d.c:1-2" dd "x" "edge" "q" "hit" >/dev/null 2>&1; rc=$?
{ [ $rc = 0 ] && [ "$(grep -c '^| 20' "$log")" = 4 ] && [ -f "$ROOT/proj/pending" ]; } && ok "R12 --free は照合を飛ばし pending を消さない" || ng "R12 free" "rc=$rc"

# R13 代表概念に * が付き、map.sh は代表を満額、他を半分で数える(edge 当たり: 代表 +2、他 +1)
printf 'src/e.c:1-9\tee\t甲, 乙\tedge\t乙\n' > "$ROOT/proj/pending"
sh scripts/keys.sh --root "$ROOT" --repo proj "返り値: x @2" "分岐: y @3" >/dev/null; sh scripts/ask.sh --root "$ROOT" --repo proj "src/e.c ee。
x のとき、何を返しますか。そうなる条件も添えてください" >/dev/null
o=$($R "src/e.c:1-9" ee "甲, 乙" "edge" "q" --verdict "contra,no"); echo "$o" | grep -q '| 甲, \*乙 | edge |' && ok "R13 代表概念に * が付く" || ng "R13 mark" "$o"
m=$(sh scripts/map.sh --root "$ROOT" --today 2026-09-08); { echo "$m" | grep -q '| 乙 | -2 |' && echo "$m" | grep -q '| 甲 | -1 |'; } && ok "R13b 代表は満額(-2)、他は半分(-1)" || ng "R13b half" "$(echo "$m" | grep '甲\|乙')"
$R "src/e.c:1-9" ee "甲" "edge" "q" "dunno" >/dev/null 2>&1; rc=$?; [ $rc = 7 ] && ok "R13c pending の概念(4 列)と違えば exit 7 は変わらず" || ng "R13c" "rc=$rc"
echo; echo "PASS $pass / FAIL $fail"; [ $fail -eq 0 ]
