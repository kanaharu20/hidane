#!/bin/sh
# hidane next.sh — 次に問う関数を 1 つ選ぶ。LLM は使わない。
#
# 使い方: next.sh [--root DIR] [--repo NAME] [--tree DIR] [--today D] [-n N]
#   概念の順位は全 repo の値から(unknown > fuzzy > unasked、同じ状態なら値の低い順)。
#   候補の関数は今いる repo の functions.md / log.md から。すでに問うた場所は除く。
#   作業ツリー(git の root、または --tree)に、その場所にその関数名が今も無ければ除く(消えた・ずれた関数)。
#   解説した関数(explained.md): 同じ日は候補から外す。1〜3 日後なら最優先で問う(テスト効果)。備考に「解説の N 日後」を付ける。
#   known の概念からは出さない。-n N で上位 N 件を表にする。
# 出力は決まった形。Claude はこれをそのまま使って問いを作る。
# 型もここで決める(過去のズレがある概念 → edge、無ければ trace)。決めた内容は
# <root>/<repo>/pending に置き、record.sh はそれと一致する記録しか受け付けない。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REPO=""; TODAY=""; N=1; TREE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --today) TODAY="$2"; shift 2 ;;
    -n) N="$2"; shift 2 ;;
    --help|-h) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "next.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done
. "$HERE/lang.sh"
if [ -z "$REPO" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "next.sh: $(L r_norepo)" >&2; exit 3; }
  REPO=$(basename "$top"); [ -n "$TREE" ] || TREE="$top"
fi
[ -n "$TODAY" ] || TODAY=$(date +%Y-%m-%d)
d="$ROOT/$REPO"
[ -f "$d/functions.md" ] || [ -f "$d/log.md" ] || { echo "next.sh: $REPO $(L n_none_repo)" >&2; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
sh "$HERE/map.sh" --root "$ROOT" --today "$TODAY" --tsv > "$tmp/map"
for r in "$ROOT"/*/; do
  [ -f "$r/log.md" ] && grep '^| 20' "$r/log.md" | sed "s/^/$(basename "$r")	/"
  true
done | sh "$HERE/resolve.sh" --root "$ROOT" > "$tmp/alllog"
# 作業ツリーに今も無い関数(ファイルが消えた、行がずれて名前が範囲に無い)は候補から外す
alive() {  # $1 = fn 行。TREE が無ければ全部通す
  [ -n "$TREE" ] || return 0
  place=$(printf '%s' "$1" | awk -F'|' '{ gsub(/^ +| +$/, "", $3); print $3 }'); fnm=$(printf '%s' "$1" | awk -F'|' '{ gsub(/^ +| +$/, "", $4); print $4 }')
  file=${place%%:*}; range=${place##*:}; a=${range%-*}; b=${range#*-}
  [ -f "$TREE/$file" ] || return 1
  sed -n "${a},${b}p" "$TREE/$file" | grep -qF "$fnm"
}
stale=0
{ if [ -f "$d/functions.md" ]; then grep '^| 20' "$d/functions.md" | while IFS= read -r row; do if alive "$row"; then printf 'fn\t%s\n' "$row"; else printf 'stale\t%s\n' "$row"; fi; done; fi
  [ -f "$d/log.md" ] && grep '^| 20' "$d/log.md" | sed 's/^/log	/'; true; } | sh "$HERE/resolve.sh" --root "$ROOT" > "$tmp/mine"
stale=$(grep -c '^stale	' "$tmp/mine" || true)
[ -f "$d/explained.md" ] && grep '^| 20' "$d/explained.md" > "$tmp/explained" || : > "$tmp/explained"

awk -F'\t' -v map="$tmp/map" -v alllog="$tmp/alllog" -v n="$N" -v pending="$d/pending" \
  -v l_known="$(L st_known)" -v l_fuzzy="$(L st_fuzzy)" -v l_unknown="$(L st_unknown)" -v l_unasked="$(L st_unasked)" \
  -v ty_trace="$(L ty_trace)" -v ty_edge="$(L ty_edge)" \
  -v n_place="$(L n_place)" -v n_func="$(L n_func)" -v n_concepts="$(L n_concepts)" -v n_lead="$(L n_lead)" -v n_why="$(L n_why)" \
  -v n_zure="$(L n_zure)" -v n_type="$(L n_type)" -v n_inputs="$(L n_inputs)" -v n_form="$(L n_form)" \
  -v why_unknown="$(L n_why_unknown)" -v why_fuzzy="$(L n_why_fuzzy)" -v why_unasked="$(L n_why_unasked)" \
  -v in_edge="$(L n_inputs_edge)" -v in_trace="$(L n_inputs_trace)" -v form_text="$(L n_form_text)" -v edge_hint="$(L n_edge_hint)" \
  -v none_cand="$(L n_none_cand)" -v stale="$stale" -v stale_note="$(printf "$(L n_stale)" "$stale")" -v explained="$tmp/explained" -v today="$TODAY" -v n_explained="$(L n_explained)" -v h_concept="$(L h_concept)" -v h_state="$(L h_state)" -v h_value="$(L h_value)" -v h_place="$(L n_place)" -v h_func="$(L n_func)" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function rank(st) { return (st == "unknown" ? 0 : st == "fuzzy" ? 1 : st == "unasked" ? 2 : 9) }
function label(st) { return (st == "known" ? l_known : st == "fuzzy" ? l_fuzzy : st == "unknown" ? l_unknown : l_unasked) }
function jdn(d,   y, m, dd, a, yy, mm) { y = substr(d,1,4)+0; m = substr(d,6,2)+0; dd = substr(d,9,2)+0; a = int((14-m)/12); yy = y+4800-a; mm = m+12*a-3
  return dd + int((153*mm+2)/5) + 365*yy + int(yy/4) - int(yy/100) + int(yy/400) - 32045 }
BEGIN {
  while ((getline l < explained) > 0) { split(l, col, "|"); ep = trim(col[3]); ed = substr(trim(col[2]), 1, 10); ago = jdn(today) - jdn(ed)
    if (!(ep in exp_ago) || ago < exp_ago[ep]) exp_ago[ep] = ago }
  while ((getline l < map) > 0) { split(l, t, "\t"); c = t[1]; val[c] = t[2]; st[c] = t[5]; if (!(c in st)) st[c] = "unasked" }
  while ((getline l < alllog) > 0) {
    split(l, t, "\t"); repo = t[1]; split(t[2], col, "|"); z = trim(col[9]); k = split(trim(col[5]), cs, ",")
    if (z == "") continue
    for (i = 1; i <= k; i++) { c = trim(cs[i]); if (c != "") zure[c] = zure[c] "- " z "(" repo ", " substr(trim(col[2]), 1, 10) ")\n" }
  }
}
{
  kind = $1; split($2, col, "|"); place = trim(col[3]); fnm = trim(col[4]); k = split(trim(col[5]), cs, ",")
  if (kind == "log") { asked[place] = 1; next }
  if (kind == "stale") next
  if (place in seenp) next; seenp[place] = 1
  for (i = 1; i <= k; i++) { c = trim(cs[i]); if (c == "") continue; cand[place] = cand[place] (cand[place] == "" ? "" : ", ") c; fname[place] = fnm }
}
END {
  m = 0
  for (p in cand) {
    if (p in asked) continue
    if ((p in exp_ago) && exp_ago[p] == 0) continue            # 解説した当日は問わない
    best = 99; bv = 999; bc = ""
    k = split(cand[p], cs, ", ")
    for (i = 1; i <= k; i++) { c = cs[i]; r = rank(st[c]); v = val[c] + 0; if (r < best || (r == best && v < bv)) { best = r; bv = v; bc = c } }
    if (best == 9) continue
    if ((p in exp_ago) && exp_ago[p] >= 1 && exp_ago[p] <= 3) { best = -1; note[p] = sprintf(n_explained, exp_ago[p]) }   # 1〜3 日後は最優先
    m++; key[m] = sprintf("%d\t%+04d\t%s", best, bv + 100, p); P[m] = p; C[m] = bc
  }
  if (m == 0) { print none_cand (stale > 0 ? " (" stale_note ")" : "") > "/dev/stderr"; exit 1 }
  for (i = 2; i <= m; i++) { for (j = i; j > 1 && key[j] < key[j-1]; j--) { sw = key[j]; key[j] = key[j-1]; key[j-1] = sw; sw = P[j]; P[j] = P[j-1]; P[j-1] = sw; sw = C[j]; C[j] = C[j-1]; C[j-1] = sw } }
  if (n > 1) {
    printf("| # | %s | %s | %s | %s | %s | %s |\n|---|---|---|---|---|---|---|\n", h_place, h_func, n_lead, h_state, h_value, n_concepts)
    for (i = 1; i <= m && i <= n; i++) printf("| %d | %s | %s | %s | %s | %+d | %s |\n", i, P[i], fname[P[i]], C[i], label(st[C[i]]), val[C[i]], cand[P[i]])
    exit 0
  }
  p = P[1]; c = C[1]
  printf("%s: %s\n%s: %s\n%s: %s\n%s: %s(%s, %+d)\n", n_place, p, n_func, fname[p], n_concepts, cand[p], n_lead, c, label(st[c]), val[c])
  printf("%s: %s%s\n", n_why, (st[c] == "unknown" ? why_unknown : st[c] == "fuzzy" ? why_fuzzy : why_unasked), (note[p] != "" ? " / " note[p] : ""))
  if (zure[c] != "") { type = "edge"; printf("%s(%s):\n%s", n_zure, c, zure[c]); printf("%s: edge (%s) — %s\n%s: %s\n", n_type, ty_edge, edge_hint, n_inputs, in_edge) }
  else { type = "trace"; printf("%s: trace (%s)\n%s: %s\n", n_type, ty_trace, n_inputs, in_trace) }
  printf("%s: %s\n", n_form, form_text)
  printf("%s\t%s\t%s\t%s\t%s\n", p, fname[p], cand[p], type, note[p]) > pending
  close(pending)
}' "$tmp/mine"
