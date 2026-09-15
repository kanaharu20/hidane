#!/bin/sh
# hidane next.sh — 次に問う関数を 1 つ選ぶ。LLM は使わない。
#
# 使い方: next.sh [--root DIR] [--repo NAME] [--tree DIR] [--today D] [-n N] [--focus [概念]]
#   --focus [概念]  集中モード。その概念(省略なら順位が最上位の概念)の関数を続けて HIDANE_FOCUS_N 問(既定 3)出す。
#                   <root>/<repo>/focus に「概念<TAB>残り」を置き、以後の呼び出しはそれに従う。record.sh が 1 つ減らす
#   概念の順位は全 repo の値から(unknown > fuzzy > unasked、同じ状態なら値の低い順)。
#   候補の関数は今いる repo の functions.md / log.md から。すでに問うた関数(同じファイル・同じ名前。行がずれても同じ)は除く。
#   作業ツリー(git の root、または --tree)に、その場所にその関数名が今も無ければ除く(消えた・ずれた関数)。
#   known の概念からは出さない。-n N で上位 N 件を表にする。
# 出力は決まった形。Claude はこれをそのまま使って問いを作る。
# 型もここで決める(一度でも答えた概念 → edge(境界を突く、重み 2)、初めての概念 → trace)。決めた内容は
# <root>/<repo>/pending(場所 関数 概念 型 代表)に置き、record.sh はそれと一致する記録しか受け付けない。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REPO=""; TODAY=""; N=1; TREE=""; FOCUS=""; FOCUS_C=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --today) TODAY="$2"; shift 2 ;;
    -n) N="$2"; shift 2 ;;
    --focus) FOCUS=1; shift; if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then FOCUS_C="$1"; shift; fi ;;
    --help|-h) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "next.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done
. "$HERE/lang.sh"
if [ -z "$REPO" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "next.sh: $(L r_norepo)" >&2; exit 3; }
  REPO=$(hidane_repo_key "$top"); [ -n "$TREE" ] || TREE="$top"
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
  sed -n "${a},${b}p" "$TREE/$file" | grep -Eq "(^|[^A-Za-z0-9_])$(printf '%s' "$fnm" | sed 's/[][\\.*^$]/\\\\&/g')([^A-Za-z0-9_]|$)"
}
stale=0
{ if [ -f "$d/functions.md" ]; then grep '^| 20' "$d/functions.md" | while IFS= read -r row; do if alive "$row"; then printf 'fn\t%s\n' "$row"; else printf 'stale\t%s\n' "$row"; fi; done; fi
  [ -f "$d/log.md" ] && grep '^| 20' "$d/log.md" | sed 's/^/log	/'; true; } | sh "$HERE/resolve.sh" --root "$ROOT" > "$tmp/mine"
stale=$(grep -c '^stale	' "$tmp/mine" || true)

# 集中モード。focus ファイル = 概念<TAB>残り。--focus で始め、残りがある間は次の問いもその概念から
ff="$d/focus"; fc=""; fleft=0
if [ -n "$FOCUS" ]; then
  if [ -n "$FOCUS_C" ]; then cut -f1 "$tmp/map" | grep -qxF "$FOCUS_C" || { printf "next.sh: $(L n_focus_unknown)\n" "$FOCUS_C" >&2; exit 2; }; fi
  printf '%s\t%s\n' "${FOCUS_C:-?}" "${HIDANE_FOCUS_N:-3}" > "$ff"
fi
if [ -f "$ff" ]; then fc=$(cut -f1 "$ff"); fleft=$(cut -f2 "$ff"); fi

awk -F'\t' -v map="$tmp/map" -v alllog="$tmp/alllog" -v n="$N" -v pending="$d/pending" \
  -v l_known="$(L st_known)" -v l_fuzzy="$(L st_fuzzy)" -v l_unknown="$(L st_unknown)" -v l_unasked="$(L st_unasked)" \
  -v ty_trace="$(L ty_trace)" -v ty_edge="$(L ty_edge)" \
  -v n_place="$(L n_place)" -v n_func="$(L n_func)" -v n_concepts="$(L n_concepts)" -v n_lead="$(L n_lead)" -v n_why="$(L n_why)" \
  -v n_zure="$(L n_zure)" -v n_type="$(L n_type)" -v n_inputs="$(L n_inputs)" -v n_form="$(L n_form)" \
  -v why_unknown="$(L n_why_unknown)" -v why_fuzzy="$(L n_why_fuzzy)" -v why_unasked="$(L n_why_unasked)" \
  -v in_edge="$(L n_inputs_edge)" -v in_trace="$(L n_inputs_trace)" -v form_text="$(L n_form_text)" -v edge_hint="$(L n_edge_hint)" \
  -v none_cand="$(L n_none_cand)" -v stale="$stale" -v focus="$fc" -v fleft="$fleft" -v ff="$ff" -v n_focus_left="$(L n_focus_left)" -v n_focus_none="$(L n_focus_none)" -v stale_note="$(printf "$(L n_stale)" "$stale")" -v h_concept="$(L h_concept)" -v h_state="$(L h_state)" -v h_value="$(L h_value)" -v h_place="$(L n_place)" -v h_func="$(L n_func)" -v l_dispute="$(L rs_dispute)" -f "$HERE/next.awk" "$tmp/mine"
