#!/bin/sh
set -u
cd "$(dirname "$0")/.." || exit 2
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/root"; mkdir -p "$ROOT/worker" "$ROOT/api"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }
H='| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | ズレ | 備考 |
|---|---|---|---|---|---|---|---|---|'
F='| 日付 | 場所 | 関数 | 概念 | commit | 備考 |
|---|---|---|---|---|---|'
# worker: 停止フラグの伝搬 = -4 非理解(ズレ 2 回)、ヒープ操作 = +6 理解、境界条件 = -1 曖昧
cat > "$ROOT/worker/log.md" <<L
$H
| 2026-09-05 | src/log.c:20-29 | log_line | 停止フラグの伝搬 | 追う | q | ズレ | 停止後も 1 行出る |  |
| 2026-09-06 | src/stop.c:3-41 | request_stop | 停止フラグの伝搬 | 要約 | q | ズレ | wake の書き忘れ |  |
| 2026-09-07 | src/heap.c:3-16 | heap_push | ヒープ操作 | 要約 | q | 当たり |  |  |
| 2026-09-07 | src/heap.c:20-30 | heap_pop | ヒープ操作 | 要約 | q | 当たり |  |  |
| 2026-09-07 | src/a.c:1-5 | a | 境界条件 | 追う | q | ズレ | n=1 |  |
L
cat > "$ROOT/worker/functions.md" <<L
$F
| 2026-09-08 | src/heap.c:40-50 | heap_peek | ヒープ操作 | abc |  |
| 2026-09-08 | src/main.c:1-9 | main | 起動処理 | abc | 新 |
| 2026-09-08 | src/mon.c:1-20 | monitor | 停止フラグの伝搬, 境界条件 | abc |  |
| 2026-09-08 | src/b.c:1-5 | b | 境界条件 | abc |  |
L
cat > "$ROOT/api/functions.md" <<L
$F
| 2026-09-08 | src/server.py:10-30 | shutdown | 停止フラグの伝搬 | def |  |
| 2026-09-08 | src/chunk.py:1-9 | split | 分割 | def | 新 |
L
N="sh scripts/next.sh --root $ROOT --today 2026-09-08"

o=$($N --repo worker); echo "$o" | grep -q '^場所: src/mon.c:1-20$' && echo "$o" | grep -q '^代表: 停止フラグの伝搬(非理解、値 -4)$' && ok "N01 非理解の概念に付いた未出題の関数が先" || ng "N01" "$o"
echo "$o" | grep -q '^- 停止後も 1 行出る(worker, 2026-09-05)$' && echo "$o" | grep -q '^型: 追う(境界・変異)$' && ok "N02 過去のズレが出て、型が 追う(境界・変異) に決まる" || ng "N02 ズレ" "$o"
o=$($N --repo api); echo "$o" | grep -q '^場所: src/server.py:10-30$' && echo "$o" | grep -q '非理解' && ok "N03 repo をまたぐ: worker で非理解の概念が api の関数を先に出す" || ng "N03 またぎ" "$o"
o=$($N --repo worker -n 10)
{ echo "$o" | sed -n 3p | grep -q 'src/mon.c' && echo "$o" | sed -n 4p | grep -q 'src/b.c' && echo "$o" | sed -n 5p | grep -q 'src/main.c' && ! echo "$o" | grep -q heap_peek; } \
  && ok "N04 順: 非理解 > 曖昧 > 未出題。理解だけの関数(heap_peek)は出ない" || ng "N04 順" "$o"
echo "$o" | grep -q '^| 3 | src/main.c:1-9 | main | 起動処理 | 未出題 | +0 |' && ok "N05 未出題の関数は値 0 で 3 番目" || ng "N05 未出題" "$o"
pf="$ROOT/worker/pending"; [ -f "$pf" ] && [ "$(cat "$pf")" = "$(printf 'src/mon.c:1-20\tmonitor\t停止フラグの伝搬, 境界条件\t追う(境界・変異)')" ] && ok "N10 決定が pending に書かれる" || ng "N10 pending" "$(cat "$pf" 2>&1)"
o1=$($N --repo worker); echo "$o1" | grep -q '^問いの形: ' && echo "$o1" | grep -q '「なぜ」「何が必要か」は問わない' && ok "N11 問いの形の制約が出る" || ng "N11 問いの形" "$o1"
o2=$($N --repo api); grep -q '^src/server.py' "$ROOT/api/pending" && ok "N12 repo ごとに別の pending" || ng "N12"
# 問うた場所は除かれる
printf '| 2026-09-08 | src/mon.c:1-20 | monitor | 停止フラグの伝搬, 境界条件 | 追う | q | 分からない |  |  |\n' >> "$ROOT/worker/log.md"
o=$($N --repo worker); echo "$o" | grep -q '^場所: src/b.c:1-5$' && ok "N06 問うた関数は候補から外れ、同じ概念の別の関数へ" || ng "N06 除外" "$o"
mkdir -p "$ROOT/empty"; $N --repo empty >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 1 ] && grep -q '記録が無い' "$TMP/e" && ok "N07 記録の無い repo は exit 1 と案内" || ng "N07 空" "rc=$rc"
mkdir -p "$ROOT/done"; printf '%s\n| 2026-09-08 | x.c:1-2 | f | ヒープ操作 | 追う | q | 当たり |  |  |\n' "$H" > "$ROOT/done/log.md"
$N --repo done >/dev/null 2>"$TMP/e"; rc=$?; [ $rc = 1 ] && grep -q '候補なし' "$TMP/e" && ok "N08 全部問うた repo は exit 1「候補なし」" || ng "N08 候補なし" "rc=$rc $(cat "$TMP/e")"
# N09 候補が多く、順がばらばらでも値の昇順に並ぶ(並べ替えの入れ替えを必ず起こす)
mkdir -p "$ROOT/many"; { echo "$H"; i=1; while [ $i -le 6 ]; do
  # 概念 c<i> の値を -i にする(追う 外れ i 回)
  j=1; while [ $j -le $i ]; do echo "| 2026-09-0$j | old$i.c:1-2 | o$i | c$i | 追う | q | 外れ |  |  |"; j=$((j+1)); done; i=$((i+1)); done; } > "$ROOT/many/log.md"
{ echo "$F"; for i in 2 5 1 6 3 4; do echo "| 2026-09-08 | new$i.c:1-2 | n$i | c$i | x |  |"; done; } > "$ROOT/many/functions.md"
o=$($N --repo many -n 6 2>&1); got=$(echo "$o" | sed -n '3,8p' | awk -F'|' '{ gsub(/ /,"",$3); printf("%s ", $3) }')
[ "$got" = "new6.c:1-2 new5.c:1-2 new4.c:1-2 new3.c:1-2 new2.c:1-2 new1.c:1-2 " ] && ok "N09 6 候補が値の昇順(-6 → -1)に並ぶ" || ng "N09 並べ替え" "$got / $o"

echo; echo "PASS $pass / FAIL $fail"; [ $fail -eq 0 ]
