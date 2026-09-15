#!/bin/sh
# hidane keys.sh — 答えを聞く前に、正解の要素(鍵)を固定する。
#
# 使い方: keys.sh [--root DIR] [--repo NAME] "種別: 鍵 1 @ a-b" "種別: 鍵 2 @ a-b" ... (2〜5 個)
#   種別 = 返り値 / 分岐 / 呼び出し / 順序 / 状態(英語 return / branch / call / order / state でも可。表示言語の語に揃えて保存する)
#   保存したあと「問いの結び: 「何を返しますか。そうなる条件も添えてください」」を出す。問いの最後の文をこの結びで終える(鍵の中身・種別名・数は出ない)。
#   聞くものは 1 つ(返り値 / 呼び出し / 順序 / 状態。呼び出し+順序は「どの順で呼ばれるか」として可)。分岐はそれを決めるものとして添える。「@ 行」は問う関数の範囲内。
#   これで、鍵にした事実は全部ユーザーが答えられる範囲に入る(問いが返り値だけを聞いて、鍵が途中の分岐まで求めるずれを防ぐ)。
#         keys.sh [--root DIR] [--repo NAME] --show
#   鍵 = 具体的で確かめられる事実 1 つ(返り値、呼ばれる関数、実行の順序、通る分岐)。理由は書かない(「ので」「because」を含む鍵は exit 2)。
#   末尾の「@ a-b」はその事実がある行(任意)。partial / miss のとき、ユーザーには行番号だけを見せる。
# next.sh が決めた pending が無いと書かない(exit 5)。鍵は <root>/<repo>/keys に置き、record.sh が消す。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; REPO=""; SHOW=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --show) SHOW=1; shift ;;
    --help|-h) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; break ;;
    -*) echo "keys.sh: unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
. "$HERE/lang.sh"
if [ -z "$REPO" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "keys.sh: $(L r_norepo)" >&2; exit 3; }
  REPO=$(hidane_repo_key "$top")
fi
kf="$ROOT/$REPO/keys"
if [ -n "$SHOW" ]; then [ -f "$kf" ] && cat "$kf"; exit 0; fi
[ -f "$ROOT/$REPO/pending" ] || { echo "keys.sh: $(L k_nopending)" >&2; exit 5; }
[ $# -ge 2 ] && [ $# -le 5 ] || { echo "keys.sh: $(L k_count) ($#)" >&2; exit 2; }
place=$(cut -f1 "$ROOT/$REPO/pending"); rng=${place##*:}; ra=${rng%-*}; rb=${rng#*-}
case "$ra$rb" in *[!0-9]*|"") ra="" ;; esac   # 範囲が読めなければ行の検査はしない
: > "$kf"
i=0; n_ret=0; n_branch=0; n_call=0; n_order=0; n_state=0
for k in "$@"; do
  i=$((i+1))
  k=$(printf '%s' "$k" | tr '\n\t' '  ' | sed 's/|/｜/g; s/^ *//; s/ *$//')
  [ -n "$k" ] || { rm -f "$kf"; echo "keys.sh: $(L k_empty) ($i)" >&2; exit 2; }
  case "$k" in *ので*|*なぜなら*|*[Bb]ecause*) rm -f "$kf"; printf "keys.sh: $(L k_reason)\n" "$i" >&2; exit 2 ;; esac
  head=${k%%:*}; head=$(printf '%s' "$head" | sed 's/ *$//'); rest=${k#*:}; rest=$(printf '%s' "$rest" | sed 's/^ *//')
  case "$head" in
    返り値|return|[Rr]eturn\ value) c=ret; n_ret=$((n_ret+1)) ;;
    分岐|branch) c=branch; n_branch=$((n_branch+1)) ;;
    呼び出し|call) c=call; n_call=$((n_call+1)) ;;
    順序|order) c=order; n_order=$((n_order+1)) ;;
    状態|state) c=state; n_state=$((n_state+1)) ;;
    *) rm -f "$kf"; printf "keys.sh: $(L k_cat)\n" "$i" >&2; exit 2 ;;
  esac
  [ -n "$rest" ] || { rm -f "$kf"; echo "keys.sh: $(L k_empty) ($i)" >&2; exit 2; }
  # 「@ 行」はこの関数の範囲内。別ファイルや呼んだ先の行は弾く
  case "$rest" in *@*)
    at=$(printf '%s' "${rest##*@}" | sed 's/^ *//; s/ *$//'); bad=""
    case "$at" in *[!0-9,\ -]*) bad=1 ;; esac
    if [ -z "$bad" ] && [ -n "$ra" ]; then for n in $(printf '%s' "$at" | tr ',-' '  '); do [ "$n" -ge "$ra" ] && [ "$n" -le "$rb" ] || bad=1; done; fi
    [ -z "$bad" ] || { rm -f "$kf"; printf "keys.sh: $(L k_range)\n" "$i" "$at" "$place" >&2; exit 2; } ;;
  esac
  printf '%d\t%s: %s\n' "$i" "$(L k_c_$c)" "$rest" >> "$kf"
done
# 聞くものは 1 つ(返り値 / 呼び出し / 順序 / 状態)。分岐はそれを決めるものとして添える。呼び出し+順序は「どの順で呼ばれるか」として 1 つ
prim=""; np=0; pl=""
for c in ret call order state; do eval n=\$n_$c; [ "$n" -gt 0 ] || continue; np=$((np+1)); prim="$prim${prim:+ }$c"; pl="$pl${pl:+, }$(L k_p_$c)"; done
[ "$np" -ge 1 ] || { rm -f "$kf"; echo "keys.sh: $(L k_noprim)" >&2; exit 2; }
if [ "$np" -gt 1 ] && [ "$prim" != "call order" ]; then rm -f "$kf"; printf "keys.sh: $(L k_one)\n" "$np" "$pl" >&2; exit 2; fi
cp "$ROOT/$REPO/pending" "$kf.pending"   # どの問いの鍵かを残す。record.sh が pending と照合する
printf "keys.sh: $(L k_saved)\n" "$i"
case "$prim" in "call order") end=$(L k_e_callorder) ;; *) end=$(L k_e_$prim) ;; esac
[ "$n_branch" -gt 0 ] && end="$end$(L k_e_branch)"
printf "$(L k_end)\n%s\n" "$end" "$(L k_end_note)"
