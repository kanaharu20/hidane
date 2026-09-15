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
#   .obsidian/graph.json Graph view の色。値 -6..+6 の 13 段(赤 → 黄 → 青緑)、未出題は灰。無いときだけ書く
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
{
  # 先頭: 全体の段階(状態ごとの数、答えた数と最終日)、最近求めた解説。Claude が解説の前に読む入口
  printf '# hidane\n\n## %s\n\n' "$(L i_overall)"
  awk -F'\t' -v k="$(L st_known)" -v f="$(L st_fuzzy)" -v u="$(L st_unknown)" -v a="$(L st_unasked)" '{ n[$5]++ } END { printf("%s %d / %s %d / %s %d / %s %d\n", k, n["known"]+0, f, n["fuzzy"]+0, u, n["unknown"]+0, a, n["unasked"]+0) }' "$tsv"
  q=0; lastd="-"
  for dd in "$ROOT"/*/; do [ -f "$dd/log.md" ] || continue; q=$((q + $(grep -c '^| 20' "$dd/log.md" || true))); l=$(grep '^| 20' "$dd/log.md" | cut -d'|' -f2 | cut -c2-11 | sort | tail -1); [ "$l" \> "$lastd" ] && lastd="$l"; done
  printf "$(L i_answered)\n\n" "$q" "$lastd"
  printf '## %s\n\n' "$(L i_recent)"
  if [ -f "$ROOT/explained.md" ] && grep -q '^| 20' "$ROOT/explained.md"; then grep '^| 20' "$ROOT/explained.md" | tail -5 | sed 's/^/- /'; else printf '%s\n' "$(L i_none)"; fi
  printf '\n## %s\n\n' "$(L i_table)"
  sh "$HERE/map.sh" --root "$ROOT" --today "$TODAY"
} > "$VAULT/index.md"

# 行を集めて awk に渡す(map.sh と同じ流し方)
# 作業ツリーに今も無い関数は gone(<repo>/path か log.md の先頭行から repo の場所を知る。分からなければ確かめない)
alive() { [ "$TREE" != "-" ] || return 1; [ -n "$TREE" ] || return 0; file=${1%%:*}; range=${1##*:}; a=${range%-*}; b=${range#*-}; [ -f "$TREE/$file" ] && sed -n "${a},${b}p" "$TREE/$file" | grep -Eq "(^|[^A-Za-z0-9_])$(printf '%s' "$2" | sed 's/[][\\.*^$]/\\\\&/g')([^A-Za-z0-9_]|$)"; }
for d in "$ROOT"/*/; do
  repo=$(basename "$d")
  TREE=$(cat "$d/path" 2>/dev/null || sed -n '1s/^# hidane — //p' "$d/log.md" 2>/dev/null || true)
  # 場所を知っていてそこに無ければ、その repo は丸ごと消えた("-" = 全部 gone)。場所を知らなければ確かめない("")
  case "$TREE" in /*) ;; *) TREE="" ;; esac
  if [ -n "$TREE" ] && [ ! -d "$TREE" ]; then printf '%s\tlost\t%s\n' "$repo" "$TREE"; TREE="-"; fi
  [ -f "$d/log.md" ] && grep '^| 20' "$d/log.md" | sed "s/^/$repo	log	/"
  [ -f "$d/functions.md" ] && grep '^| 20' "$d/functions.md" | while IFS= read -r row; do
    pl=$(printf '%s' "$row" | awk -F'|' '{ gsub(/^ +| +$/, "", $3); print $3 }'); fn=$(printf '%s' "$row" | awk -F'|' '{ gsub(/^ +| +$/, "", $4); print $4 }')
    if alive "$pl" "$fn"; then printf '%s\tfn\t%s\n' "$repo" "$row"; else printf '%s\tgone\t%s\n' "$repo" "$row"; fi; done
  true
done | sh "$HERE/resolve.sh" --root "$ROOT" | LC_ALL=C sort -t'	' -k3,3 | awk -F'\t' -v tsv="$tsv" -v vault="$VAULT" -v today="$TODAY" -v aliases="$ROOT/aliases.md" \
  -v l_known="$(L st_known)" -v l_fuzzy="$(L st_fuzzy)" -v l_unknown="$(L st_unknown)" -v l_unasked="$(L st_unasked)" -v l_tent="$(L st_tent)" \
  -v ty_trace="$(L ty_trace)" -v ty_edge="$(L ty_edge)" -v ty_summary="$(L ty_summary)" \
  -v rs_hit="$(L rs_hit)" -v rs_miss="$(L rs_miss)" -v rs_dunno="$(L rs_dunno)" -v rs_skip="$(L rs_skip)" -v rs_partial="$(L rs_partial)" \
  -v p_state="$(L p_state)" -v p_related="$(L p_related)" -v p_zure="$(L p_zure)" -v p_records="$(L p_records)" -v p_unasked="$(L p_unasked)" -v p_gone="$(L p_gone)" -v p_gone_n="$(L p_gone_n)" -v p_lost="$(L p_lost)" \
  -v h_concept="$(L h_concept)" -v h_state="$(L h_state)" -v h_value="$(L h_value)" -v h_evidence="$(L h_evidence)" -v h_last="$(L h_last)" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function fname(c) { gsub("/", "／", c); return c }
function label(st) { return (st == "known" ? l_known : st == "fuzzy" ? l_fuzzy : st == "unknown" ? l_unknown : l_unasked) }
function slabel(c) { return label(state[c]) ((evid[c] + 0 == 0 && nfn[c] + 0 <= 1) ? "(" l_tent ")" : "") }   # 仮: 関数が 1 つしか付いていない未出題の概念
function tlabel(t) { return (t == "trace" ? ty_trace : t == "edge" ? ty_edge : t == "summary" ? ty_summary : t) }
function rlabel(r) { return (r == "hit" ? rs_hit : r == "miss" ? rs_miss : r == "partial" ? rs_partial : r == "dunno" ? rs_dunno : r == "skip" ? rs_skip : r) }
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
  repo = $1; kind = $2; if (kind == "lost") { lost[repo] = $3; next }
  split($3, col, "|")
  date = substr(trim(col[2]), 1, 10); place = trim(col[3]); fnm = trim(col[4])
  k = split(trim(col[5]), cs, ",")
  for (i = 1; i <= k; i++) { cl[i] = trim(cs[i]); sub(/^\*/, "", cl[i]) }
  for (i = 1; i <= k; i++) for (j = 1; j <= k; j++) if (cl[i] != "" && cl[j] != "") link(cl[i], cl[j])
  for (i = 1; i <= k; i++) {
    c = cl[i]; if (c == "") continue
    if (kind == "log") {
      type = trim(col[6]); q = trim(col[7]); res = trim(col[8]); zure = trim(col[9])
      rec[c] = rec[c] sprintf("- %s [[%s]] `%s` %s — %s — %s%s\n", date, repo, place, fnm, tlabel(type), rlabel(res), (q != "" ? "(" q ")" : ""))
      if (zure != "") zl[c] = zl[c] sprintf("- %s(%s, %s)\n", zure, repo, date)
      rc[repo] = rc[repo] c "\n"
    } else {
      fog[c] = fog[c] sprintf("- %s [[%s]] `%s` %s%s\n", date, repo, place, fnm, (kind == "gone" ? " " p_gone : ""))
      if (kind == "fn") nfn[c]++
      if (kind == "gone" && !((repo SUBSEP place) in gseen)) { gseen[repo SUBSEP place] = 1; gone[repo]++ }
      rc[repo] = rc[repo] c "\n"
    }
  }
}
END {
  # 概念ページ
  for (i = 1; i <= nc; i++) {
    c = order[i]; f = vault "/concepts/" fname(c) ".md"
    r = repos[c]; gsub(",", ", ", r)
    v = value[c] + 0; tone = (evid[c] + 0 == 0 ? (nfn[c] + 0 <= 1 ? "tent" : "off") : v < 0 ? "v_m" (-v) : v > 0 ? "v_p" v : "v_z0")
    printf("---\nstate: %s\nvalue: %s\ntone: %s\nevidence: %s\nlast: %s\nrepos: [%s]\n", state[c], value[c], tone, evid[c], last[c], r) > f
    if (al[c] != "") printf("aliases: [%s]\n", al[c]) > f
    printf("updated: %s\n---\n# %s\n\n", today, c) > f
    printf("%s **%s**(%s %s, %s %s, %s %s)\n\n", p_state, slabel(c), h_value, value[c], h_evidence, evid[c], h_last, last[c]) > f
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
    printf("---\nkind: repo\nupdated: %s\n---\n# %s\n\n", today, repo) > f
    if (repo in lost) { printf(p_lost "\n\n", lost[repo]) > f }
    if (gone[repo] > 0) { printf(p_gone_n "\n\n", gone[repo]) > f }
    printf("| %s | %s | %s |\n|---|---|---|\n", h_concept, h_state, h_value) > f
    n = split(rc[repo], cs, "\n"); delete done
    for (i = 1; i <= n; i++) { c = cs[i]; if (c == "" || (c in done)) continue; done[c] = 1
      printf("| [[%s]] | %s | %s |\n", fname(c), slabel(c), value[c]) > f }
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

# Graph view の色。値 -6..+6 の 13 段(赤 → 黄 → 青緑)。frontmatter の tone: v_m6..v_z0..v_p6 で塗る(未出題は off = 灰)。
# tone の記号は互いに部分文字列にならない(Obsidian の property 検索は部分一致のため)。
# 無いときだけ書く。旧方式(state ごとの 4 色)の graph.json は丸ごと作り直す(.bak を残す)
g="$VAULT/.obsidian/graph.json"
if [ -f "$g" ] && grep -q '\[state:\(known\|fuzzy\|unknown\|理解\|曖昧\|非理解\|霧\|未出題\)' "$g"; then cp "$g" "$g.bak"; rm -f "$g"; fi
# 0.5.5 より前の graph.json に仮(tent)の色を足す
if [ -f "$g" ] && ! grep -q '\[tone:tent\]' "$g"; then   # 1 行形式でも Obsidian が整形した複数行形式でも、colorGroups の先頭に足す
  cp "$g" "$g.bak"; awk '{ print } /"colorGroups": \[/ { match($0, /^ */); printf("%s  { \"query\": \"[tone:tent]\", \"color\": { \"a\": 1, \"rgb\": 5592405 } },\n", substr($0, 1, RLENGTH)) }' "$g.bak" > "$g"
fi
[ -f "$g" ] || cat > "$g" <<'JSON'
{
  "collapse-color-groups": false,
  "colorGroups": [
    { "query": "[tone:v_m6]", "color": { "a": 1, "rgb": 16729943 } },
    { "query": "[tone:v_m5]", "color": { "a": 1, "rgb": 16735827 } },
    { "query": "[tone:v_m4]", "color": { "a": 1, "rgb": 16741711 } },
    { "query": "[tone:v_m3]", "color": { "a": 1, "rgb": 16747595 } },
    { "query": "[tone:v_m2]", "color": { "a": 1, "rgb": 16753735 } },
    { "query": "[tone:v_m1]", "color": { "a": 1, "rgb": 16759619 } },
    { "query": "[tone:v_z0]", "color": { "a": 1, "rgb": 16765503 } },
    { "query": "[tone:v_p1]", "color": { "a": 1, "rgb": 14210383 } },
    { "query": "[tone:v_p2]", "color": { "a": 1, "rgb": 11721056 } },
    { "query": "[tone:v_p3]", "color": { "a": 1, "rgb": 9165936 } },
    { "query": "[tone:v_p4]", "color": { "a": 1, "rgb": 6610816 } },
    { "query": "[tone:v_p5]", "color": { "a": 1, "rgb": 4121489 } },
    { "query": "[tone:v_p6]", "color": { "a": 1, "rgb": 1566369 } },
    { "query": "[tone:off]",  "color": { "a": 1, "rgb": 7041144 } },
    { "query": "[tone:tent]", "color": { "a": 1, "rgb": 5592405 } },
    { "query": "path:repos",  "color": { "a": 1, "rgb": 13620186 } }
  ],
  "showTags": false, "showAttachments": false, "hideUnresolved": true, "showOrphans": true,
  "textFadeMultiplier": 0, "nodeSizeMultiplier": 1.2, "lineSizeMultiplier": 1
}
JSON

nconc=$(ls "$VAULT/concepts" | wc -l | tr -d ' '); nrepo=$(ls "$VAULT/repos" | wc -l | tr -d ' ')
printf 'pages.sh: %s: ' "$VAULT"; printf "$(L p_summary)" "$nconc" "$nrepo"
awk -F'\t' -v k="$(L st_known)" -v f="$(L st_fuzzy)" -v u="$(L st_unknown)" -v a="$(L st_unasked)" '{ n[$5]++ } END { printf(" %s %d %s %d %s %d %s %d\n", k, n["known"]+0, f, n["fuzzy"]+0, u, n["unknown"]+0, a, n["unasked"]+0) }' "$tsv"
