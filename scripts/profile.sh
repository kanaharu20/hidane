#!/bin/sh
# hidane profile.sh — ある関数について「その人にどう解説するか」の指示を、地図から決めて出す。
#
# 使い方: profile.sh [--root DIR] [--repo NAME] [--today D] [場所 | 関数名]
#   場所 file:a-b か関数名で指定。無ければ直前に問うた関数(ズレた直後に解説を求める使い方)。
#   概念ごとに、状態から指示を決める:
#     known   → 飛ばす(既知として前提にする)
#     unknown → 膨らませる。過去のズレを先に突く
#     fuzzy   → 普通に述べる。過去のズレがあれば触れる
#     unasked → 一言だけ。求められたら詳しく
#   長さの目安と書く順も出す。解説の文そのものは Claude が書く。
#   解説を求めた事実を <root>/<repo>/explained.md に 1 行残す(next.sh が読む)。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REPO=""; TODAY=""; TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --today) TODAY="$2"; shift 2 ;;
    --help|-h) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "profile.sh: unknown arg: $1" >&2; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done
. "$HERE/lang.sh"
if [ -z "$REPO" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "profile.sh: $(L r_norepo)" >&2; exit 3; }
  REPO=$(basename "$top")
fi
[ -n "$TODAY" ] || TODAY=$(date +%Y-%m-%d)
d="$ROOT/$REPO"
[ -f "$d/functions.md" ] || [ -f "$d/log.md" ] || { echo "profile.sh: $REPO $(L n_none_repo)" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
sh "$HERE/map.sh" --root "$ROOT" --today "$TODAY" --tsv > "$tmp/map"
for r in "$ROOT"/*/; do [ -f "$r/log.md" ] && grep '^| 20' "$r/log.md" | sed "s/^/$(basename "$r")	/"; true; done | sh "$HERE/resolve.sh" --root "$ROOT" > "$tmp/alllog"
{ [ -f "$d/functions.md" ] && grep '^| 20' "$d/functions.md" | sed 's/^/fn	/'; [ -f "$d/log.md" ] && grep '^| 20' "$d/log.md" | sed 's/^/log	/'; true; } | sh "$HERE/resolve.sh" --root "$ROOT" > "$tmp/mine"

awk -F'\t' -v map="$tmp/map" -v alllog="$tmp/alllog" -v target="$TARGET" -v today="$TODAY" -v explained="$d/explained.md" \
  -v l_known="$(L st_known)" -v l_fuzzy="$(L st_fuzzy)" -v l_unknown="$(L st_unknown)" -v l_unasked="$(L st_unasked)" \
  -v n_place="$(L n_place)" -v n_func="$(L n_func)" -v e_dir="$(L e_dir)" -v e_skip="$(L e_skip)" -v e_expand="$(L e_expand)" \
  -v e_normal="$(L e_normal)" -v e_brief="$(L e_brief)" -v e_zure="$(L e_zure)" -v e_len="$(L e_len)" -v e_order="$(L e_order)" \
  -v e_none="$(L e_none)" -v e_notfound="$(L e_notfound)" -v e_last="$(L e_last)" -v e_rules="$(L e_rules)" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function label(st) { return (st == "known" ? l_known : st == "fuzzy" ? l_fuzzy : st == "unknown" ? l_unknown : l_unasked) }
BEGIN {
  while ((getline l < map) > 0) { split(l, t, "\t"); val[t[1]] = t[2]; st[t[1]] = t[5] }
  while ((getline l < alllog) > 0) { split(l, t, "\t"); split(t[2], col, "|"); z = trim(col[9]); if (z == "") continue
    k = split(trim(col[5]), cs, ","); for (i = 1; i <= k; i++) { c = trim(cs[i]); if (c != "") zure[c] = zure[c] (zure[c] == "" ? "" : "; ") z } }
}
{
  kind = $1; split($2, col, "|"); place = trim(col[3]); fnm = trim(col[4]); cstr = trim(col[5])
  if (!(place in concepts) || kind == "fn") { concepts[place] = cstr; fname[place] = fnm }
  if (kind == "log") lastplace = place
}
END {
  if (target == "") { p = lastplace; if (p == "") { print e_none > "/dev/stderr"; exit 1 } ; how = e_last }
  else { p = ""; for (q in concepts) if (q == target || fname[q] == target) { p = q; break }
         if (p == "") { print e_notfound ": " target > "/dev/stderr"; exit 1 }; how = "" }
  printf("%s: %s\n%s: %s%s\n", n_place, p, n_func, fname[p], (how != "" ? " (" how ")" : ""))
  printf("%s:\n", e_dir)
  k = split(concepts[p], cs, ","); nu = 0; nf = 0; na = 0; order = ""
  for (i = 1; i <= k; i++) { c = trim(cs[i]); if (c == "") continue; s = st[c]; if (s == "") s = "unasked"
    if (s == "known") d = e_skip; else if (s == "unknown") { d = e_expand; nu++ } else if (s == "fuzzy") { d = e_normal; nf++ } else { d = e_brief; na++ }
    z = (zure[c] != "" && s != "known") ? "。" e_zure ": " zure[c] : ""
    printf("- %s [%s%s]: %s%s\n", c, label(s), (s == "unasked" ? "" : sprintf(", %+d", val[c] + 0)), d, z) }
  lines = 2 + nu * 6 + nf * 3 + na * 1
  printf("%s: %d\n%s\n%s\n", e_len, lines, e_order, e_rules)
  if ((getline l < explained) < 0) printf("| date | place | function | concepts |\n|---|---|---|---|\n") > explained
  close(explained)
  printf("| %s | %s | %s | %s |\n", today, p, fname[p], concepts[p]) >> explained
}' "$tmp/mine"
