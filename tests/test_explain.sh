#!/bin/sh
# explained.sh と index.md の「入口」の L0 検査。解説は状態に影響しない。
set -u
cd "$(dirname "$0")/.." || exit 2
export HIDANE_LANG=ja
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/root"; mkdir -p "$ROOT/w"; cp tests/fixtures/worker/log.md "$ROOT/w/"; export HIDANE_VAULT="$TMP/vault"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }
X="sh scripts/explained.sh --root $ROOT --repo w"
before=$(sh scripts/map.sh --root "$ROOT" --today 2026-09-08)

o=$($X "printf の戻り値" "境界条件, 無い概念" 2>"$TMP/e")
{ echo "$o" | grep -q '| w | printf の戻り値 | 境界条件 |$' && grep -q '地図に無い概念は捨てた: 無い概念' "$TMP/e" && [ "$(grep -c '^| 20' "$ROOT/explained.md")" = 1 ] && head -1 "$ROOT/explained.md" | grep -q '状態には影響しない'; } \
  && ok "X01 explained.md に 1 行。地図に無い概念は捨てて stderr" || ng "X01" "$o $(cat "$TMP/e")"
o=$($X "この設計でいいか" ""); echo "$o" | grep -q '| この設計でいいか |  |$' && ok "X02 概念が空でも残せる" || ng "X02" "$o"
$X "" >/dev/null 2>&1; rc=$?; [ $rc = 2 ] && ok "X03 対象が空なら exit 2" || ng "X03" "rc=$rc"
o=$($X "a|b" "境界条件"); echo "$o" | grep -q '| a｜b |' && ok "X04 対象の | は ｜ に" || ng "X04" "$o"
after=$(sh scripts/map.sh --root "$ROOT" --today 2026-09-08); [ "$before" = "$after" ] && ok "X05 解説の記録は値も状態も変えない" || ng "X05 state changed"
{ grep -q '^## 最近求めた解説$' "$TMP/vault/index.md" && grep -q '^- | 20[0-9-]* [0-9:]* | w | printf の戻り値 | 境界条件 |$' "$TMP/vault/index.md" && ! grep -q '(まだ無い)' "$TMP/vault/index.md"; } \
  && ok "X06 index.md の「最近求めた解説」に出る" || ng "X06 index" "$(sed -n '1,14p' "$TMP/vault/index.md")"
for i in 1 2 3 4 5 6; do $X "t$i" "" >/dev/null; done
[ "$(sed -n '/^## 最近求めた解説$/,/^## 概念$/p' "$TMP/vault/index.md" | grep -c '^- ')" = 5 ] && ok "X07 最近の解説は 5 件まで" || ng "X07 five" "$(sed -n '/最近求めた/,/概念/p' "$TMP/vault/index.md")"
! grep -q '解説' "$TMP/vault/concepts/境界条件.md" && ok "X08 概念ページには解説の印を付けない" || ng "X08 page mark"
o=$(cd "$TMP" && HIDANE_ROOT="$ROOT" HIDANE_VAULT="$TMP/vault" sh "$OLDPWD/scripts/explained.sh" "外で" ""); echo "$o" | grep -q '| - | 外で |' && ok "X09 git の外では repo は -" || ng "X09" "$o"
echo; echo "PASS $pass / FAIL $fail"; [ $fail -eq 0 ]
