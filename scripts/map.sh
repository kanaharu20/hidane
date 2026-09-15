#!/bin/sh
# hidane map.sh — log.md から概念ごとの「値」「鮮度」「状態」を計算して表にする。
# 状態は保存しない。毎回 log.md から計算する。LLM は使わない。
#
# 使い方: map.sh [--root DIR] [--today YYYY-MM-DD] [--tsv] [--help]
#   --root DIR    <DIR>/<repo>/log.md(答えの記録)と <DIR>/<repo>/functions.md(commit 時のタグ)を全部読む
#                 既定: $HIDANE_ROOT か ~/.claude/hidane
#   --today DATE  鮮度の基準日(既定: 今日)。テスト用
#   --tsv         見出し・脚注なしのタブ区切り(概念 値 証拠 最終 状態 repo)。状態は記号。pages.sh 用
#
# 記録の中の語彙は言語に依らない記号(lang.sh 参照):
#   型   trace 1 / edge 2(summary は旧記録だけ。重み 3 のまま読む)   結果  hit +1 / partial 0(証拠にはなる) / miss -1 / dunno -1 / skip 0(証拠にしない)
#   代表 概念列で先頭に * が付いた概念(next.sh が狙った概念)は満額、同じ行の他の概念は半分(切り捨て)。* が無い旧行は全部満額
#   状態 known / fuzzy / unknown / unasked  表示だけ言語表を通す
# 規則(定数は環境変数で上書きできる。全部仮置き):
#   値   = Σ(型の重み × 符号)。1 行ごとに足し、±CAP で止める(歩きながら止める)
#   鮮度 = known は最後の当たりの日、unknown は最後のズレ(miss / dunno)の日から FRESH_DAYS 日以内(ズレでは理解に戻らず、当たりでは非理解に戻らない)
#   状態 = 証拠なし → unasked / 値 >= +THRESHOLD かつ当たりが新鮮 → known / 値 <= -THRESHOLD かつズレが新鮮 → unknown / それ以外 → fuzzy
# 出力は値の昇順(=出題の優先順)。末尾に「読んだ行数 / 使えた行数」を出す。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"
TODAY=""; TSV=""
W_TRACE="${HIDANE_W_TRACE:-1}"; W_EDGE="${HIDANE_W_EDGE:-2}"; W_SUMMARY=3   # summary は 0.5.1 で廃止。旧行を読むためだけに残す
THRESHOLD="${HIDANE_THRESHOLD:-4}"; CAP="${HIDANE_CAP:-6}"; FRESH_DAYS="${HIDANE_FRESH_DAYS:-30}"
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --today) TODAY="$2"; shift 2 ;;
    --tsv) TSV=1; shift ;;
    --help|-h) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "map.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done
. "$HERE/lang.sh"
[ -n "$TODAY" ] || TODAY=$(date +%Y-%m-%d)

found=0
for d in "$ROOT"/*/; do
  [ -f "$d/log.md" ] || [ -f "$d/functions.md" ] || continue
  found=1; break
done
[ "$found" = 1 ] || { echo "map.sh: $ROOT: no */log.md or */functions.md" >&2; exit 1; }
for d in "$ROOT"/*/; do
  repo=$(basename "$d")
  [ -f "$d/log.md" ] && grep '^| 20' "$d/log.md" | sed "s/^/$repo	log	/"
  [ -f "$d/functions.md" ] && grep '^| 20' "$d/functions.md" | sed "s/^/$repo	fn	/"
  true
done | sh "$HERE/resolve.sh" --root "$ROOT" | awk -F'\t' -v tsv="$TSV" \
  -v today="$TODAY" -v wt="$W_TRACE" -v we="$W_EDGE" -v ws="$W_SUMMARY" \
  -v th="$THRESHOLD" -v cap="$CAP" -v fresh="$FRESH_DAYS" \
  -v l_known="$(L st_known)" -v l_fuzzy="$(L st_fuzzy)" -v l_unknown="$(L st_unknown)" -v l_unasked="$(L st_unasked)" \
  -v h_concept="$(L h_concept)" -v h_value="$(L h_value)" -v h_evidence="$(L h_evidence)" -v h_last="$(L h_last)" -v h_state="$(L h_state)" -v h_repo="$(L h_repo)" \
  -v m_footer="$(L m_footer)" -v m_bad="$(L m_bad)" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function jdn(d,   y, m, dd, a, yy, mm) {
  y = substr(d,1,4)+0; m = substr(d,6,2)+0; dd = substr(d,9,2)+0
  a = int((14-m)/12); yy = y+4800-a; mm = m+12*a-3
  return dd + int((153*mm+2)/5) + 365*yy + int(yy/4) - int(yy/100) + int(yy/400) - 32045
}
function weight(t) { if (t == "trace") return wt; if (t == "edge") return we; if (t == "summary") return ws; return -1 }
function sign(r) { if (r == "hit") return 1; if (r == "miss" || r == "dunno") return -1; if (r == "partial" || r == "skip") return 0; return -99 }
function label(st) { return (st == "known" ? l_known : st == "fuzzy" ? l_fuzzy : st == "unknown" ? l_unknown : l_unasked) }
$2 == "fn" {
  repo = $1; line = $3; split(line, col, "|")
  k = split(trim(col[5]), cs, ",")
  for (i = 1; i <= k; i++) { c = trim(cs[i]); if (c == "") continue; seen[c] = 1
    if (!(c SUBSEP repo in rep)) { rep[c SUBSEP repo] = 1; repos[c] = (repos[c] == "" ? repo : repos[c] "," repo) } }
  next
}
{
  read++
  repo = $1; line = $3; split(line, col, "|")
  date = substr(trim(col[2]), 1, 10); concepts = trim(col[5]); type = trim(col[6]); result = trim(col[8])
  w = weight(type); s = sign(result)
  if (w < 0 || s == -99 || date !~ /^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) { printf("map.sh: %s (%s): %s\n", m_bad, repo, line) > "/dev/stderr"; next }
  used++
  k = split(concepts, cs, ","); haslead = 0
  for (i = 1; i <= k; i++) if (trim(cs[i]) ~ /^\*/) haslead = 1
  for (i = 1; i <= k; i++) {
    c = trim(cs[i]); if (c == "") continue
    islead = (c ~ /^\*/); sub(/^\*/, "", c); seen[c] = 1
    if (!(c SUBSEP repo in rep)) { rep[c SUBSEP repo] = 1; repos[c] = (repos[c] == "" ? repo : repos[c] "," repo) }
    if (result == "skip") continue
    ww = (haslead && !islead) ? int(w / 2) : w
    v = val[c] + ww * s; if (v > cap) v = cap; if (v < -cap) v = -cap
    val[c] = v; cnt[c]++; if (date > last[c]) last[c] = date
    if (s > 0 && date > lasthit[c]) lasthit[c] = date
    if (s < 0 && date > lastmiss[c]) lastmiss[c] = date
  }
}
END {
  if (!tsv) printf("!\t1\t| %s | %s | %s | %s | %s | %s |\n!\t2\t|---|---|---|---|---|---|\n", h_concept, h_value, h_evidence, h_last, h_state, h_repo)
  for (c in seen) {
    v = val[c] + 0; n = cnt[c] + 0
    if (n == 0) { st = "unasked"; lastd = "-" }
    else { lastd = last[c]
      hitfresh = (lasthit[c] != "" && jdn(today) - jdn(lasthit[c]) <= fresh)
      missfresh = (lastmiss[c] != "" && jdn(today) - jdn(lastmiss[c]) <= fresh)
      if (v >= th && hitfresh) st = "known"; else if (v <= -th && missfresh) st = "unknown"; else st = "fuzzy" }
    if (tsv) printf("%+04d\t%s\t%s\t%d\t%d\t%s\t%s\t%s\n", v + 100, c, c, v, n, lastd, st, repos[c])
    else     printf("%+04d\t%s\t| %s | %+d | %d | %s | %s | %s |\n", v + 100, c, c, v, n, lastd, label(st), repos[c])
  }
  if (!tsv) { printf("ZZZ\t\t\n~\t\t"); printf(m_footer, read, used, today, th, cap, fresh); printf("\n") }
}' | LC_ALL=C sort -t'	' -k1,1 -k2,2 | cut -f3- | sed '/^$/d'
