#!/bin/sh
# hidane next.sh — 次に問う関数を 1 つ選ぶ。LLM は使わない。
#
# 使い方: next.sh [--root DIR] [--repo NAME] [--today D] [-n N]
#   概念の順位は全 repo の値から(非理解 > 曖昧 > 霧、同じ状態なら値の低い順)。
#   候補の関数は今いる repo の functions.md / log.md から。すでに問うた場所は除く。
#   理解の概念からは出さない。-n N で上位 N 件を表にする。
# 出力は決まった形。Claude はこれをそのまま使って問いを作る。
# 型もここで決める(過去のズレがある概念 → 追う(境界・変異)、無ければ 追う)。決めた内容は
# <root>/<repo>/pending に置き、record.sh はそれと一致する記録しか受け付けない。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REPO=""; TODAY=""; N=1
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --today) TODAY="$2"; shift 2 ;;
    -n) N="$2"; shift 2 ;;
    --help|-h) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "next.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$REPO" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "next.sh: git リポジトリの中で実行するか --repo を付けてください" >&2; exit 3; }
  REPO=$(basename "$top")
fi
[ -n "$TODAY" ] || TODAY=$(date +%Y-%m-%d)
d="$ROOT/$REPO"
[ -f "$d/functions.md" ] || [ -f "$d/log.md" ] || { echo "next.sh: $REPO には記録が無い。commit して霧を作るか、tag.sh --commit HEAD を回してください" >&2; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
sh "$HERE/map.sh" --root "$ROOT" --today "$TODAY" --tsv > "$tmp/map"
# 全 repo の log から、概念ごとの過去のズレ
for r in "$ROOT"/*/; do
  [ -f "$r/log.md" ] && grep '^| 20' "$r/log.md" | sed "s/^/$(basename "$r")	/"
  true
done | sh "$HERE/resolve.sh" --root "$ROOT" > "$tmp/alllog"
{ [ -f "$d/functions.md" ] && grep '^| 20' "$d/functions.md" | sed 's/^/fn	/'; [ -f "$d/log.md" ] && grep '^| 20' "$d/log.md" | sed 's/^/log	/'; true; } | sh "$HERE/resolve.sh" --root "$ROOT" > "$tmp/mine"

awk -F'\t' -v map="$tmp/map" -v alllog="$tmp/alllog" -v n="$N" -v pending="$d/pending" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function rank(st) { return (st == "非理解" ? 0 : st == "曖昧" ? 1 : st == "霧" ? 2 : 9) }
BEGIN {
  while ((getline l < map) > 0) { split(l, t, "\t"); c = t[1]; val[c] = t[2]; st[c] = t[5]; if (!(c in st)) st[c] = "霧" }
  while ((getline l < alllog) > 0) {
    split(l, t, "\t"); repo = t[1]; split(t[2], col, "|"); z = trim(col[9]); k = split(trim(col[5]), cs, ",")
    if (z == "") continue
    for (i = 1; i <= k; i++) { c = trim(cs[i]); if (c != "") zure[c] = zure[c] "- " z "(" repo ", " substr(trim(col[2]), 1, 10) ")\n" }
  }
}
{
  kind = $1; split($2, col, "|"); place = trim(col[3]); fnm = trim(col[4]); k = split(trim(col[5]), cs, ",")
  if (kind == "log") { asked[place] = 1; next }
  if (place in seenp) next; seenp[place] = 1
  for (i = 1; i <= k; i++) { c = trim(cs[i]); if (c == "") continue; cand[place] = cand[place] (cand[place] == "" ? "" : ", ") c; fname[place] = fnm }
}
END {
  # 候補を採点: 概念のうち最も順位の高いものを代表にする
  m = 0
  for (p in cand) {
    if (p in asked) continue
    best = 99; bv = 999; bc = ""
    k = split(cand[p], cs, ", ")
    for (i = 1; i <= k; i++) { c = cs[i]; r = rank(st[c]); v = val[c] + 0
      if (r < best || (r == best && v < bv)) { best = r; bv = v; bc = c } }
    if (best == 9) continue                          # 理解の概念だけの関数は出さない
    m++; key[m] = sprintf("%d\t%+04d\t%s", best, bv + 100, p); P[m] = p; C[m] = bc
  }
  if (m == 0) { print "候補なし: この repo の関数は全部問うた(または理解のみ)。commit して霧を作るか、tag.sh --commit HEAD を回す" > "/dev/stderr"; exit 1 }
  # 並べ替え(単純な挿入ソート)
  for (i = 2; i <= m; i++) { for (j = i; j > 1 && key[j] < key[j-1]; j--) { sw = key[j]; key[j] = key[j-1]; key[j-1] = sw; sw = P[j]; P[j] = P[j-1]; P[j-1] = sw; sw = C[j]; C[j] = C[j-1]; C[j-1] = sw } }
  if (n > 1) {
    print "| 順 | 場所 | 関数 | 代表の概念 | 状態 | 値 | 全概念 |"; print "|---|---|---|---|---|---|---|"
    for (i = 1; i <= m && i <= n; i++) printf("| %d | %s | %s | %s | %s | %+d | %s |\n", i, P[i], fname[P[i]], C[i], st[C[i]], val[C[i]], cand[P[i]])
    exit 0
  }
  p = P[1]; c = C[1]
  printf("場所: %s\n関数: %s\n概念: %s\n代表: %s(%s、値 %+d)\n", p, fname[p], cand[p], c, st[c], val[c])
  why = (st[c] == "非理解" ? "非理解の概念に付いた、まだ問うていない関数" : st[c] == "曖昧" ? "曖昧な概念に付いた、まだ問うていない関数" : "霧(証拠なし)の関数")
  printf("理由: %s\n", why)
  if (zure[c] != "") {
    type = "追う(境界・変異)"
    printf("過去のズレ(%s):\n%s", c, zure[c])
    printf("型: %s\n", type)
    printf("入力の候補: 空 / 1 個だけ / 末尾 / 上限ちょうど / 過去のズレの状況を再現する値、のどれか 1 つ\n")
  } else {
    type = "追う"
    printf("型: %s\n", type)
    printf("入力の候補: 普通の値を 1 つ\n")
  }
  printf("問いの形: 「<場所> <関数>。<入力> のとき、何を返す / 何が起きるか」の 1 問だけ。「なぜ」「何が必要か」は問わない\n")
  printf("%s\t%s\t%s\t%s\n", p, fname[p], cand[p], type) > pending
  close(pending)
}' "$tmp/mine"
