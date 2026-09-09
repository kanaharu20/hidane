#!/bin/sh
# migrate.sh と install.sh --update の L0 検査。
set -u
cd "$(dirname "$0")/.." || exit 2
export HIDANE_LANG=ja
H=$(pwd -P)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }

# 古い形式(日本語の型・結果)の記録
ROOT="$TMP/root"; mkdir -p "$ROOT/old"
printf '| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | ズレ | 備考 |\n|---|---|---|---|---|---|---|---|---|\n| 2026-09-01 | a.c:1-2 | f | 境界条件 | 追う | q | 当たり |  |  |\n| 2026-09-02 | a.c:3-4 | g | 境界条件 | 追う(境界・変異) | q | 分からない |  |  |\n| 2026-09-03 | a.c:5-6 | h | 境界条件 | 要約 | q | ズレ | x |  |\n' > "$ROOT/old/log.md"
printf 'a.c:1-2\tf\t境界条件\t追う\n' > "$ROOT/old/pending"
o=$(sh scripts/migrate.sh --root "$ROOT")
{ grep -q '| trace | q | hit |' "$ROOT/old/log.md" && grep -q '| edge | q | dunno |' "$ROOT/old/log.md" && grep -q '| summary | q | miss |' "$ROOT/old/log.md" && [ -f "$ROOT/old/log.md.bak-1" ] && [ "$(cat "$ROOT/.version")" = 1 ] && [ ! -f "$ROOT/old/pending" ]; } \
  && ok "U01 段 1: 日本語の型・結果を記号に、退避を残し、古い pending を消し、.version=1" || ng "U01 migrate" "$o $(cat "$ROOT/old/log.md")"
cp "$ROOT/old/log.md" "$TMP/after1"; o=$(sh scripts/migrate.sh --root "$ROOT"); diff -q "$TMP/after1" "$ROOT/old/log.md" >/dev/null && echo "$o" | grep -q 'nothing to do' && ok "U02 2 回目は何もしない(冪等)" || ng "U02 idempotent" "$o"
m=$(sh scripts/map.sh --root "$ROOT" --today 2026-09-08); echo "$m" | grep -q '| 境界条件 | -4 | 3 |' && ok "U03 移行後の記録を map.sh が読める(+1 -2 -3 = -4)" || ng "U03 map after" "$m"
sh scripts/migrate.sh --root "$TMP/none" | grep -q 'no records' && ok "U04 記録が無ければ何もしない" || ng "U04"

# --update: 疑似リモートから新版を取ってくる
# 作業ツリーの今の状態(未コミット含む)を疑似リモートにする
cp -R "$H" "$TMP/src" && (cd "$TMP/src" && git config user.email t@t && git config user.name t && git add -A && git commit -qm wip --allow-empty)
BARE="$TMP/bare.git"; git clone -q --bare "$TMP/src" "$BARE"
git clone -q "$BARE" "$TMP/h1"; git clone -q "$BARE" "$TMP/h2"
(cd "$TMP/h2" && git config user.email t@t && git config user.name t && echo "0.1.1" > VERSION && echo "# new" >> CHANGELOG.md && git add -A && git commit -qm bump && git push -q origin HEAD)
ROOT2="$TMP/root2"; mkdir -p "$ROOT2"; echo 'lang=ja' > "$ROOT2/config"
o=$(cd "$TMP" && HIDANE_ROOT="$ROOT2" HIDANE_SKILL_DIR="$TMP/skill" HIDANE_VAULT="$TMP/vault" sh "$TMP/h1/install.sh" --update 2>&1); rc=$?
{ [ $rc = 0 ] && [ "$(cat "$TMP/h1/VERSION")" = "0.1.1" ] && [ "$(cat "$TMP/skill/VERSION")" = "0.1.1" ] && echo "$o" | grep -q '0.1.0 → 0.1.1' && [ "$(cat "$TMP/skill/HOME")" = "$(cd "$TMP/h1" && pwd -P)" ] && [ "$(cat "$ROOT2/.version")" = 1 ]; } \
  && ok "U05 --update: pull → skill 更新 → 移行、版の差を出す" || ng "U05 update" "rc=$rc $o"
o=$(cd "$TMP" && HIDANE_ROOT="$ROOT2" HIDANE_SKILL_DIR="$TMP/skill" HIDANE_VAULT="$TMP/vault" sh "$TMP/h1/install.sh" --update 2>&1); echo "$o" | grep -q '0.1.1 → 0.1.1' && ok "U06 最新なら版は変わらず、失敗もしない" || ng "U06" "$o"
[ "$(sh "$TMP/h1/install.sh" --version)" = "0.1.1" ] && ok "U07 --version" || ng "U07"
echo; echo "PASS $pass / FAIL $fail"; [ $fail -eq 0 ]
