#!/bin/sh
# hidane tag.sh — コミットが触った関数に概念タグを付け、functions.md に追記する(霧の入口)。
#
# ここが hidane で唯一 LLM に判断させる場所。Claude がするのは
# 「既存の概念一覧から選ぶか、無ければ新しい名前を付ける」だけ。形式はこのスクリプトが検査し、
# 検査に落ちた行は捨てて stderr に出す。値や状態には一切触れない。
#
# 使い方: tag.sh [--commit REV] [--root DIR] [--repo DIR] [--dry-run] [--help]
#   --commit REV  対象コミット(既定 HEAD)
#   --root DIR    記録の場所(既定 $HIDANE_ROOT か ~/.claude/hidane)。<root>/<repo名>/functions.md に追記
#   --repo DIR    git リポジトリ(既定: カレント)
#   --dry-run     LLM を呼ばず、渡すはずのプロンプトを stdout に出す
# 環境変数: HIDANE_CLAUDE(claude コマンドの差し替え。検査用) HIDANE_MODEL  HIDANE_MAX_FUNCS(1 回に付ける上限。既定 8)
#
# 既に functions.md か log.md にある場所は付け直さない(同じ場所には一度だけ)。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REV=HEAD; REPO=.; DRY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --commit) REV="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --help|-h) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "tag.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done
CLAUDE="${HIDANE_CLAUDE:-claude}"
MAXF="${HIDANE_MAX_FUNCS:-8}"

cd "$REPO"
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "tag.sh: git リポジトリではない: $REPO" >&2; exit 3; }
cd "$top"; repo=$(basename "$top")
short=$(git rev-parse --short "$REV")
out="$ROOT/$repo"; fn="$out/functions.md"; log="$out/log.md"
mkdir -p "$out"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# 1. 候補: このコミットが触った関数(場所<TAB>関数名)。既知の場所は除く
sh "$HERE/scope.sh" --commit "$REV" 2>/dev/null | sed 1d | awk '{ print $1 "\t" $2 }' > "$tmp/cands"
{ [ -f "$fn" ] && grep '^| 20' "$fn"; [ -f "$log" ] && grep '^| 20' "$log"; true; } \
  | awk -F'|' '{ p=$3; f=$4; gsub(/^ +| +$/, "", p); gsub(/^ +| +$/, "", f); print p "\t" f }' > "$tmp/known"
grep -vxF -f "$tmp/known" "$tmp/cands" 2>/dev/null | head -n "$MAXF" > "$tmp/todo" || true
[ -s "$tmp/todo" ] || { echo "tag.sh: $repo@$short: 付ける関数なし"; exit 0; }

# 2. 既存の概念一覧(全 repo)
sh "$HERE/map.sh" --root "$ROOT" --tsv 2>/dev/null | cut -f1 | LC_ALL=C sort -u > "$tmp/existing" || true

# 3. プロンプト。完成形はスクリプトが作り、Claude は穴(概念名)だけ埋める
{
  cat <<'P'
次の関数それぞれに、その関数を理解するために必要な概念を 1〜3 個付けてください。

概念とは、言語構成・パターン・技能のいずれかで、別のコードでも再利用できる理解の単位です
(例: 境界条件、部分失敗の巻き戻し、条件変数の待機と通知、時刻の単位換算)。
関数の名前や repo 固有の事情ではなく、他の repo でも同じ名前で呼べるものを選んでください。
「既存の概念」に同じ意味のものがあれば必ずその名前をそのまま使い、無いときだけ新しい名前を付けてください。
名前は日本語の短い名詞句(20 字以内)。

出力は関数ごとに 1 行、タブ区切りで
場所<TAB>関数名<TAB>概念1, 概念2
だけを書き、前置きや説明は一切書かないでください。場所と関数名は下に書いてある通りに写してください。

## 既存の概念
P
  if [ -s "$tmp/existing" ]; then sed 's/^/- /' "$tmp/existing"; else echo "(まだ無い)"; fi
  echo; echo "## 関数"
  while IFS="$(printf '\t')" read -r place name; do
    file=${place%%:*}; range=${place##*:}; a=${range%-*}; b=${range#*-}
    echo; echo "### $place	$name"; echo '```'
    git show "$REV:$file" 2>/dev/null | sed -n "${a},${b}p"
    echo '```'
  done < "$tmp/todo"
} > "$tmp/prompt"

if [ -n "$DRY" ]; then cat "$tmp/prompt"; exit 0; fi

# 4. LLM 呼び出し(標準入力でプロンプトを渡す)
"$CLAUDE" -p ${HIDANE_MODEL:+--model "$HIDANE_MODEL"} --output-format text < "$tmp/prompt" > "$tmp/answer" 2>"$tmp/answer.err" \
  || { echo "tag.sh: claude が失敗: $(head -c 300 "$tmp/answer.err")" >&2; exit 4; }

# 5. 検査して functions.md に追記。落ちた行は stderr
today=$(date +%Y-%m-%d)
[ -f "$fn" ] || printf '# hidane — commit 時に付けた概念(未出題の関数。霧の入口)\n\n| 日付 | 場所 | 関数 | 概念 | commit | 備考 |\n|---|---|---|---|---|---|\n' > "$fn"
awk -F'\t' -v today="$today" -v short="$short" -v todo="$tmp/todo" -v existing="$tmp/existing" -v fn="$fn" '
function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
BEGIN {
  while ((getline l < todo) > 0) { split(l, t, "\t"); want[t[1]] = t[2] }
  while ((getline l < existing) > 0) if (l != "") known[l] = 1
}
{
  line = $0; sub(/\r$/, "", line)
  if (line ~ /^[ \t]*$/) next
  if (NF != 3) { printf("tag.sh: 捨てた(列が 3 でない): %s\n", line) > "/dev/stderr"; bad++; next }
  place = trim($1); name = trim($2); cs = trim($3)
  if (!(place in want)) { printf("tag.sh: 捨てた(候補に無い場所): %s\n", line) > "/dev/stderr"; bad++; next }
  if (place in done) { printf("tag.sh: 捨てた(同じ場所が 2 回): %s\n", line) > "/dev/stderr"; bad++; next }
  if (cs ~ /[|\t]/ || cs == "") { printf("tag.sh: 捨てた(概念が空か | を含む): %s\n", line) > "/dev/stderr"; bad++; next }
  n = split(cs, arr, ","); out = ""; note = ""
  for (i = 1; i <= n; i++) {
    c = trim(arr[i]); if (c == "" || length(c) > 40) continue
    out = (out == "" ? c : out ", " c)
    if (!(c in known)) { note = (note == "" ? "新: " c : note ", " c); known[c] = 1 }
  }
  if (out == "") { printf("tag.sh: 捨てた(使える概念なし): %s\n", line) > "/dev/stderr"; bad++; next }
  done[place] = 1; good++
  printf("| %s | %s | %s | %s | %s | %s |\n", today, place, want[place], out, short, note) >> fn
}
END { printf("tag.sh: 追記 %d 行、捨てた %d 行 → %s\n", good + 0, bad + 0, fn) }
' "$tmp/answer"

# 6. vault を更新(失敗しても記録は残っているので無視)
sh "$HERE/pages.sh" --root "$ROOT" >/dev/null 2>&1 || true
