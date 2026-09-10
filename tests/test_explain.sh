#!/bin/sh
# profile.sh と、解説後の next.sh の振る舞いの L0 検査。
set -u
cd "$(dirname "$0")/.." || exit 2
export HIDANE_LANG=ja
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/root"; mkdir -p "$ROOT/w"; export HIDANE_VAULT="$TMP/vault"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }
H='| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | ズレ | 備考 |
|---|---|---|---|---|---|---|---|---|'
F='| 日付 | 場所 | 関数 | 概念 | commit | 備考 |
|---|---|---|---|---|---|'
# 排他制御 = 非理解(-6)、境界条件 = 曖昧(-1)、早期リターン = 理解(+6)、再帰 = 未出題
cat > "$ROOT/w/log.md" <<L
$H
| 2026-09-01 | a.c:1-9 | a | 排他制御 | summary | q | miss | lock を持ったまま return |  |
| 2026-09-02 | b.c:1-9 | b | 排他制御 | summary | q | miss | unlock の順序 |  |
| 2026-09-03 | c.c:1-9 | c | 境界条件 | trace | q | miss | n=0 |  |
| 2026-09-04 | d.c:1-9 | d | 早期リターン | summary | q | hit |  |  |
| 2026-09-05 | e.c:1-9 | e | 早期リターン | summary | q | hit |  |  |
| 2026-09-06 | f.c:1-9 | f | 境界条件, 排他制御 | trace | q | hit |  |  |
L
cat > "$ROOT/w/functions.md" <<L
$F
| 2026-09-07 | g.c:1-20 | g | 排他制御, 境界条件, 早期リターン, 再帰 | x |  |
| 2026-09-07 | h.c:1-5 | h | 再帰 | x |  |
L
P="sh scripts/profile.sh --root $ROOT --repo w --today 2026-09-08"; N="sh scripts/next.sh --root $ROOT --repo w"

o=$($P g)
{ echo "$o" | grep -q '^場所: g.c:1-20$' && echo "$o" | grep -q '^- 排他制御 \[非理解, -5\]: 膨らませる。.*過去のズレ: lock を持ったまま return; unlock の順序' && echo "$o" | grep -q '^- 境界条件 \[曖昧, +0\]: 普通に述べる。過去のズレ: n=0' && echo "$o" | grep -q '^- 早期リターン \[理解, +6\]: 飛ばす' && echo "$o" | grep -q '^- 再帰 \[未出題\]: 一言だけ'; } \
  && ok "E01 概念ごとの指示: 非理解=膨らませる(過去のズレつき)、曖昧=普通、理解=飛ばす、未出題=一言" || ng "E01 directives" "$o"
echo "$o" | grep -q '^長さの目安(行): 12$' && ok "E02 長さの目安 = 2 + 6×1 + 3×1 + 1×1 = 12" || ng "E02 length" "$(echo "$o" | grep 長さ)"
{ echo "$o" | grep -q '^順: ' && echo "$o" | grep -q '^規則: 問いを出さない'; } && ok "E03 順と規則が出る" || ng "E03"
[ "$(grep -c '^| 20' "$ROOT/w/explained.md")" = 1 ] && grep -q '| 2026-09-08 | g.c:1-20 | g |' "$ROOT/w/explained.md" && head -1 "$ROOT/w/explained.md" | grep -q '^| date |' && ok "E04 explained.md に見出しつきで 1 行残る" || ng "E04 explained" "$(cat "$ROOT/w/explained.md")"
o=$($P "g.c:1-20"); echo "$o" | grep -q '^関数: g$' && ok "E05 場所でも指定できる" || ng "E05 by place"
o=$($P); echo "$o" | grep -q '^場所: f.c:1-9$' && echo "$o" | grep -q '直前に問うた関数' && ok "E06 引数なしは直前に問うた関数" || ng "E06 last" "$o"
$P nope >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 1 ] && grep -q '記録に無い' "$TMP/e" && ok "E07 無い関数は exit 1" || ng "E07" "rc=$rc"

# next.sh: 解説の当日は除外、1〜3 日後は最優先、備考が pending → record へ
printf '| date | place | function | concepts |\n|---|---|---|---|\n| 2026-09-08 | g.c:1-20 | g | 排他制御, 境界条件, 早期リターン, 再帰 |\n' > "$ROOT/w/explained.md"
o=$($N --today 2026-09-08); echo "$o" | grep -q '^場所: h.c:1-5$' && ok "E08 解説した当日は候補から外れる(g でなく h)" || ng "E08 same day" "$o"
o=$($N --today 2026-09-10); echo "$o" | grep -q '^場所: g.c:1-20$' && echo "$o" | grep -q '解説の 2 日後' && ok "E09 2 日後は最優先で、理由に「解説の 2 日後」" || ng "E09 boost" "$o"
[ "$(cut -f5 "$ROOT/w/pending")" = "解説の 2 日後" ] && ok "E10 pending の 5 列目に備考" || ng "E10 pending" "$(cat "$ROOT/w/pending")"
o=$(sh scripts/record.sh --root $ROOT --repo w "g.c:1-20" g "排他制御, 境界条件, 早期リターン, 再帰" edge "q" dunno); echo "$o" | grep -q '| dunno |  | 解説の 2 日後 |' && ok "E11 record.sh が備考に「解説の 2 日後」を入れる(照合は 4 列)" || ng "E11 note" "$o"
o=$($N --today 2026-09-20 2>&1); echo "$o" | grep -q '^場所: h.c:1-5$' && ok "E12 4 日以上経てば普通の順(g は問うたので h)" || ng "E12" "$o"
echo; echo "PASS $pass / FAIL $fail"; [ $fail -eq 0 ]
