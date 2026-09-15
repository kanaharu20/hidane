#!/bin/sh
# hidane tag.sh — 関数に概念タグを付け、functions.md に追記する(まだ問うていない関数が地図に載る入口)。
#
# ここが hidane で唯一 LLM に判断させる場所。Claude がするのは
# 「既存の概念一覧から選ぶか、無ければ新しい名前を付ける」だけ。形式はこのスクリプトが検査し、
# 検査に落ちた行は捨てて stderr に出す。値や状態には一切触れない。
#
# 使い方: tag.sh [--commit REV | --all] [--bg] [--root DIR] [--repo DIR] [--dry-run] [--help]
#   --commit REV  そのコミットが触った関数だけ(既定 HEAD。hook が使う)
#   --all         リポジトリ全体の関数。hook を置いた最初に一度回して、全関数を地図に載せる。既知の場所は飛ばす
#   --root DIR    記録の場所(既定 $HIDANE_ROOT か ~/.claude/hidane)。<root>/<repo名>/functions.md に追記
#   --repo DIR    git リポジトリ(既定: カレント)
#   --dry-run     LLM を呼ばず、渡すはずのプロンプトを stdout に出す
#   --bg          候補の数だけ表示してすぐ戻り、LLM 呼び出しは背景で回して <root>/hook.log に集計を残す(/hidane --tag 用。数分かかっても待たせない)
# 環境変数: HIDANE_CLAUDE(claude コマンドの差し替え。検査用) HIDANE_MODEL
#           HIDANE_MAX_FUNCS(1 回の呼び出しに載せる関数の数。既定 8。候補が尽きるまで繰り返す)
#
# 既に functions.md か log.md にある場所は付け直さない(同じ場所には一度だけ)。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REV=HEAD; ALL=""; REPO=.; DRY=""; BG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --commit) REV="$2"; shift 2 ;;
    --all) ALL=1; shift ;;
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --bg) BG=1; shift ;;
    --help|-h) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "tag.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done
. "$HERE/lang.sh"
CLAUDE="${HIDANE_CLAUDE:-claude}"
MAXF="${HIDANE_MAX_FUNCS:-8}"

cd "$REPO"
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "tag.sh: git リポジトリではない: $REPO" >&2; exit 3; }
cd "$top"; repo=$(basename "$top")
short=$(git rev-parse --short "$REV")
out="$ROOT/$repo"; fn="$out/functions.md"; log="$out/log.md"
mkdir -p "$out"; [ -n "$DRY" ] || printf '%s\n' "$top" > "$out/path"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# 1. 候補(場所<TAB>関数名)。既知の場所は除く
if [ -n "$ALL" ]; then sh "$HERE/scope.sh" --all 2>/dev/null; else sh "$HERE/scope.sh" --commit "$REV" 2>/dev/null; fi \
  | sed 1d | awk '{ print $1 "\t" $2 }' > "$tmp/cands"
{ [ -f "$fn" ] && grep '^| 20' "$fn"; [ -f "$log" ] && grep '^| 20' "$log"; true; } \
  | awk -F'|' '{ p=$3; f=$4; gsub(/^ +| +$/, "", p); gsub(/^ +| +$/, "", f); print p "\t" f }' > "$tmp/known"
grep -vxF -f "$tmp/known" "$tmp/cands" 2>/dev/null > "$tmp/todo" || true
total=$(wc -l < "$tmp/todo" | tr -d ' ')
[ "$total" -gt 0 ] || { echo "tag.sh: $repo@$short: $(L t_none)"; exit 0; }
if [ -n "$BG" ]; then
  batches=$(( (total + MAXF - 1) / MAXF ))
  printf "tag.sh: $(L t_bg)\n" "$total" "$batches" "$ROOT/hook.log"
  if [ -n "$ALL" ]; then mode="--all"; else mode="--commit $REV"; fi
  ( nohup sh "$HERE/tag.sh" $mode --root "$ROOT" --repo "$top" >> "$ROOT/hook.log" 2>&1 & ) >/dev/null 2>&1
  exit 0
fi

# 2. 既存の概念一覧(全 repo)。呼び出しごとに更新する(前の束で新設した名前を次の束が使えるように)
existing() { sh "$HERE/map.sh" --root "$ROOT" --tsv 2>/dev/null | cut -f1 | LC_ALL=C sort -u; }

# 関数のコード。コミット指定ならその版、--all なら HEAD、無ければ作業ツリー
code() { # $1 file $2 a $3 b
  { git show "$REV:$1" 2>/dev/null || cat "$1" 2>/dev/null; } | sed -n "$2,$3p"
}

# 3. 束ごとに: プロンプト → 呼び出し → 検査 → 追記
prompt() { # $1 束のファイル $2 既存一覧のファイル
  if [ "$LANGX" = "ja" ]; then cat <<'P'
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
  else cat <<'P'
For each function below, attach 1-3 concepts a reader must understand to follow it.

A concept is a reusable unit of understanding: a language construct, a pattern, or a skill
(e.g. boundary conditions, rollback on partial failure, condition variable wait/notify, time unit conversion).
Pick names that would apply in any other repository, not names tied to this function or project.
If an "existing concept" means the same thing, reuse that exact name; only invent a new name when none fits.
Names are short English noun phrases (at most 4 words).

Output exactly one line per function, tab-separated:
place<TAB>function<TAB>concept1, concept2
Nothing else: no preamble, no explanation. Copy place and function exactly as written below.

## Existing concepts
P
  fi
  if [ -s "$2" ]; then sed 's/^/- /' "$2"; else echo "(none yet)"; fi
  echo; if [ "$LANGX" = "ja" ]; then echo "## 関数"; else echo "## Functions"; fi
  while IFS="$(printf '\t')" read -r place name; do
    file=${place%%:*}; range=${place##*:}; a=${range%-*}; b=${range#*-}
    echo; echo "### $place	$name"; echo '```'; code "$file" "$a" "$b"; echo '```'
  done < "$1"
}

[ -f "$fn" ] || [ -n "$DRY" ] || printf '# hidane — %s\n\n%s\n|---|---|---|---|---|---|\n' "$(L fn_title)" "$(L fn_header)" > "$fn"
today=$(date +%Y-%m-%d)
good_all=0; bad_all=0; calls=0
split -l "$MAXF" "$tmp/todo" "$tmp/chunk."
for chunk in "$tmp"/chunk.*; do
  existing > "$tmp/existing"
  prompt "$chunk" "$tmp/existing" > "$tmp/prompt"
  if [ -n "$DRY" ]; then cat "$tmp/prompt"; echo; echo "----- (batch)"; continue; fi
  calls=$((calls + 1))
  "$CLAUDE" -p ${HIDANE_MODEL:+--model "$HIDANE_MODEL"} --output-format text < "$tmp/prompt" > "$tmp/answer" 2>"$tmp/answer.err" \
    || { echo "tag.sh: $(L t_fail)($(L t_batch) $calls): $(head -c 300 "$tmp/answer.err")" >&2; exit 4; }
  awk -F'\t' -v today="$today" -v short="$short" -v todo="$chunk" -v existing="$tmp/existing" -v fn="$fn" -v t_drop="$(L t_drop)" -v t_new="$(L t_new)" '
  function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
  BEGIN {
    while ((getline l < todo) > 0) { split(l, t, "\t"); want[t[1]] = t[2] }
    while ((getline l < existing) > 0) if (l != "") known[l] = 1
  }
  {
    line = $0; sub(/\r$/, "", line)
    if (line ~ /^[ \t]*$/) next
    if (NF != 3) { printf("tag.sh: %s(列が 3 でない): %s\n", t_drop, line) > "/dev/stderr"; bad++; next }
    place = trim($1); name = trim($2); cs = trim($3)
    if (!(place in want)) { printf("tag.sh: %s(候補に無い場所): %s\n", t_drop, line) > "/dev/stderr"; bad++; next }
    if (place in done) { printf("tag.sh: %s(同じ場所が 2 回): %s\n", t_drop, line) > "/dev/stderr"; bad++; next }
    if (cs ~ /[|\t]/ || cs == "") { printf("tag.sh: %s(概念が空か | を含む): %s\n", t_drop, line) > "/dev/stderr"; bad++; next }
    n = split(cs, arr, ","); out = ""; note = ""
    for (i = 1; i <= n; i++) {
      c = trim(arr[i]); if (c == "" || length(c) > 40) continue
      out = (out == "" ? c : out ", " c)
      if (!(c in known)) { note = (note == "" ? t_new ": " c : note ", " c); known[c] = 1 }
    }
    if (out == "") { printf("tag.sh: %s(使える概念なし): %s\n", t_drop, line) > "/dev/stderr"; bad++; next }
    done[place] = 1; good++
    printf("| %s | %s | %s | %s | %s | %s |\n", today, place, want[place], out, short, note) >> fn
  }
  END { printf("%d %d\n", good + 0, bad + 0) }
  ' "$tmp/answer" > "$tmp/counts"
  read -r g b < "$tmp/counts"; good_all=$((good_all + g)); bad_all=$((bad_all + b))
done
[ -n "$DRY" ] && exit 0
printf "tag.sh: $(L t_done) → %s\n" "$total" "$calls" "$good_all" "$bad_all" "$fn"

# 4. vault を更新(失敗しても記録は残っているので無視)。数日に一度は概念名の統合も
sh "$HERE/pages.sh" --root "$ROOT" >/dev/null 2>&1 || true
sh "$HERE/lint.sh" --root "$ROOT" --if-due 2>&1 | sed 's/^/tag.sh: /' || true
