#!/bin/sh
# hidane weak.sh — 弱い所の材料を地図から集める。Claude はこれを読んで 1 枚にまとめる(値も状態も変えない)。
#
# 使い方: weak.sh [--root DIR] [--repo NAME] [--tree DIR] [--today YYYY-MM-DD] [-n N]
#   選ぶ概念 = 非理解・曖昧 のうち、ズレ(miss / partial)の記録が 1 件以上あるもの。値の低い順に N 個(既定 3、HIDANE_WEAK_N)
#   出す物  = 冒頭の「地図から」2 行(そのまま解説の先頭に置く)、概念ごとのズレ全件(新しい順)、今いる repo でその概念が付いた関数(作業ツリーに今も在るものだけ、8 個まで)
#   ズレの記録が 1 件も無ければ stderr に 1 行出して exit 1
# 分からない(dunno)だけの概念は「弱い」ではなく「まだ材料が無い」ので選ばない。LLM は使わない。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REPO=""; TREE=""; TODAY=$(date +%Y-%m-%d); N="${HIDANE_WEAK_N:-3}"
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --today) TODAY="$2"; shift 2 ;;
    -n) N="$2"; shift 2 ;;
    --help|-h) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "weak.sh: unknown option: $1" >&2; exit 2 ;;
  esac
done
. "$HERE/lang.sh"
top=$(git rev-parse --show-toplevel 2>/dev/null) || top=""
[ -n "$REPO" ] || { if [ -n "$top" ]; then REPO=$(hidane_repo_key "$top"); else REPO="-"; fi; }
[ -n "$TREE" ] || TREE="$top"
# 作業ツリーに今も無い関数は挙げない(next.sh と同じ確かめ方)
alive() { [ -n "$TREE" ] || return 0; file=${1%%:*}; range=${1##*:}; a=${range%-*}; b=${range#*-}; [ -f "$TREE/$file" ] && sed -n "${a},${b}p" "$TREE/$file" | grep -Eq "(^|[^A-Za-z0-9_])$(printf '%s' "$2" | sed 's/[][\\.*^$]/\\\\&/g')([^A-Za-z0-9_]|$)"; }
tsv=$(mktemp); trap 'rm -f "$tsv"' EXIT
sh "$HERE/map.sh" --root "$ROOT" --today "$TODAY" --tsv > "$tsv" 2>/dev/null || true
for d in "$ROOT"/*/; do
  r=$(basename "$d")
  [ -f "$d/log.md" ] && grep '^| 20' "$d/log.md" | sed "s/^/$r	log	/"
  [ -f "$d/functions.md" ] && [ "$r" = "$REPO" ] && grep '^| 20' "$d/functions.md" | while IFS= read -r row; do
    pl=$(printf '%s' "$row" | awk -F'|' '{ gsub(/^ +| +$/, "", $3); print $3 }'); fn=$(printf '%s' "$row" | awk -F'|' '{ gsub(/^ +| +$/, "", $4); print $4 }')
    alive "$pl" "$fn" && printf '%s\tfn\t%s\n' "$r" "$row"; done
  true
done | sh "$HERE/resolve.sh" --root "$ROOT" | awk -F'\t' -v tsv="$tsv" -v n="$N" -v repo="$REPO" \
  -v l_known="$(L st_known)" -v l_fuzzy="$(L st_fuzzy)" -v l_unknown="$(L st_unknown)" \
  -v w_head1="$(L w_head1)" -v w_head2="$(L w_head2)" -v w_none_skip="$(L w_none_skip)" -v w_sep="$(L w_sep)" \
  -v w_concept="$(L w_concept)" -v w_funcs="$(L w_funcs)" -v w_nofuncs="$(L w_nofuncs)" -v w_none="$(L w_none)" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function label(st) { return (st == "known" ? l_known : st == "fuzzy" ? l_fuzzy : l_unknown) }
BEGIN { while ((getline l < tsv) > 0) { split(l, t, "\t"); c = t[1]; val[c] = t[2]; st[c] = t[5]; order[++nc] = c }; close(tsv) }
{
  r = $1; kind = $2; split($3, col, "|"); date = substr(trim(col[2]), 1, 10); place = trim(col[3]); fnm = trim(col[4])
  k = split(trim(col[5]), cs, ",")
  for (i = 1; i <= k; i++) {
    c = trim(cs[i]); if (c == "") continue
    if (kind == "log") { z = trim(col[9]); if (z != "") { nz[c]++; zl[c] = sprintf("- %s %s `%s` (%s): %s\n", date, fnm, place, r, z) zl[c] } }
    else if (r == repo) { fk = c SUBSEP fnm; if (!(fk in seen)) { seen[fk] = 1; nf[c]++ }; fplace[fk] = place }
  }
}
END {
  m = 0
  for (i = 1; i <= nc; i++) { c = order[i]; if ((st[c] == "unknown" || st[c] == "fuzzy") && nz[c] > 0 && m < n) pick[++m] = c }
  if (m == 0) { print w_none > "/dev/stderr"; exit 1 }
  for (i = 1; i <= nc; i++) if (st[order[i]] == "known") known = known (known == "" ? "" : ", ") order[i]
  for (i = 1; i <= m; i++) { c = pick[i]; total += nz[c]; if (st[c] == "unknown") u = u (u == "" ? "" : ", ") c; else f = f (f == "" ? "" : ", ") c }
  printf(w_head1 "\n", (u == "" ? "-" : u), (f == "" ? "-" : f), total)
  printf(w_head2 "\n\n", (known == "" ? w_none_skip : known))
  for (i = 1; i <= m; i++) {
    c = pick[i]
    printf("## %s(%s, %+d, " w_concept ")\n%s", c, label(st[c]), val[c], nz[c], zl[c])
    q = 0
    for (fk in fplace) { split(fk, p, SUBSEP); if (p[1] == c) { q++; fl[q] = "  " fplace[fk] " " p[2] } }
    for (a = 2; a <= q; a++) for (b = a; b > 1 && fl[b] < fl[b-1]; b--) { sw = fl[b]; fl[b] = fl[b-1]; fl[b-1] = sw }
    if (q > 8) q = 8
    if (q > 0) { printf(w_funcs ":\n", repo); for (a = 1; a <= q; a++) print fl[a] } else print w_nofuncs
    printf("\n"); split("", fl)
  }
}'
