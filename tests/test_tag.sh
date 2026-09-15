#!/bin/sh
# tag.sh と hook の L0 検査。claude は偽物(HIDANE_CLAUDE)に差し替える。LLM は呼ばない。
set -u
cd "$(dirname "$0")/.." || exit 2
export HIDANE_LANG=ja
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
printf '| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | miss | 備考 |\n|---|---|---|---|---|---|---|---|---|\n| 2026-09-01 | x.c:1-2 | f | 境界条件 | trace | q | hit |  |  |\n' > "$ROOT/other/log.md"

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
{ [ -f "$ROOT/vault/concepts/早期リターン.md" ] && grep -q '^state: unasked$' "$ROOT/vault/concepts/早期リターン.md" && grep -q 'clamp' "$ROOT/vault/concepts/早期リターン.md"; } \
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

# G15 上限なし: 関数 25 個の repo を --all で回すと候補 25(以前は上位 20 で切れていた)
R4="$TMP/proj4"; mkdir -p "$R4"; (cd "$R4" && git init -q && git config user.email t@t && git config user.name t
  for i in $(seq 1 25); do printf 'int h%s(int x)\n{\n\treturn x + %s;\n}\n' $i $i > "h$i.c"; done; git add -A && git commit -qm init)
: > "$FAKE_COUNT"
HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$R4" --root "$ROOT" --all > "$TMP/o5" 2>/dev/null
{ grep -q '候補 25、呼び出し 4 回、追記 25 行' "$TMP/o5" && [ "$(grep -c '^| 20' "$ROOT/proj4/functions.md")" = 25 ]; } && ok "G15 --all は 20 件で切れずに全関数を候補にする" || ng "G15 上限" "$(cat "$TMP/o5")"

# G16 Python の複数行 import は関数ではない。3 行の関数(def + docstring + 1 行)は候補になる
R5="$TMP/proj5"; mkdir -p "$R5"; (cd "$R5" && git init -q && git config user.email t@t && git config user.name t
  printf 'from .models import (\n    A,\n    B,\n    C,\n    D,\n)\n\n\ndef main() -> None:\n    """Dispatch."""\n    fire.Fire(Cli)\n' > cli.py; git add -A && git commit -qm init)
o=$(cd "$R5" && sh "$OLDPWD/scripts/scope.sh" --all 2>/dev/null); { echo "$o" | grep -q 'cli.py:9-11 *main' && ! echo "$o" | grep -q 'import'; } && ok "G16 複数行 import は候補にしない。3 行の関数は候補にする" || ng "G16 import" "$o"

# G17 C: 「struct timeval x;」の宣言で関数を割らない。ヘッダの複数行プロトタイプと Makefile は候補にしない
R6="$TMP/proj6"; mkdir -p "$R6/src" "$R6/incl"; (cd "$R6" && git init -q && git config user.email t@t && git config user.name t
  printf 'long\tdeadline_of(t_dongle *d)\n{\n\tstruct timespec\tdeadline;\n\n\tif (d->state != 1)\n\t\treturn (0);\n\treturn (d->t);\n}\n' > src/cool.c
  printf 'int\t\terror_arg(const char *name, const char *value,\n\t\t\tconst char *why);\nvoid\tenqueue_both(t_coder *coder, t_dongle *f,\n\t\t\tlong key);\n' > incl/header.h
  printf 'all: $(NAME)\n\n$(NAME): $(OBJ)\n\t$(CC) $(OBJ) -o $(NAME)\n' > Makefile
  git add -A && git commit -qm init)
o=$(cd "$R6" && sh "$OLDPWD/scripts/scope.sh" --all 2>/dev/null); { echo "$o" | grep -q 'src/cool.c:1-8 *deadline_of' && ! echo "$o" | grep -q 'src/cool.c:3' && ! echo "$o" | grep -q 'header.h' && ! echo "$o" | grep -q 'Makefile'; } \
  && ok "G17 struct の局所宣言で割らない。プロトタイプ・Makefile は候補にしない" || ng "G17 C 誤検出" "$o"
# G18 --bg: 候補の数を 1 行出してすぐ戻り、追記は背景で hook.log に集計が残る
R7="$TMP/proj7"; mkdir -p "$R7"; (cd "$R7" && git init -q && git config user.email t@t && git config user.name t
  for i in 1 2 3 4 5; do printf 'int k%s(int x)\n{\n\treturn x * %s;\n}\n' $i $i > "k$i.c"; done; git add -A && git commit -qm init)
: > "$FAKE_COUNT"; rm -f "$ROOT/hook.log"
o=$(HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$R7" --root "$ROOT" --all --bg 2>&1); rc=$?
i=0; while [ $i -lt 40 ] && ! grep -q '候補' "$ROOT/hook.log" 2>/dev/null; do sleep 0.25; i=$((i+1)); done
{ [ $rc = 0 ] && echo "$o" | grep -q '^tag.sh: 候補 5 件。背景で' && grep -q '候補 5、呼び出し 1 回、追記 5 行' "$ROOT/hook.log" && [ "$(grep -c '^| 20' "$ROOT/proj7/functions.md")" = 5 ]; } \
  && ok "G18 --bg は候補数の 1 行で戻り、背景で付けて hook.log に集計" || ng "G18 bg" "rc=$rc $o $(cat "$ROOT/hook.log" 2>&1)"

# G19 commit が 1 つも無い repo、未追跡のファイルでも --all は動く(記録の commit 欄は -)。作業ツリーの中身を送る
R8="$TMP/proj8"; mkdir -p "$R8"; (cd "$R8" && git init -q && git config user.email t@t && git config user.name t
  printf 'int fresh(int x)\n{\n\treturn x + 1;\n}\n' > fresh.c; printf 'obj/\n' > .gitignore; mkdir obj; printf 'int ignored(int x)\n{\n\treturn x;\n}\n' > obj/i.c)
: > "$FAKE_COUNT"
HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$R8" --root "$ROOT" --all > "$TMP/o8" 2>"$TMP/e8"; rc=$?
{ [ $rc = 0 ] && grep -q '候補 1、呼び出し 1 回、追記 1 行' "$TMP/o8" && grep -q '^| 20[0-9-]* | fresh.c:1-4 | fresh | 算術 | - |' "$ROOT/proj8/functions.md" && ! grep -q ignored "$ROOT/proj8/functions.md"; } \
  && ok "G19 commit 無し・未追跡でも --all は付く(commit 欄は -)。.gitignore のものは拾わない" || ng "G19 no commit" "rc=$rc $(cat "$TMP/o8" "$TMP/e8"; cat "$ROOT/proj8/functions.md" 2>&1)"
d=$(HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$R2" --root "$ROOT" --all --dry-run 2>/dev/null | head -3); printf 'int f1(int x)\n{\n\treturn x + 100;\n}\n' > "$R2/f1.c"
printf '%s\n| 2026-09-09 | x.c:1-2 | zz | c | abc |  |\n' "$(head -3 "$ROOT/proj2/functions.md")" > "$ROOT/proj2/functions.md"
d=$(HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$R2" --root "$ROOT" --all --dry-run 2>/dev/null); echo "$d" | grep -q 'x + 100' && ok "G20 --all は作業ツリーの中身を送る(HEAD ではない)" || ng "G20 worktree" "$(echo "$d" | grep -n 'f1' | head -3)"

# G21 同じ repo で 2 つ同時に走らせない(鍵ディレクトリ)。--bg の親も止まる
mkdir -p "$ROOT/proj7/.tag.lock"; touch "$R7/k6.c"; printf 'int k6(int x)\n{\n\treturn x;\n}\n' > "$R7/k6.c"
HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$R7" --root "$ROOT" --all >/dev/null 2>"$TMP/e9"; rc=$?
HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$R7" --root "$ROOT" --all --bg >/dev/null 2>"$TMP/e10"; rc2=$?
{ [ $rc = 5 ] && [ $rc2 = 5 ] && grep -q '別の tag.sh' "$TMP/e9" && [ "$(grep -c '^| 20' "$ROOT/proj7/functions.md")" = 5 ]; } && ok "G21 鍵があれば exit 5、何も付けない(--bg も)" || ng "G21 lock" "rc=$rc rc2=$rc2 $(cat "$TMP/e9")"
rmdir "$ROOT/proj7/.tag.lock"
# G22 --commit は行番号も中身もその commit の木から(作業ツリーが先にずれていても一致する)
R9="$TMP/proj9"; mkdir -p "$R9/src"; (cd "$R9" && git init -q && git config user.email t@t && git config user.name t
  printf 'int committed(int v)\n{\n\tif (v > 0)\n\t\treturn v;\n\treturn 0;\n}\n' > src/a.c && git add -A && git commit -qm one
  printf '/* 1 */\n/* 2 */\n/* 3 */\n/* 4 */\n/* 5 */\n' | cat - src/a.c > src/a.c.new && mv src/a.c.new src/a.c)
d=$(HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$R9" --root "$ROOT" --commit HEAD --dry-run 2>/dev/null)
{ echo "$d" | grep -q '^### src/a.c:1-6	committed' && echo "$d" | grep -A2 '^### src/a.c:1-6' | grep -q '^int committed'; } && ok "G22 --commit は commit の木で範囲と中身を揃える" || ng "G22 commit tree" "$(echo "$d" | grep -n 'a.c\|committed' | head -5)"
# G23 scope.sh の既出除外は 関数 列で(ズレ列ではない)。partial の行でも除ける
R10="$TMP/proj10"; mkdir -p "$R10/src" "$ROOT/proj10"; (cd "$R10" && git init -q && git config user.email t@t && git config user.name t
  printf 'int asked_fn(int v)\n{\n\treturn v;\n}\n' > src/a.c && printf 'int other_fn(int v)\n{\n\treturn v;\n}\n' > src/b.c && git add -A && git commit -qm one)
printf '| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | ズレ | 備考 |\n|---|---|---|---|---|---|---|---|---|\n| 2026-09-09 | src/a.c:7-10 | asked_fn | c | trace | q | partial | 触れていない: x @5 |  |\n' > "$ROOT/proj10/log.md"
o=$(cd "$R10" && HIDANE_ROOT="$ROOT" sh "$OLDPWD/scripts/scope.sh" --all 2>/dev/null); { ! echo "$o" | grep -q 'asked_fn' && echo "$o" | grep -q 'other_fn'; } && ok "G23 問うた関数は行がずれても scope.sh の候補から外れる" || ng "G23 asked" "$o"
# G24 functions.md が見出しだけでも log.md の既知は読む(set -e で落ちない)
printf '| 日付 | 場所 | 関数 | 概念 | commit | 備考 |\n|---|---|---|---|---|---|\n' > "$ROOT/proj10/functions.md"
printf '| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | ズレ | 備考 |\n|---|---|---|---|---|---|---|---|---|\n| 2026-09-09 | src/b.c:1-4 | other_fn | c | trace | q | hit |  |  |\n' > "$ROOT/proj10/log.md"
d=$(HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$R10" --root "$ROOT" --all --dry-run 2>/dev/null); { ! echo "$d" | grep -q '^### src/b.c' && echo "$d" | grep -q '^### src/a.c'; } && ok "G24 見出しだけの functions.md でも log.md の既知は除く" || ng "G24 set -e" "$(echo "$d" | grep '^###')"
# G25 同じ basename の別 repo は別の置き場(basename-<数字>)。同じ repo は同じ置き場
mkdir -p "$TMP/one/api" "$TMP/two/api"; for p in "$TMP/one/api" "$TMP/two/api"; do (cd "$p" && git init -q && git config user.email t@t && git config user.name t && printf 'int f(int x)\n{\n\treturn x;\n}\n' > f.c && git add -A && git commit -qm i); done
HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$TMP/one/api" --root "$ROOT" --all >/dev/null 2>&1
HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$TMP/two/api" --root "$ROOT" --all >/dev/null 2>&1
HIDANE_CLAUDE="$FAKE" sh scripts/tag.sh --repo "$TMP/one/api" --root "$ROOT" --all >/dev/null 2>&1
one=$(cd "$TMP/one/api" && pwd -P); two=$(cd "$TMP/two/api" && pwd -P)
n=$(ls -d "$ROOT"/api* | wc -l | tr -d ' '); { [ "$n" = 2 ] && [ "$(cat "$ROOT/api/path")" = "$one" ] && [ "$(grep -c '^| 20' "$ROOT/api/functions.md")" = 1 ] && grep -qF "$two" "$ROOT"/api-*/path; } && ok "G25 同名の別 repo は api-<数字> に分かれ、同じ repo は同じ置き場" || ng "G25 repo key" "$(ls "$ROOT"; cat "$ROOT"/api*/path)"

# G26 ファイル名に使えない概念名(先頭 .、..、/ を含む)は捨てる
R12="$TMP/proj12"; mkdir -p "$R12"; (cd "$R12" && git init -q && git config user.email t@t && git config user.name t && printf 'int nm(int x)\n{\n\treturn x;\n}\n' > nm.c && git add -A && git commit -qm i)
cat > "$TMP/badname" <<'F'
#!/bin/sh
grep '^### ' | sed 's/^### //' | awk -F'\t' '{ printf("%s\t%s\t.hidden, a/b, x..y, 正常な名前\n", $1, $2) }'
F
chmod +x "$TMP/badname"
HIDANE_CLAUDE="$TMP/badname" sh scripts/tag.sh --repo "$R12" --root "$ROOT" --all >/dev/null 2>"$TMP/e12"
{ grep -q '| nm.c:1-4 | nm | 正常な名前 |' "$ROOT/proj12/functions.md" && [ "$(grep -c '名前に使えない' "$TMP/e12")" = 3 ]; } && ok "G26 ファイル名に使えない概念名は捨て、残りで付ける" || ng "G26 names" "$(cat "$ROOT/proj12/functions.md" "$TMP/e12")"

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

# H07 hook は HEAD を文字で渡さず、その時の commit に解決して渡す
grep -q 'git rev-parse HEAD' hooks/post-commit && grep -q -- '--commit "\$rev"' hooks/post-commit && ok "H07 hook は commit の hash を固定して背景に渡す" || ng "H07 hook rev"
# H08 core.hooksPath があればそこに置く。置けなければ exit 5 で「置けなかった」
R11="$TMP/proj11"; mkdir -p "$R11" "$TMP/hp"; (cd "$R11" && git init -q && git config core.hooksPath "$TMP/hp")
(cd "$R11" && sh "$H/install.sh" --hook >/dev/null 2>&1); rc=$?; { [ $rc = 0 ] && grep -q hidane-hook "$TMP/hp/post-commit"; } && ok "H08 core.hooksPath の場所に置く" || ng "H08 hooksPath" "rc=$rc $(ls "$TMP/hp")"
(cd "$R11" && git config core.hooksPath /nonexistent-dir/x && sh "$H/install.sh" --hook > "$TMP/h8" 2>&1); rc=$?; { [ $rc = 5 ] && grep -q '置けなかった' "$TMP/h8"; } && ok "H08b 置けなければ exit 5" || ng "H08b" "rc=$rc $(cat "$TMP/h8")"

# I01 install.sh 引数なし: skill + hook + 全関数タグ + 地図、を非対話で一度に
R2="$TMP/setup"; mkdir -p "$R2/src"; (cd "$R2" && git init -q && git config user.email t@t && git config user.name t && printf 'int one(void)\n{\n\treturn 1;\n}\n' > src/one.c && git add -A && git commit -qm init)
cat > "$FAKE" <<'F'
#!/bin/sh
grep '^### ' | sed 's/^### //' | awk -F'\t' '{ printf("%s\t%s\t定数の返却\n", $1, $2) }'
F
ROOT2="$TMP/root2"; export HIDANE_VAULT="$TMP/vault2"
(cd "$R2" && HIDANE_ROOT="$ROOT2" HIDANE_SKILL_DIR="$TMP/skill2" HIDANE_CLAUDE="$FAKE" sh "$H/install.sh" --lang ja < /dev/null > "$TMP/setup.out" 2>&1); rc=$?
{ [ $rc = 0 ] && [ -f "$TMP/skill2/SKILL.md" ] && grep -q hidane-hook "$R2/.git/hooks/post-commit" && grep -q '| src/one.c:1-4 | one | 定数の返却 |' "$ROOT2/setup/functions.md" && [ -f "$TMP/vault2/concepts/定数の返却.md" ] && grep -q 'Obsidian' "$TMP/setup.out"; } \
  && ok "I01 install.sh 一発で skill・hook・タグ付け・地図まで揃う" || ng "I01 setup" "rc=$rc $(cat "$TMP/setup.out")"
(cd "$TMP" && HIDANE_ROOT="$ROOT2" HIDANE_SKILL_DIR="$TMP/skill2" sh "$H/install.sh" --lang ja < /dev/null > "$TMP/setup2.out" 2>&1); grep -q 'git リポジトリの外' "$TMP/setup2.out" && ok "I02 リポジトリの外では skill だけ置いて案内する" || ng "I02" "$(cat "$TMP/setup2.out")"

echo; echo "PASS $pass / FAIL $fail"
[ $fail -eq 0 ]
