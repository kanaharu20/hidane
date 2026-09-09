#!/bin/sh
# hidane lint.sh — 似た概念名を統合する(数日に一度)。log.md は書き換えず、aliases.md に「旧名 → 新名」を足す。
#
# 使い方: lint.sh [--root DIR] [--if-due] [--dry-run]
#   --if-due   前回から HIDANE_LINT_DAYS 日(既定 3)経っていないなら何もしない(hook 経由で使う)
#   --dry-run  LLM を呼ばず、プロンプトを出す
# 環境変数: HIDANE_CLAUDE HIDANE_MODEL HIDANE_LINT_DAYS
#
# Claude がするのは「同じ意味の概念の組を挙げる」だけ。新名は既存の概念名でなければならず、
# 旧名 = 新名、存在しない名前、循環はスクリプトが捨てる。統合後は値が合流する(行の合計)。
# 取り消すときは aliases.md の該当行を消すだけ。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; IFDUE=""; DRY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --if-due) IFDUE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --help|-h) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "lint.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done
. "$HERE/lang.sh"
CLAUDE="${HIDANE_CLAUDE:-claude}"; DAYS="${HIDANE_LINT_DAYS:-3}"
A="$ROOT/aliases.md"; STAMP="$ROOT/.lint-stamp"
today=$(date +%Y-%m-%d)
if [ -n "$IFDUE" ] && [ -f "$STAMP" ]; then
  last=$(cat "$STAMP")
  jd() { awk -v d="$1" 'BEGIN{y=substr(d,1,4)+0;m=substr(d,6,2)+0;dd=substr(d,9,2)+0;a=int((14-m)/12);yy=y+4800-a;mm=m+12*a-3;print dd+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045}'; }
  [ $(( $(jd "$today") - $(jd "$last") )) -ge "$DAYS" ] || exit 0
fi

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
sh "$HERE/map.sh" --root "$ROOT" --tsv > "$tmp/map" 2>/dev/null || true
n=$(wc -l < "$tmp/map" | tr -d ' ')
[ "$n" -ge 2 ] || { [ -n "$IFDUE" ] || printf "lint.sh: $(L l_few)\n" "$n"; exit 0; }

# 概念ごとに: 状態、値、repo、付いている関数名(最大 6)
for d in "$ROOT"/*/; do
  repo=$(basename "$d")
  for f in log.md functions.md; do [ -f "$d/$f" ] && grep '^| 20' "$d/$f" | sed "s/^/$repo	/"; done; true
done | sh "$HERE/resolve.sh" --root "$ROOT" | awk -F'\t' -v map="$tmp/map" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
BEGIN { while ((getline l < map) > 0) { split(l, t, "\t"); order[++nc] = t[1]; info[t[1]] = t[5] " 値 " t[2] " 証拠 " t[3] " repo " t[6] } }
{ split($2, col, "|"); fn = trim(col[4]); k = split(trim(col[5]), cs, ","); for (i = 1; i <= k; i++) { c = trim(cs[i]); if (c != "" && cnt[c] < 6 && !((c SUBSEP fn) in seen)) { seen[c SUBSEP fn] = 1; cnt[c]++; fns[c] = fns[c] (fns[c] == "" ? "" : ", ") fn } } }
END { for (i = 1; i <= nc; i++) { c = order[i]; printf("- %s(%s)関数: %s\n", c, info[c], fns[c]) } }
' > "$tmp/list"

{
  if [ "$LANGX" = "ja" ]; then cat <<'P'
以下は、ある開発者のコードに付いた「概念」の一覧です(概念名、状態、付いている関数名)。
同じ意味、または一方が他方の言い換えにすぎない組があれば、統合してください。

規則:
- 統合先(新名)は一覧にある名前から選ぶ。新しい名前は作らない
- 統合先は、より一般的で、他のコードにも使える方の名前にする。証拠の多い方を優先
- 粒度が本当に違うもの(「境界条件」と「オーバーフロー検出」など、片方が他方の一部)は統合しない
- 迷うものは統合しない。統合は取り消せるが、しない方が安全

出力は 1 組につき 1 行、タブ区切りで
旧名<TAB>新名<TAB>理由(20 字以内)
だけ。統合すべき組が無ければ「なし」と 1 行だけ書く。前置きや説明は書かない。

## 概念
P
  else cat <<'P'
Below is the list of "concepts" attached to one developer's code (name, state, functions it is attached to).
If two names mean the same thing, or one is merely a paraphrase of the other, merge them.

Rules:
- The target (new name) must be a name from the list. Never invent a new name.
- Prefer the more general name that applies to other code; prefer the one with more evidence.
- Do not merge names of genuinely different granularity (e.g. "boundary conditions" vs "overflow detection", where one is part of the other).
- When in doubt, do not merge. Merges can be undone, but not merging is safer.

Output exactly one line per pair, tab-separated:
old<TAB>new<TAB>reason (under 10 words)
Nothing else. If nothing should be merged, write a single line: none

## Concepts
P
  fi
  cat "$tmp/list"
} > "$tmp/prompt"
if [ -n "$DRY" ]; then cat "$tmp/prompt"; exit 0; fi

"$CLAUDE" -p ${HIDANE_MODEL:+--model "$HIDANE_MODEL"} --output-format text < "$tmp/prompt" > "$tmp/answer" 2>"$tmp/err" \
  || { echo "lint.sh: $(L t_fail): $(head -c 300 "$tmp/err")" >&2; exit 4; }

[ -f "$A" ] || printf '# hidane — %s\n\n%s\n|---|---|---|---|\n' "$(L al_title)" "$(L al_header)" > "$A"
cut -f1 "$tmp/map" > "$tmp/names"
awk -F'\t' -v today="$today" -v names="$tmp/names" -v aliases="$A" -v t_drop="$(L t_drop)" -v l_done="$(L l_done)" '
function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
BEGIN {
  while ((getline l < names) > 0) exist[l] = 1
  while ((getline l < aliases) > 0) if (l ~ /^\| 20/) { split(l, a, "|"); to[trim(a[3])] = trim(a[4]) }
}
function root(c, i) { for (i = 0; i < 10 && (c in to); i++) c = to[c]; return c }
{
  line = $0; sub(/\r$/, "", line); if (line ~ /^[ \t]*$/ || trim(line) == "なし" || tolower(trim(line)) == "none") next
  if (NF < 2) { printf("lint.sh: %s(列が足りない): %s\n", t_drop, line) > "/dev/stderr"; bad++; next }
  o = trim($1); n = trim($2); r = trim($3); gsub(/\|/, "｜", r)
  if (o == n) { printf("lint.sh: %s(同名): %s\n", t_drop, line) > "/dev/stderr"; bad++; next }
  if (!(o in exist)) { printf("lint.sh: %s(旧名が無い): %s\n", t_drop, line) > "/dev/stderr"; bad++; next }
  if (!(n in exist)) { printf("lint.sh: %s(新名が一覧に無い): %s\n", t_drop, line) > "/dev/stderr"; bad++; next }
  if (o in to) { printf("lint.sh: %s(旧名はすでに別名): %s\n", t_drop, line) > "/dev/stderr"; bad++; next }
  if (root(n) == o) { printf("lint.sh: %s(循環): %s\n", t_drop, line) > "/dev/stderr"; bad++; next }
  to[o] = n; good++
  printf("| %s | %s | %s | %s |\n", today, o, n, r) >> aliases
}
END { printf("lint.sh: " l_done " → %s\n", good + 0, bad + 0, aliases) }
' "$tmp/answer"
echo "$today" > "$STAMP"
sh "$HERE/pages.sh" --root "$ROOT" >/dev/null 2>&1 || true
