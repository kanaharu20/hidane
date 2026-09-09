#!/bin/sh
# tag.sh と hook の L0 検査。claude は偽物(HIDANE_CLAUDE)に差し替える。LLM は呼ばない。
set -u
cd "$(dirname "$0")/.." || exit 2
H=$(pwd -P)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }

# 試験用 repo: C の関数 2 つ
R="$TMP/proj"; mkdir -p "$R/src"; cd "$R" && git init -q && git config user.email t@t && git config user.name t
cat > src/a.c <<'C'
#include <stdlib.h>

int clamp(int v, int lo, int hi)
{
	if (v < lo)
		return lo;
	if (v > hi)
		return hi;
	return v;
}

int *make_buf(int n)
{
	int *p = malloc(sizeof(int) * n);
	if (!p)
		return NULL;
	for (int i = 0; i < n; i++)
		p[i] = 0;
	return p;
}
C
git add -A && git commit -qm init
cd "$H"
ROOT="$TMP/root"; mkdir -p "$ROOT/other"; export HIDANE_VAULT="$ROOT/vault"
# 既存の概念を 1 つ用意(別 repo の log)
printf '| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | ズレ | 備考 |\n|---|---|---|---|---|---|---|---|---|\n| 2026-09-01 | x.c:1-2 | f | 境界条件 | 追う | q | 当たり |  |  |\n' > "$ROOT/other/log.md"

# 偽 claude: 呼ばれた回数を数え、良い行 1・悪い行 3 を返す
FAKE="$TMP/claude"; cat > "$FAKE" <<'F'
#!/bin/sh
echo x >> "$FAKE_COUNT"
cat > /dev/null
printf 'src/a.c:3-10\tclamp\t境界条件, 早期リターン\n'
printf 'src/zzz.c:1-2\tnope\t何か\n'
printf 'こんにちは、付けました\n'
printf 'src/a.c:12-20\tmake_buf\t失敗時の解放|危険\n'
F
chmod +x "$FAKE"; export FAKE_COUNT="$TMP/count"; : > "$FAKE_COUNT"

# G01 dry-run: プロンプトに既存概念と関数のコードが入る
d=$(sh scripts/tag.sh --repo "$R" --root "$ROOT" --dry-run)
{ echo "$d" | grep -q '^- 境界条件$' && echo "$d" | grep -q '### src/a.c:3-10	clamp' && echo "$d" | grep -q 'return hi;'; } \
  && ok "G01 dry-run のプロンプトに既存概念・場所・コードが入る" || ng "G01 dry-run" "$(echo "$d" | head -20)"
[ "$(wc -l < "$FAKE_COUNT" | tr -d ' ')" = 0 ] && ok "G02 dry-run は claude を呼ばない" || ng "G02 dry-run が呼んだ"

# G03 本番: 良い行だけ追記、悪い行は捨てる
HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$R" --root "$ROOT" > "$TMP/o" 2> "$TMP/e"
fn="$ROOT/proj/functions.md"
{ [ "$(grep -c '^| 20' "$fn")" = 1 ] && grep -q '| src/a.c:3-10 | clamp | 境界条件, 早期リターン | ' "$fn"; } && ok "G03 良い 1 行だけ functions.md に追記" || ng "G03 追記" "$(cat "$fn" "$TMP/e")"
grep -q '新: 早期リターン' "$fn" && ok "G04 既存に無い概念は 備考 に 新: と出る(既存の 境界条件 は出ない)" || ng "G04 新" "$(tail -1 "$fn")"
[ "$(grep -c '捨てた' "$TMP/e")" = 3 ] && ok "G05 悪い 3 行は捨てて stderr に理由" || ng "G05 捨てた数" "$(cat "$TMP/e")"
grep -q '候補 2、呼び出し 1 回、追記 1 行、捨てた 3 行' "$TMP/o" && ok "G06 結果の 1 行(候補 2 / 呼び出し 1 / 追記 1 / 捨てた 3)" || ng "G06 結果行" "$(cat "$TMP/o")"
short=$(cd "$R" && git rev-parse --short HEAD); grep -q "| $short |" "$fn" && ok "G07 commit の短縮ハッシュが入る" || ng "G07 hash"

# G08 vault が更新され、未出題の概念ページができる
{ [ -f "$ROOT/vault/concepts/早期リターン.md" ] && grep -q '^state: 未出題$' "$ROOT/vault/concepts/早期リターン.md" && grep -q 'clamp' "$ROOT/vault/concepts/早期リターン.md"; } \
  && ok "G08 tag のあと vault に 未出題 のページができる" || ng "G08 vault" "$(ls "$ROOT/vault/concepts" 2>&1)"

# G09 もう一度: clamp は既知なので候補は make_buf だけ → 偽 claude の答えは全部落ちて追記 0
HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$R" --root "$ROOT" > "$TMP/o2" 2>/dev/null
{ grep -q '追記 0 行' "$TMP/o2" && [ "$(grep -c '^| 20' "$fn")" = 1 ]; } && ok "G09 同じ場所には二度付けない" || ng "G09 再実行" "$(cat "$TMP/o2")"
d2=$(sh scripts/tag.sh --repo "$R" --root "$ROOT" --dry-run); { echo "$d2" | grep -q make_buf && ! echo "$d2" | grep -q '### src/a.c:3-10'; } && ok "G10 2 回目の候補は make_buf だけ" || ng "G10 候補" "$(echo "$d2" | grep '###')"

# G11 claude が失敗しても exit 4 で functions.md は壊れない
printf '#!/bin/sh\nexit 1\n' > "$TMP/bad"; chmod +x "$TMP/bad"
HIDANE_CLAUDE="$TMP/bad" sh scripts/tag.sh --repo "$R" --root "$ROOT" >/dev/null 2>&1; rc=$?
{ [ $rc = 4 ] && [ "$(grep -c '^| 20' "$fn")" = 1 ]; } && ok "G11 claude 失敗は exit 4、記録は無傷" || ng "G11 失敗時" "rc=$rc"

# G12 --all: リポジトリ全体が候補。既知(clamp)は飛ばし、make_buf だけ付く。fake は候補を読んで返す
cat > "$FAKE" <<'F'
#!/bin/sh
echo x >> "$FAKE_COUNT"
grep '^### ' | sed 's/^### //' | awk -F'\t' '{ printf("%s\t%s\t算術\n", $1, $2) }'
F
: > "$FAKE_COUNT"
HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$R" --root "$ROOT" --all > "$TMP/o3" 2>/dev/null
{ grep -q '候補 1、呼び出し 1 回、追記 1 行' "$TMP/o3" && grep -q '| src/a.c:12-20 | make_buf | 算術 |' "$fn"; } && ok "G12 --all は全体から、既知を飛ばして付ける" || ng "G12 --all" "$(cat "$TMP/o3"; tail -2 "$fn")"
# G13 束: 候補 5 を上限 2 で回すと呼び出し 3 回、全部付く
R2="$TMP/proj2"; mkdir -p "$R2"; (cd "$R2" && git init -q && git config user.email t@t && git config user.name t
  for i in 1 2 3 4 5; do printf 'int f%s(int x)\n{\n\treturn x + %s;\n}\n' $i $i > "f$i.c"; done; git add -A && git commit -qm init)
: > "$FAKE_COUNT"
HIDANE_CLAUDE="$FAKE" HIDANE_MAX_FUNCS=2 sh scripts/tag.sh --repo "$R2" --root "$ROOT" > "$TMP/o4" 2>/dev/null
{ grep -q '候補 5、呼び出し 3 回、追記 5 行、捨てた 0 行' "$TMP/o4" && [ "$(wc -l < "$FAKE_COUNT" | tr -d ' ')" = 3 ] && [ "$(grep -c '^| 20' "$ROOT/proj2/functions.md")" = 5 ]; } \
  && ok "G13 上限 2 で候補 5 → 3 回呼んで全部付く(上限で取りこぼさない)" || ng "G13 束" "$(cat "$TMP/o4")"
# G14 束の途中で claude が失敗しても、それまでの追記は残り exit 4
R3="$TMP/proj3"; mkdir -p "$R3"; (cd "$R3" && git init -q && git config user.email t@t && git config user.name t
  for i in 1 2 3; do printf 'int g%s(void)\n{\n\treturn %s;\n}\n' $i $i > "g$i.c"; done; git add -A && git commit -qm init)
cat > "$TMP/flaky" <<'F'
#!/bin/sh
n=$(wc -l < "$FAKE_COUNT" | tr -d ' '); echo x >> "$FAKE_COUNT"
[ "$n" -ge 1 ] && exit 1
grep '^### ' | sed 's/^### //' | awk -F'\t' '{ printf("%s\t%s\t定数\n", $1, $2) }'
F
chmod +x "$TMP/flaky"; : > "$FAKE_COUNT"
HIDANE_CLAUDE="$TMP/flaky" HIDANE_MAX_FUNCS=1 sh scripts/tag.sh --repo "$R3" --root "$ROOT" >/dev/null 2>"$TMP/e4"; rc=$?
{ [ $rc = 4 ] && [ "$(grep -c '^| 20' "$ROOT/proj3/functions.md")" = 1 ] && grep -q '束 2' "$TMP/e4"; } && ok "G14 2 束目で失敗: 1 束目の追記は残り exit 4" || ng "G14 途中失敗" "rc=$rc $(cat "$TMP/e4")"

# H01 hook: 置く → commit → 背景で functions.md が増える
(cd "$R" && sh "$H/install.sh" --hook >/dev/null) && grep -q "$H" "$R/.git/hooks/post-commit" && ok "H01 install.sh --hook が hidane の場所を埋めて置く" || ng "H01 install"
cat > "$FAKE" <<'F'
#!/bin/sh
# 候補(### 場所<TAB>名前)を読んで、全部に「算術」を付ける
grep '^### ' | sed 's/^### //' | awk -F'\t' '{ printf("%s\t%s\t算術\n", $1, $2) }'
F
n0=$(grep -c '^| 20' "$fn")
(cd "$R" && printf 'int square(int x)\n{\n\treturn x * x;\n}\n' > src/b.c && git add -A && HIDANE_CLAUDE="$FAKE" HIDANE_ROOT="$ROOT" git commit -qm two); rc=$?
[ $rc = 0 ] && ok "H02 hook があっても commit は成功" || ng "H02 commit rc=$rc"
i=0; while [ $i -lt 20 ] && ! grep -q 'square' "$fn" 2>/dev/null; do sleep 0.25; i=$((i+1)); done
grep -q '| src/b.c:1-4 | square | 算術 |' "$fn" && ok "H03 commit 後に背景で functions.md が増える" || ng "H03 背景タグ" "$(cat "$fn"; cat "$ROOT/hook.log" 2>/dev/null)"
[ "$(grep -c '^| 20' "$fn")" = $((n0 + 1)) ] && ok "H04 hook が付けるのはそのコミットが触った関数だけ(増えたのは 1 行)" || ng "H04 増分" "$(grep -c '^| 20' "$fn") vs $((n0 + 1))"

# H05 claude が無い環境では hook は黙って何もしない、commit は成功
(cd "$R" && echo '// c' >> src/b.c && git add -A && HIDANE_CLAUDE=/nonexistent/claude HIDANE_ROOT="$ROOT" git commit -qm three); rc=$?
sleep 0.5; [ $rc = 0 ] && [ "$(grep -c '^| 20' "$fn")" = $((n0 + 1)) ] && ok "H05 claude 無しでも commit 成功、記録は増えない" || ng "H05" "rc=$rc rows=$(grep -c '^| 20' "$fn")"

# H06 他人の hook は上書きしない、--unhook は hidane のだけ消す
(cd "$R" && sh "$H/install.sh" --unhook >/dev/null && printf '#!/bin/sh\necho mine\n' > .git/hooks/post-commit && sh "$H/install.sh" --hook >/dev/null 2>&1; rc=$?; [ $rc = 5 ] && grep -q mine .git/hooks/post-commit) \
  && ok "H06 他人の hook は触らず exit 5、--unhook は hidane のだけ消す" || ng "H06 上書き防止"

echo; echo "PASS $pass / FAIL $fail"
[ $fail -eq 0 ]
