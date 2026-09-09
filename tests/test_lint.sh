#!/bin/sh
# resolve.sh と lint.sh の L0 検査。claude は偽物。
set -u
cd "$(dirname "$0")/.." || exit 2
export HIDANE_LANG=ja
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/root"; mkdir -p "$ROOT/worker" "$ROOT/api"; export HIDANE_VAULT="$TMP/vault"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }
H='| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | miss | 備考 |
|---|---|---|---|---|---|---|---|---|'
F='| 日付 | 場所 | 関数 | 概念 | commit | 備考 |
|---|---|---|---|---|---|'
cat > "$ROOT/worker/log.md" <<L
$H
| 2026-09-05 | a.c:1-5 | a | 境界条件 | trace | q | miss | n=1 |  |
| 2026-09-06 | b.c:1-5 | b | 境界条件, ヒープ操作 | trace | q | miss |  |  |
L
cat > "$ROOT/api/log.md" <<L
$H
| 2026-09-07 | c.py:1-5 | c | 末尾要素の扱い | trace | q | dunno |  |  |
L
cat > "$ROOT/api/functions.md" <<L
$F
| 2026-09-08 | d.py:1-9 | d | 端の処理, 転置索引の走査 | x |  |
L
M="sh scripts/map.sh --root $ROOT --today 2026-09-08"

# 別名なし: そのまま
o=$($M); echo "$o" | grep -q '^| 末尾要素の扱い | -1 |' && echo "$o" | grep -q '^| 端の処理 | +0 |' && ok "L01 aliases.md が無ければ名前はそのまま" || ng "L01" "$o"

# 別名: 末尾要素の扱い → 境界条件、端の処理 → 末尾要素の扱い(連鎖)
printf '# aliases\n\n| 日付 | 旧名 | 新名 | 理由 |\n|---|---|---|---|\n| 2026-09-08 | 末尾要素の扱い | 境界条件 | 同義 |\n| 2026-09-08 | 端の処理 | 末尾要素の扱い | 同義 |\n' > "$ROOT/aliases.md"
o=$($M)
{ echo "$o" | grep -q '^| 境界条件 | -3 | 3 | 2026-09-07 | 曖昧 | api,worker |' && ! echo "$o" | grep -q '末尾要素の扱い' && ! echo "$o" | grep -q '端の処理'; } \
  && ok "L02 統合後は値が合流(−1−1−1 = −3)、repo は両方、旧名は表から消える(連鎖も解く)" || ng "L02 合流" "$o"
r=$(printf 'x\tlog\t| 2026-09-08 | e.c:1-2 | e | 端の処理, 境界条件, 末尾要素の扱い | trace | q | hit |  |  |\n' | sh scripts/resolve.sh --root "$ROOT")
[ "$r" = "x	log	| 2026-09-08 | e.c:1-2 | e | 境界条件 | trace | q | hit |  |  |" ] && ok "L03 同じ概念に解ける名前は 1 つにまとまる。前置きのタブ列は保たれる" || ng "L03 dedupe" "$r"

# pages: 新名のページに aliases、旧名のページは無い
sh scripts/pages.sh --root "$ROOT" --vault "$TMP/vault" --today 2026-09-08 >/dev/null
{ grep -q '^aliases: \[末尾要素の扱い, 端の処理\]$' "$TMP/vault/concepts/境界条件.md" && [ ! -f "$TMP/vault/concepts/末尾要素の扱い.md" ] && grep -q 'd.py:1-9' "$TMP/vault/concepts/境界条件.md"; } \
  && ok "L04 概念ページの frontmatter に aliases、旧名のページは作らない、旧名の関数は新名のページに" || ng "L04 pages" "$(sed -n '1,8p' "$TMP/vault/concepts/境界条件.md")"

# next.sh は解いた名前を出す → pending も解いた名前
o=$(sh scripts/next.sh --root "$ROOT" --repo api --today 2026-09-08); grep -q '境界条件' "$ROOT/api/pending" && ! grep -q '端の処理' "$ROOT/api/pending" && ok "L05 next.sh の pending は解いた名前" || ng "L05 next" "$(cat "$ROOT/api/pending")"

# lint: 偽 claude が 良い 1 組 + 悪い 5 行 を返す
rm "$ROOT/aliases.md"
FAKE="$TMP/claude"; cat > "$FAKE" <<'Q'
#!/bin/sh
cat > /dev/null
printf '端の処理\t境界条件\t同義\n'
printf '境界条件\t境界条件\t同じ\n'
printf '存在しない\t境界条件\t\n'
printf 'ヒープ操作\t新しい名前\t\n'
printf 'ヒープ操作\n'
printf 'なし\n'
Q
chmod +x "$FAKE"
HIDANE_CLAUDE="$FAKE" sh scripts/lint.sh --root "$ROOT" > "$TMP/o" 2> "$TMP/e"; rc=$?
{ [ $rc = 0 ] && grep -q '統合 1 組、捨てた 4 行' "$TMP/o" && grep -q '^| 20[0-9-]* | 端の処理 | 境界条件 | 同義 |$' "$ROOT/aliases.md" && [ "$(grep -c '^| 20' "$ROOT/aliases.md")" = 1 ]; } \
  && ok "L06 lint: 良い 1 組だけ aliases.md に、同名・無い名前・新しい名前・列不足は捨てる、「なし」は無視" || ng "L06 lint" "rc=$rc $(cat "$TMP/o" "$TMP/e")"
[ -f "$ROOT/.lint-stamp" ] && [ "$(cat "$ROOT/.lint-stamp")" = "$(date +%Y-%m-%d)" ] && ok "L07 実行日が stamp に残る" || ng "L07 stamp"

# 循環: 境界条件 → 端の処理 は、端の処理 → 境界条件 があるので捨てる
printf '#!/bin/sh\ncat >/dev/null\nprintf "境界条件\\t端の処理\\t逆\\n"\n' > "$FAKE"
HIDANE_CLAUDE="$FAKE" sh scripts/lint.sh --root "$ROOT" > /dev/null 2> "$TMP/e"
{ grep -q '循環\|新名が一覧に無い' "$TMP/e" && [ "$(grep -c '^| 20' "$ROOT/aliases.md")" = 1 ]; } && ok "L08 循環する統合は捨てる" || ng "L08 循環" "$(cat "$TMP/e")"

# --if-due: 今日やったので何もしない(偽 claude は呼ばれない)。HIDANE_LINT_DAYS=0 なら動く
: > "$TMP/count"; printf '#!/bin/sh\necho x >> "%s"\ncat >/dev/null\necho なし\n' "$TMP/count" > "$FAKE"
HIDANE_CLAUDE="$FAKE" sh scripts/lint.sh --root "$ROOT" --if-due >/dev/null 2>&1
[ "$(wc -l < "$TMP/count" | tr -d ' ')" = 0 ] && ok "L09 --if-due: 今日済んでいれば呼ばない" || ng "L09 if-due"
HIDANE_CLAUDE="$FAKE" HIDANE_LINT_DAYS=0 sh scripts/lint.sh --root "$ROOT" --if-due >/dev/null 2>&1
[ "$(wc -l < "$TMP/count" | tr -d ' ')" = 1 ] && ok "L10 --if-due: 期限が来ていれば呼ぶ" || ng "L10 if-due days=0"

# dry-run にはプロンプトに概念一覧(解いた名前)と関数名が入る
d=$(sh scripts/lint.sh --root "$ROOT" --dry-run); echo "$d" | grep -q '^- 境界条件(' && echo "$d" | grep -q '関数: ' && ! echo "$d" | grep -q '^- 端の処理' && ok "L11 dry-run: 概念一覧は別名を解いた後の名前" || ng "L11 dry-run" "$(echo "$d" | tail -5)"

echo; echo "PASS $pass / FAIL $fail"; [ $fail -eq 0 ]
