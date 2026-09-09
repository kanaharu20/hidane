#!/bin/sh
# hidane map.sh — log.md から概念ごとの「値」「鮮度」「状態」を計算して表にする。
# 状態は保存しない。毎回 log.md から計算する。LLM は使わない。
#
# 使い方: map.sh [--root DIR] [--today YYYY-MM-DD] [--tsv] [--help]
#   --root DIR    <DIR>/<repo>/log.md(答えの記録)と <DIR>/<repo>/functions.md(commit 時のタグ)を全部読む
#                 既定: $HIDANE_ROOT か ~/.claude/hidane
#   --today DATE  鮮度の基準日(既定: 今日)。テスト用
#   --tsv         見出し・脚注なしのタブ区切り(概念 値 証拠 最終 状態 repo)。pages.sh 用
#
# 規則(定数は環境変数で上書きできる。全部仮置き):
#   値   = Σ(型の重み × 符号)。追う 1 / 追う(境界・変異) 2 / 要約 3
#          当たり・一致 +1、ズレ・外れ・分からない -1、未回答 0(証拠にしない)
#          1 行ごとに足し、±CAP で止める(歩きながら止める)
#   鮮度 = 最後に証拠のあった日から FRESH_DAYS 日以内
#   状態 = 証拠なし(functions.md にだけある、または未回答だけ)→ 未出題
#          値 >= +THRESHOLD かつ新鮮 → 理解
#          値 <= -THRESHOLD かつ新鮮 → 非理解
#          それ以外 → 曖昧
# 出力は値の昇順(=出題の優先順)。末尾に「読んだ行数 / 使えた行数」を出す。
set -eu

ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"
TODAY=""
TSV=""
W_TRACE="${HIDANE_W_TRACE:-1}"
W_EDGE="${HIDANE_W_EDGE:-2}"
W_SUMMARY="${HIDANE_W_SUMMARY:-3}"
THRESHOLD="${HIDANE_THRESHOLD:-4}"
CAP="${HIDANE_CAP:-6}"
FRESH_DAYS="${HIDANE_FRESH_DAYS:-30}"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --today) TODAY="$2"; shift 2 ;;
    --tsv) TSV=1; shift ;;
    --help|-h) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "map.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$TODAY" ] || TODAY=$(date +%Y-%m-%d)

found=0
for d in "$ROOT"/*/; do
  [ -f "$d/log.md" ] || [ -f "$d/functions.md" ] || continue
  found=1; break
done
[ "$found" = 1 ] || { echo "map.sh: $ROOT に */log.md も */functions.md も無い" >&2; exit 1; }
for d in "$ROOT"/*/; do
  repo=$(basename "$d")
  # 行頭が "| 20" の行だけがデータ。repo 名と種別(log / fn)を先頭に付けて流す
  [ -f "$d/log.md" ] && grep '^| 20' "$d/log.md" | sed "s/^/$repo	log	/"
  [ -f "$d/functions.md" ] && grep '^| 20' "$d/functions.md" | sed "s/^/$repo	fn	/"
  true
done | sh "$(dirname "$0")/resolve.sh" --root "$ROOT" | awk -F'\t' -v tsv="$TSV" \
  -v today="$TODAY" -v wt="$W_TRACE" -v we="$W_EDGE" -v ws="$W_SUMMARY" \
  -v th="$THRESHOLD" -v cap="$CAP" -v fresh="$FRESH_DAYS" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function jdn(d,   y, m, dd, a, yy, mm) {   # YYYY-MM-DD → ユリウス日
  y = substr(d,1,4)+0; m = substr(d,6,2)+0; dd = substr(d,9,2)+0
  a = int((14-m)/12); yy = y+4800-a; mm = m+12*a-3
  return dd + int((153*mm+2)/5) + 365*yy + int(yy/4) - int(yy/100) + int(yy/400) - 32045
}
function weight(t) {
  if (t == "追う") return wt
  if (t == "追う(境界・変異)" || t == "追う(境界)" || t == "追う(変異)") return we
  if (t == "要約") return ws
  return -1
}
function sign(r) {
  if (r == "当たり" || r == "一致") return 1
  if (r == "ズレ" || r == "外れ" || r == "分からない") return -1
  if (r == "未回答") return 0
  return -99
}
$2 == "fn" {
  # functions.md: | 日付 | 場所 | 関数 | 概念 | commit | 備考 |  → 概念を「見た」だけ。証拠にはならない
  repo = $1; line = $3
  split(line, col, "|")
  k = split(trim(col[5]), cs, ",")
  for (i = 1; i <= k; i++) {
    c = trim(cs[i]); if (c == "") continue
    seen[c] = 1
    if (!(c SUBSEP repo in rep)) { rep[c SUBSEP repo] = 1; repos[c] = (repos[c] == "" ? repo : repos[c] "," repo) }
  }
  next
}
{
  read++
  repo = $1; line = $3
  n = split(line, col, "|")
  # col[1] は空、col[2] 日時 ... col[10] 備考
  date = substr(trim(col[2]), 1, 10)
  concepts = trim(col[5]); type = trim(col[6]); result = trim(col[8])
  w = weight(type); s = sign(result)
  if (w < 0 || s == -99 || date !~ /^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) {
    printf("map.sh: 読めない行 (%s): %s\n", repo, line) > "/dev/stderr"; next
  }
  used++
  k = split(concepts, cs, ",")
  for (i = 1; i <= k; i++) {
    c = trim(cs[i]); if (c == "") continue
    seen[c] = 1
    if (!(c SUBSEP repo in rep)) { rep[c SUBSEP repo] = 1; repos[c] = (repos[c] == "" ? repo : repos[c] "," repo) }
    if (s == 0) continue                       # 未回答は証拠にしない
    v = val[c] + w * s
    if (v > cap) v = cap; if (v < -cap) v = -cap
    val[c] = v; cnt[c]++
    if (date > last[c]) last[c] = date
  }
}
END {
  if (!tsv) printf("!\t1\t| 概念 | 値 | 証拠 | 最終 | 状態 | repo |\n!\t2\t|---|---|---|---|---|---|\n")
  for (c in seen) {
    v = val[c] + 0; n = cnt[c] + 0
    if (n == 0) { st = "未出題"; lastd = "-" }
    else {
      lastd = last[c]
      isfresh = (jdn(today) - jdn(lastd) <= fresh)
      if (v >= th && isfresh) st = "理解"
      else if (v <= -th && isfresh) st = "非理解"
      else st = "曖昧"
    }
    # 並べ替え用: 値の昇順、同値は名前順
    if (tsv) printf("%+04d\t%s\t%s\t%d\t%d\t%s\t%s\t%s\n", v + 100, c, c, v, n, lastd, st, repos[c])
    else     printf("%+04d\t%s\t| %s | %+d | %d | %s | %s | %s |\n", v + 100, c, c, v, n, lastd, st, repos[c])
  }
  if (!tsv) printf("ZZZ\t\t\n~\t\t読んだ行 %d / 使えた行 %d(基準日 %s、閾値 ±%d、上限 ±%d、鮮度 %d 日)\n", read, used, today, th, cap, fresh)
}' | LC_ALL=C sort -t'	' -k1,1 -k2,2 | cut -f3- | sed '/^$/d' 
