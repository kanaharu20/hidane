#!/bin/sh
# map.sh の L0 検査。LLM を使わない。数秒で終わる。
# 方針: 正解と一致するだけでなく、入力を変えたら出力が変わることも確かめる(空振り防止)。
set -u
cd "$(dirname "$0")/.." || exit 2
MAP="sh scripts/map.sh"
FX=tests/fixtures
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "PASS $1"; }
ng()   { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }
row()  { grep "^| $2 |" "$1" || echo "(行なし: $2)"; }

# T01 手タグ 15 件と一致する(正解ファイル)
$MAP --root $FX --today 2026-09-08 > "$TMP/out.md" 2>"$TMP/err"
if diff -q tests/expected_map.md "$TMP/out.md" >/dev/null; then ok "T01 手タグ 15 件の値と状態が正解と一致"; else ng "T01 正解と不一致" "$(diff tests/expected_map.md "$TMP/out.md" | head -5)"; fi

# T02 読んだ行 = 使えた行 = 15
grep -q '読んだ行 15 / 使えた行 15' "$TMP/out.md" && ok "T02 読んだ行 15 / 使えた行 15" || ng "T02 行数" "$(tail -1 "$TMP/out.md")"

# T03 変異: ズレ 1 行を当たりに変えると 停止フラグの伝搬 が -4 非理解 → -2 曖昧 になる
mkdir -p "$TMP/m1/worker"; sed 's/| 停止後のログ抑止 | ズレ |/| 停止後のログ抑止 | 当たり |/' $FX/worker/log.md > "$TMP/m1/worker/log.md"
r=$($MAP --root "$TMP/m1" --today 2026-09-08 | row /dev/stdin 停止フラグの伝搬)
echo "$r" | grep -q '| -2 | 2 | .* | 曖昧 |' && ok "T03 変異(ズレ→当たり)で値と状態が動く" || ng "T03 変異が効かない" "$r"

# T04 忘却: 基準日を 60 日後にすると 停止フラグの伝搬 は値 -4 のまま 曖昧 に落ちる
r=$($MAP --root $FX --today 2026-11-07 | row /dev/stdin 停止フラグの伝搬)
echo "$r" | grep -q '| -4 | 2 | .* | 曖昧 |' && ok "T04 30 日超で 非理解 → 曖昧(値は変わらない)" || ng "T04 忘却" "$r"

# T05 忘却の境目: ちょうど 30 日は新鮮、31 日は古い
r30=$($MAP --root $FX --today 2026-10-06 | row /dev/stdin 停止フラグの伝搬)
r31=$($MAP --root $FX --today 2026-10-07 | row /dev/stdin 停止フラグの伝搬)
{ echo "$r30" | grep -q '非理解' && echo "$r31" | grep -q '曖昧'; } && ok "T05 鮮度の境目は 30 日(30 日は新鮮、31 日は古い)" || ng "T05 境目" "$r30 / $r31"

# T06 上限: 追う型の外れを 8 回並べても値は -6 で止まる
mkdir -p "$TMP/cap/x"; { echo '| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | ズレ | 備考 |'; echo '|---|---|---|---|---|---|---|---|---|'
  i=1; while [ $i -le 8 ]; do echo "| 2026-09-0$((i%9)) | f.c:1-2 | f | 上限試験 | 追う | q | 外れ |  |  |"; i=$((i+1)); done; } > "$TMP/cap/x/log.md"
r=$($MAP --root "$TMP/cap" --today 2026-09-08 | row /dev/stdin 上限試験)
echo "$r" | grep -q '| -6 | 8 |' && ok "T06 8 回外しても -6 で止まる" || ng "T06 上限" "$r"

# T07 歩きながら止める: -6 の後に 要約 当たり(+3)で -3 になる(末尾でまとめて止めると -5 になってしまう)
{ echo "| 2026-09-08 | f.c:1-2 | f | 上限試験 | 要約 | q | 当たり |  |  |"; } >> "$TMP/cap/x/log.md"
r=$($MAP --root "$TMP/cap" --today 2026-09-08 | row /dev/stdin 上限試験)
echo "$r" | grep -q '| -3 | 9 |' && ok "T07 上限は 1 行ごとに適用(-6 → +3 で -3)" || ng "T07 歩き止め" "$r"

# T08 未回答だけの概念は 未出題、証拠 0、最終 -
r=$(row "$TMP/out.md" 入力検証)
echo "$r" | grep -q '| +0 | 0 | - | 未出題 |' && ok "T08 未回答だけの概念は未出題" || ng "T08 未出題" "$r"

# T09 読めない行(未知の型)は stderr に出て、使えた行から外れる
mkdir -p "$TMP/bad/x"; { head -2 "$TMP/cap/x/log.md"; echo "| 2026-09-08 | f.c:1-2 | f | 何か | 記述 | q | 当たり |  |  |"; echo "| 2026-09-08 | f.c:1-2 | f | 何か | 追う | q | 当たり |  |  |"; } > "$TMP/bad/x/log.md"
$MAP --root "$TMP/bad" --today 2026-09-08 > "$TMP/bad.out" 2> "$TMP/bad.err"
{ grep -q '読めない行' "$TMP/bad.err" && grep -q '読んだ行 2 / 使えた行 1' "$TMP/bad.out"; } && ok "T09 読めない行は数に出て、黙って消えない" || ng "T09 読めない行" "$(cat "$TMP/bad.err" "$TMP/bad.out" | tail -3)"

# T10 定数は環境変数で変わる: 閾値 3 なら 境界条件(-3)が 非理解 になる
r=$(HIDANE_THRESHOLD=3 $MAP --root $FX --today 2026-09-08 | row /dev/stdin 境界条件)
echo "$r" | grep -q '| -3 | 3 | .* | 非理解 |' && ok "T10 閾値を 3 にすると 境界条件 が非理解" || ng "T10 定数上書き" "$r"

# T11 repo をまたぐ概念は repo 列に両方出る
r=$(row "$TMP/out.md" 境界条件)
echo "$r" | grep -q 'api,worker' && ok "T11 境界条件 は api と worker の両方から引かれている" || ng "T11 またぎ" "$r"

# T12 log.md が無いと exit 1
$MAP --root "$TMP/none" >/dev/null 2>&1; [ $? -eq 1 ] && ok "T12 log.md も functions.md も無しは exit 1" || ng "T12 exit code"

# T13 functions.md にだけある概念は 未出題、repo 列に出る、値 0 証拠 0
r=$(row "$TMP/out.md" 起動と引数処理)
echo "$r" | grep -q '| +0 | 0 | - | 未出題 | worker |' && ok "T13 functions.md だけの概念は未出題" || ng "T13 functions.md" "$r"

echo; echo "PASS $pass / FAIL $fail"
[ $fail -eq 0 ]
