#!/bin/sh
# hidane pages.sh — map.sh の結果を Obsidian の vault(Markdown の束)に書き出す。
#
# 使い方: pages.sh [--root DIR] [--vault DIR] [--today YYYY-MM-DD] [--help]
#   --root DIR    map.sh と同じ(既定: $HIDANE_ROOT か ~/.claude/hidane)
#   --vault DIR   書き出し先(既定: $HIDANE_VAULT か ~/Documents/hidane。Obsidian から開きやすい見える場所)
#   --today DATE  鮮度の基準日。テスト用
#
# vault の中身は全部この script が書く。人は書かない。消しても再生成で戻る。
#   concepts/<概念>.md   frontmatter(state, value, evidence, last, repos)+ 関連・典型的なズレ・記録・未出題
#   repos/<repo>.md      その repo に出た概念と状態
#   index.md             map.sh の表そのまま
#   .obsidian/graph.json Graph view の色(理解 黄緑 / 曖昧 黄 / 非理解 赤 / 未出題 灰)。無いときだけ書く
# 前回あって今回無い概念ページは消す(概念の統合で名前が消えたとき)。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; VAULT="${HIDANE_VAULT:-}"; TODAY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --vault) VAULT="$2"; shift 2 ;;
    --today) TODAY="$2"; shift 2 ;;
    --help|-h) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "pages.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done
. "$HERE/lang.sh"
[ -n "$VAULT" ] || VAULT="$HOME/Documents/hidane"
[ -n "$TODAY" ] || TODAY=$(date +%Y-%m-%d)
mkdir -p "$VAULT/concepts" "$VAULT/repos" "$VAULT/.obsidian"

tsv=$(mktemp); trap 'rm -f "$tsv"' EXIT
sh "$HERE/map.sh" --root "$ROOT" --today "$TODAY" --tsv > "$tsv"
sh "$HERE/map.sh" --root "$ROOT" --today "$TODAY" > "$VAULT/index.md"

# 行を集めて awk に渡す(map.sh と同じ流し方)
for d in "$ROOT"/*/; do
  repo=$(basename "$d")
  [ -f "$d/log.md" ] && grep '^| 20' "$d/log.md" | sed "s/^/$repo	log	/"
  [ -f "$d/functions.md" ] && grep '^| 20' "$d/functions.md" | sed "s/^/$repo	fn	/"
  true
done | sh "$HERE/resolve.sh" --root "$ROOT" | LC_ALL=C sort -t'	' -k3,3 | awk -F'\t' -v tsv="$tsv" -v vault="$VAULT" -v today="$TODAY" -v aliases="$ROOT/aliases.md" \
  -v l_known="$(L st_known)" -v l_fuzzy="$(L st_fuzzy)" -v l_unknown="$(L st_unknown)" -v l_unasked="$(L st_unasked)" \
  -v ty_trace="$(L ty_trace)" -v ty_edge="$(L ty_edge)" -v ty_summary="$(L ty_summary)" \
  -v rs_hit="$(L rs_hit)" -v rs_miss="$(L rs_miss)" -v rs_dunno="$(L rs_dunno)" -v rs_skip="$(L rs_skip)" \
  -v p_state="$(L p_state)" -v p_related="$(L p_related)" -v p_zure="$(L p_zure)" -v p_records="$(L p_records)" -v p_unasked="$(L p_unasked)" \
  -v h_concept="$(L h_concept)" -v h_state="$(L h_state)" -v h_value="$(L h_value)" -v h_evidence="$(L h_evidence)" -v h_last="$(L h_last)" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function fname(c) { gsub("/", "／", c); return c }
function label(st) { return (st == "known" ? l_known : st == "fuzzy" ? l_fuzzy : st == "unknown" ? l_unknown : l_unasked) }
function tlabel(t) { return (t == "trace" ? ty_trace : t == "edge" ? ty_edge : t == "summary" ? ty_summary : t) }
function rlabel(r) { return (r == "hit" ? rs_hit : r == "miss" ? rs_miss : r == "dunno" ? rs_dunno : r == "skip" ? rs_skip : r) }
function link(a, b) { if (a == b) return; if (!((a SUBSEP b) in rel)) { rel[a SUBSEP b] = 1; related[a] = related[a] "- [[" fname(b) "]]\n" } }
BEGIN {
  while ((getline l < aliases) > 0) { if (l ~ /^\| 20/) { split(l, a, "|"); o = trim(a[3]); nn = trim(a[4]); if (o != "" && nn != "" && o != nn) { to[o] = nn; olds[++no] = o } } }
  close(aliases)
  for (i = 1; i <= no; i++) { o = olds[i]; c = to[o]; for (j = 0; j < 10 && (c in to); j++) c = to[c]; al[c] = al[c] (al[c] == "" ? "" : ", ") o }
  while ((getline l < tsv) > 0) {
    split(l, t, "\t"); c = t[1]; value[c] = t[2]; evid[c] = t[3]; last[c] = t[4]; state[c] = t[5]; repos[c] = t[6]
    order[++nc] = c
  }
  close(tsv)
}
{
  repo = $1; kind = $2; split($3, col, "|")
  date = substr(trim(col[2]), 1, 10); place = trim(col[3]); fnm = trim(col[4])
  k = split(trim(col[5]), cs, ",")
  for (i = 1; i <= k; i++) { cl[i] = trim(cs[i]) }
  for (i = 1; i <= k; i++) for (j = 1; j <= k; j++) if (cl[i] != "" && cl[j] != "") link(cl[i], cl[j])
  for (i = 1; i <= k; i++) {
    c = cl[i]; if (c == "") continue
    if (kind == "log") {
      type = trim(col[6]); q = trim(col[7]); res = trim(col[8]); zure = trim(col[9])
      rec[c] = rec[c] sprintf("- %s [[%s]] `%s` %s — %s — %s%s\n", date, repo, place, fnm, tlabel(type), rlabel(res), (q != "" ? "(" q ")" : ""))
      if (zure != "") zl[c] = zl[c] sprintf("- %s(%s, %s)\n", zure, repo, date)
      rc[repo] = rc[repo] c "\n"
    } else {
      fog[c] = fog[c] sprintf("- %s [[%s]] `%s` %s\n", date, repo, place, fnm)
      rc[repo] = rc[repo] c "\n"
    }
  }
}
END {
  # 概念ページ
  for (i = 1; i <= nc; i++) {
    c = order[i]; f = vault "/concepts/" fname(c) ".md"
    r = repos[c]; gsub(",", ", ", r)
    printf("---\nstate: %s\nvalue: %s\nevidence: %s\nlast: %s\nrepos: [%s]\n", state[c], value[c], evid[c], last[c], r) > f
    if (al[c] != "") printf("aliases: [%s]\n", al[c]) > f
    printf("updated: %s\n---\n# %s\n\n", today, c) > f
    printf("%s **%s**(%s %s, %s %s, %s %s)\n\n", p_state, label(state[c]), h_value, value[c], h_evidence, evid[c], h_last, last[c]) > f
    if (related[c] != "") printf("## %s\n%s\n", p_related, related[c]) > f
    if (zl[c] != "")      printf("## %s\n%s\n", p_zure, zl[c]) > f
    if (rec[c] != "")     printf("## %s\n%s\n", p_records, rec[c]) > f
    if (fog[c] != "")     printf("## %s\n%s\n", p_unasked, fog[c]) > f
    close(f)
    keep[fname(c) ".md"] = 1
  }
  # repo ページ(概念を状態ごとに、重複なし)
  for (repo in rc) {
    f = vault "/repos/" repo ".md"
    printf("---\nkind: repo\nupdated: %s\n---\n# %s\n\n| %s | %s | %s |\n|---|---|---|\n", today, repo, h_concept, h_state, h_value) > f
    n = split(rc[repo], cs, "\n"); delete done
    for (i = 1; i <= n; i++) { c = cs[i]; if (c == "" || (c in done)) continue; done[c] = 1
      printf("| [[%s]] | %s | %s |\n", fname(c), label(state[c]), value[c]) > f }
    close(f)
    keepr[repo ".md"] = 1
  }
  # 消す対象(前回あって今回無いページ)を stdout に出す。sh 側で rm する
  for (k in keep)  printf("keep\tconcepts/%s\n", k)
  for (k in keepr) printf("keep\trepos/%s\n", k)
}' > "$tsv.keep"

# 掃除: keep に無い .md を消す
for d in concepts repos; do
  for f in "$VAULT/$d"/*.md; do
    [ -f "$f" ] || continue
    grep -qxF "keep	$d/$(basename "$f")" "$tsv.keep" || rm -f "$f"
  done
done
rm -f "$tsv.keep"

# Graph view の色。無いときだけ書く(利用者が Obsidian 側で変えた設定を上書きしない)
g="$VAULT/.obsidian/graph.json"
# 旧名「霧」や旧配色で作った色設定が残っていれば新しくする(利用者が自分で変えた色は触らない)。
# Obsidian が整形し直した JSON(数字の後が改行)にも効くよう、行末と非数字の両方を見る
if [ -f "$g" ]; then
  sed -i '' 's/\[state:霧\]/[state:unasked]/; s/\[state:未出題\]/[state:unasked]/; s/\[state:理解\]/[state:known]/; s/\[state:曖昧\]/[state:fuzzy]/; s/\[state:非理解\]/[state:unknown]/' "$g" 2>/dev/null || true
  for pair in 9159498:1566369 16771899:16765503 16007990:16729943 10395294:7041144 6323595:13620186; do
    o=${pair%%:*}; n=${pair##*:}
    sed -i '' "s/\(\"rgb\": *\)$o\([^0-9]\)/\1$n\2/; s/\(\"rgb\": *\)$o\$/\1$n/" "$g" 2>/dev/null || true
  done
fi
[ -f "$g" ] || cat > "$g" <<'JSON'
{
  "collapse-color-groups": false,
  "colorGroups": [
    { "query": "[state:known]",   "color": { "a": 1, "rgb": 1566369 } },
    { "query": "[state:fuzzy]",   "color": { "a": 1, "rgb": 16765503 } },
    { "query": "[state:unknown]", "color": { "a": 1, "rgb": 16729943 } },
    { "query": "[state:unasked]", "color": { "a": 1, "rgb": 7041144 } },
    { "query": "path:repos",     "color": { "a": 1, "rgb": 13620186 } }
  ],
  "showTags": false, "showAttachments": false, "hideUnresolved": true, "showOrphans": true,
  "textFadeMultiplier": 0, "nodeSizeMultiplier": 1.2, "lineSizeMultiplier": 1
}
JSON

nconc=$(ls "$VAULT/concepts" | wc -l | tr -d ' '); nrepo=$(ls "$VAULT/repos" | wc -l | tr -d ' ')
printf 'pages.sh: %s: ' "$VAULT"; printf "$(L p_summary)" "$nconc" "$nrepo"
awk -F'\t' -v k="$(L st_known)" -v f="$(L st_fuzzy)" -v u="$(L st_unknown)" -v a="$(L st_unasked)" '{ n[$5]++ } END { printf(" %s %d %s %d %s %d %s %d\n", k, n["known"]+0, f, n["fuzzy"]+0, u, n["unknown"]+0, a, n["unasked"]+0) }' "$tsv"
