#!/bin/sh
# 言語切替の L0 検査。記録は記号、表示だけ変わる。
set -u
cd "$(dirname "$0")/.." || exit 2
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
FX=tests/fixtures
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }

# X01 en の表: 見出しと状態が英語、値は ja と同じ
en=$(HIDANE_LANG=en sh scripts/map.sh --root $FX --today 2026-09-08); ja=$(HIDANE_LANG=ja sh scripts/map.sh --root $FX --today 2026-09-08)
{ echo "$en" | grep -q '^| Concept | Value | Evidence | Last | State | Repo |$' && echo "$en" | grep -q '| 停止フラグの伝搬 | -4 | 2 | 2026-09-06 | not understood | worker |' && echo "$en" | grep -q '| unasked |' && echo "$en" | grep -q '^rows read 15 / usable 15'; } \
  && ok "X01 en: 見出し・状態・脚注が英語" || ng "X01 en map" "$(echo "$en" | head -4)"
[ "$(echo "$en" | cut -d'|' -f2-4 | sed 1,2d | sed '$d')" = "$(echo "$ja" | cut -d'|' -f2-4 | sed 1,2d | sed '$d')" ] && ok "X02 en と ja で値の列は同じ" || ng "X02 値が違う"
# X03 --tsv は言語に依らず記号
[ "$(HIDANE_LANG=en sh scripts/map.sh --root $FX --today 2026-09-08 --tsv | cut -f5 | sort -u | tr '\n' ' ')" = "$(HIDANE_LANG=ja sh scripts/map.sh --root $FX --today 2026-09-08 --tsv | cut -f5 | sort -u | tr '\n' ' ')" ] && ok "X03 --tsv の状態は記号で言語に依らない" || ng "X03 tsv"
# X04 config で言語が決まる(HIDANE_LANG 未設定)
mkdir -p "$TMP/root/w"; cp $FX/worker/log.md "$TMP/root/w/log.md"; echo 'lang=en' > "$TMP/root/config"
o=$(env -u HIDANE_LANG sh scripts/map.sh --root "$TMP/root" --today 2026-09-08); echo "$o" | grep -q '^| Concept |' && ok "X04 <root>/config の lang=en が効く" || ng "X04 config" "$(echo "$o" | head -1)"
echo 'lang=ja' > "$TMP/root/config"; o=$(env -u HIDANE_LANG sh scripts/map.sh --root "$TMP/root" --today 2026-09-08); echo "$o" | grep -q '^| 概念 |' && ok "X05 config を ja にすると日本語" || ng "X05 config ja"
# X06 next.sh の en 出力
o=$(HIDANE_LANG=en sh scripts/next.sh --root $FX --repo worker --today 2026-09-08); { echo "$o" | grep -q '^Place: ' && echo "$o" | grep -q '^Type: trace (trace)$' && echo "$o" | grep -q '^Question form: exactly one question'; } && ok "X06 next.sh が英語で出る(型は記号+表示)" || ng "X06 next en" "$o"
# X07 record.sh の見出しと pages の本文が英語、frontmatter は記号
export HIDANE_VAULT="$TMP/vault"
HIDANE_LANG=en sh scripts/record.sh --free --root "$TMP/root" --repo z "a.c:1-2" f "boundary conditions" trace "q" hit >/dev/null 2>&1
{ grep -q '^| Date | Place | Function |' "$TMP/root/z/log.md" && grep -q '^state: fuzzy$' "$TMP/vault/concepts/boundary conditions.md" && grep -q '^## Records$' "$TMP/vault/concepts/boundary conditions.md" && grep -q 'trace — hit' "$TMP/vault/concepts/boundary conditions.md"; } \
  && ok "X07 record/pages: 見出しと節は英語、frontmatter は記号" || ng "X07 record en" "$(cat "$TMP/vault/concepts/boundary conditions.md" 2>&1 | head -12)"
# X08 record.sh のエラーも英語
HIDANE_LANG=en sh scripts/record.sh --free --root "$TMP/root" --repo z "a.c:1-2" f "x" 追う "q" hit >/dev/null 2>"$TMP/e"; grep -q 'type must be one of' "$TMP/e" && ok "X08 record.sh のエラーが英語(旧語彙は受け付けない)" || ng "X08" "$(cat "$TMP/e")"
# X09 tag.sh の en プロンプト
d=$(HIDANE_LANG=en sh scripts/tag.sh --repo . --root "$TMP/root" --dry-run 2>/dev/null || true)
echo "$d" | grep -q '^For each function below' && echo "$d" | grep -q '^## Functions' && ok "X09 tag.sh のプロンプトが英語" || ng "X09 tag en" "$(echo "$d" | head -3)"
# X10 install.sh --lang は config に書き、--skill は言語の SKILL を選ぶ
HIDANE_ROOT="$TMP/root2" HIDANE_SKILL_DIR="$TMP/skill" sh install.sh --skill --lang en >/dev/null && { [ "$(cat "$TMP/root2/config")" = "lang=en" ] && grep -q '^description: Pick one function' "$TMP/skill/SKILL.md"; } && ok "X10 install --skill --lang en: config と英語 SKILL" || ng "X10 install en" "$(cat "$TMP/root2/config" 2>&1; head -3 "$TMP/skill/SKILL.md")"
HIDANE_ROOT="$TMP/root2" HIDANE_SKILL_DIR="$TMP/skill" sh install.sh --skill --lang ja >/dev/null && { [ "$(cat "$TMP/root2/config")" = "lang=ja" ] && grep -q '^description: 自分のコード' "$TMP/skill/SKILL.md"; } && ok "X11 --lang ja に切り替えると config も SKILL も日本語" || ng "X11 install ja"
HIDANE_ROOT="$TMP/root2" sh install.sh --lang xx >/dev/null 2>&1; [ $? = 2 ] && ok "X12 未知の言語は exit 2" || ng "X12"
echo; echo "PASS $pass / FAIL $fail"; [ $fail -eq 0 ]
