#!/bin/sh
# weak.sh の L0 検査。弱い所の材料は記録から決まり、値も状態も変えない。
set -u
cd "$(dirname "$0")/.." || exit 2
export HIDANE_LANG=ja
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/root"; mkdir -p "$ROOT/worker" "$ROOT/api" "$TMP/wt/src"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }
H='| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | miss | 備考 |
|---|---|---|---|---|---|---|---|---|'
F='| 日付 | 場所 | 関数 | 概念 | commit | 備考 |
|---|---|---|---|---|---|'
# worker+api: 停止フラグの伝搬 -5 非理解(ズレ 3)、ヒープ操作 +6 理解、境界条件 -1 曖昧(ズレ 1)、入力検証 -2 曖昧(dunno だけ、ズレ無し)
cat > "$ROOT/worker/log.md" <<L
$H
| 2026-09-05 | src/log.c:20-29 | log_line | 停止フラグの伝搬 | trace | q | miss | 停止後も 1 行出る |  |
| 2026-09-06 | src/stop.c:3-41 | request_stop | 停止フラグの伝搬 | summary | q | miss | wake の書き忘れ |  |
| 2026-09-07 | src/heap.c:3-16 | heap_push | ヒープ操作 | summary | q | hit |  |  |
| 2026-09-07 | src/heap.c:20-30 | heap_pop | ヒープ操作 | summary | q | hit |  |  |
| 2026-09-07 | src/a.c:1-9 | f | 境界条件 | trace | q | partial | 触れていない: 1 を返す @5 |  |
| 2026-09-07 | src/b.c:1-9 | g | 入力検証 | edge | q | dunno |  |  |
L
cat > "$ROOT/worker/functions.md" <<L
$F
| 2026-09-08 | src/log.c:20-29 | log_line | 停止フラグの伝搬 | abc |  |
| 2026-09-08 | src/mon.c:1-20 | monitor | 停止フラグの伝搬, 境界条件 | abc |  |
| 2026-09-08 | src/gone.c:1-4 | vanished | 停止フラグの伝搬 | abc |  |
L
cat > "$ROOT/api/log.md" <<L
$H
| 2026-09-04 | src/server.py:10-30 | serve | 停止フラグの伝搬 | trace | q | miss | api 側のズレ |  |
L
printf 'x\nx\n' > "$TMP/wt/src/log.c"; for i in $(seq 1 27); do echo "int log_line(void)" >> "$TMP/wt/src/log.c"; done
printf 'int monitor(void)\n' > "$TMP/wt/src/mon.c"
W="sh scripts/weak.sh --root $ROOT --repo worker --tree $TMP/wt --today 2026-09-08"
before=$(sh scripts/map.sh --root "$ROOT" --today 2026-09-08)

o=$($W); rc=$?
echo "$o" | sed -n 1p | grep -q '^地図から: 非理解 停止フラグの伝搬 → ここから書く。曖昧 境界条件。過去のズレ 4 件を使った$' && ok "W01 1 行目: 非理解と曖昧の概念、ズレの件数" || ng "W01" "$(echo "$o" | sed -n 1p)"
echo "$o" | sed -n 2p | grep -q '^飛ばした概念: ヒープ操作$' && ok "W02 2 行目: 理解している概念を飛ばす" || ng "W02" "$(echo "$o" | sed -n 2p)"
echo "$o" | grep -q '^## 停止フラグの伝搬(非理解, -5, ズレ 3 件)$' && ok "W03 概念の見出しに状態・値・ズレ数" || ng "W03" "$o"
[ "$(echo "$o" | awk '/^## 停止フラグの伝搬/{f=1;next} /^## /{f=0} f && /^- /' | cut -c3-12 | paste -sd, -)" = "2026-09-06,2026-09-05,2026-09-04" ] && ok "W04 ズレは repo をまたいで新しい順" || ng "W04" "$o"
echo "$o" | grep -q '^- 2026-09-04 serve `src/server.py:10-30` (api): api 側のズレ$' && ok "W05 ズレの行: 日付 関数 場所 (repo): 文" || ng "W05" "$o"
! echo "$o" | grep -q '入力検証' && ok "W06 dunno だけの概念は材料が無いので選ばない" || ng "W06" "$o"
{ echo "$o" | grep -q '^worker でこの概念が付いた関数:$' && echo "$o" | grep -q '^  src/log.c:20-29 log_line$' && echo "$o" | grep -q '^  src/mon.c:1-20 monitor$' && ! echo "$o" | grep -q 'vanished'; } && ok "W07 今いる repo の関数だけ、作業ツリーに無いものは出ない" || ng "W07" "$o"
o1=$($W -n 1); { echo "$o1" | sed -n 1p | grep -q '曖昧 -。過去のズレ 3 件' && ! echo "$o1" | grep -q '^## 境界条件'; } && ok "W08 -n で概念の数を絞る(曖昧が無ければ -)" || ng "W08" "$o1"
o2=$(sh scripts/weak.sh --root "$ROOT" --repo api --today 2026-09-08); echo "$o2" | grep -q '^(今いる repo にこの概念の関数は無い)$' && ok "W09 関数の無い repo は 1 行で言う" || ng "W09" "$o2"
mkdir -p "$ROOT/fresh"; printf '%s\n| 2026-09-08 | x.c:1-2 | f | ヒープ操作 | trace | q | dunno |  |  |\n' "$H" > "$ROOT/fresh/log.md"
mkdir "$TMP/r2"; mv "$ROOT/worker" "$ROOT/api" "$TMP/r2/"
sh scripts/weak.sh --root "$ROOT" --repo fresh --today 2026-09-08 >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 1 ] && grep -q 'ズレの記録がまだ無い' "$TMP/e" && ok "W10 ズレが 1 件も無ければ exit 1 と案内" || ng "W10" "rc=$rc $(cat "$TMP/e")"
mv "$TMP/r2/worker" "$TMP/r2/api" "$ROOT/"; rm -rf "$ROOT/fresh"
after=$(sh scripts/map.sh --root "$ROOT" --today 2026-09-08); [ "$before" = "$after" ] && ok "W11 weak.sh は値も状態も変えない" || ng "W11 state changed"
oe=$(HIDANE_LANG=en $W); { echo "$oe" | sed -n 1p | grep -q '^From the map: not understood 停止フラグの伝搬 → starting there. Fuzzy 境界条件. Used 4 past misses$' && echo "$oe" | grep -q '^Skipped: ヒープ操作$' && echo "$oe" | grep -q '3 misses)$'; } && ok "W12 en" || ng "W12 en" "$oe"

echo; echo "PASS $pass / FAIL $fail"; [ $fail -eq 0 ]
