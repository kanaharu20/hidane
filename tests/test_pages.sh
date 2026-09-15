#!/bin/sh
# pages.sh の L0 検査。
set -u
cd "$(dirname "$0")/.." || exit 2
export HIDANE_LANG=ja
FX=tests/fixtures
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
V="$TMP/vault"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }

sh scripts/pages.sh --root $FX --vault "$V" --today 2026-09-08 > "$TMP/out" 2>"$TMP/err" || ng "P00 pages.sh が失敗" "$(cat "$TMP/err")"

# P01 概念ページ数 = map の概念数(12)、repo ページ 2
nc=$(ls "$V/concepts" | wc -l | tr -d ' '); nr=$(ls "$V/repos" | wc -l | tr -d ' ')
[ "$nc" = 12 ] && [ "$nr" = 2 ] && ok "P01 概念 12 / repo 2 ページ" || ng "P01 ページ数" "concepts=$nc repos=$nr"

# P02 frontmatter が map と一致(境界条件: 曖昧 -3 3 2026-09-07 api, worker)
p="$V/concepts/境界条件.md"
{ grep -q '^state: fuzzy$' "$p" && grep -q '^value: -3$' "$p" && grep -q '^evidence: 3$' "$p" && grep -q '^last: 2026-09-07$' "$p" && grep -q '^repos: \[api, worker\]$' "$p"; } \
  && ok "P02 境界条件 の frontmatter が map と一致" || ng "P02 frontmatter" "$(sed -n '1,8p' "$p")"

# P03 共起の関連リンク(境界条件 ↔ 資源獲得の順序、ヒープ操作)、自分自身は無い
{ grep -q '^- \[\[資源獲得の順序\]\]$' "$p" && grep -q '^- \[\[ヒープ操作\]\]$' "$p" && ! grep -q '^- \[\[境界条件\]\]$' "$p"; } \
  && ok "P03 共起した概念が 関連 に出る(自分は出ない)" || ng "P03 関連" "$(grep -A4 '## 関連' "$p")"

# P04 典型的なズレ に log の ズレ列が入る
grep -q '^- 停止後も1行出る(worker, 2026-09-05)$' "$V/concepts/停止フラグの伝搬.md" && ok "P04 ズレの中身が 典型的なズレ に入る" || ng "P04 ズレ" "$(grep -A3 'ズレ' "$V/concepts/停止フラグの伝搬.md")"

# P05 未出題の関数(functions.md)が未出題の概念ページに出て、記録は無い
p2="$V/concepts/起動と引数処理.md"
{ grep -q '^state: unasked$' "$p2" && grep -q '^- 2026-09-08 \[\[worker\]\] `src/main.c:74-90` main$' "$p2" && ! grep -q '## 記録' "$p2"; } \
  && ok "P05 functions.md の関数が 未出題 のページに 未出題 として出る" || ng "P05 未出題" "$(cat "$p2")"

# P06 入力検証 は log(未回答)と functions の両方を持つ: 記録 と 未出題 の両節がある
p3="$V/concepts/入力検証.md"
{ grep -q '## 記録' "$p3" && grep -q '## 未出題の関数' "$p3" && grep -q 'is_valid_num' "$p3"; } && ok "P06 記録と未出題が同じページに並ぶ" || ng "P06 両節" "$(cat "$p3")"

# P07 冪等: もう一度書いても差分なし
cp -R "$V" "$TMP/v1"; sh scripts/pages.sh --root $FX --vault "$V" --today 2026-09-08 >/dev/null 2>&1
diff -r "$TMP/v1" "$V" >/dev/null && ok "P07 2 回書いても同じ" || ng "P07 冪等" "$(diff -r "$TMP/v1" "$V" | head -3)"

# P08 掃除: 余計な概念ページは消える、graph.json は残る
echo x > "$V/concepts/古い概念.md"; echo '{"mine":1}' > "$V/.obsidian/graph.json"
sh scripts/pages.sh --root $FX --vault "$V" --today 2026-09-08 >/dev/null 2>&1
{ [ ! -f "$V/concepts/古い概念.md" ] && grep -q '"mine"' "$V/.obsidian/graph.json"; } && ok "P08 無くなった概念のページは消え、graph.json は上書きしない" || ng "P08 掃除"

# P09 初回の graph.json に 4 状態の色がある
rm -rf "$TMP/v2"; sh scripts/pages.sh --root $FX --vault "$TMP/v2" --today 2026-09-08 >/dev/null 2>&1
n=$(grep -c '\[tone:v_' "$TMP/v2/.obsidian/graph.json"); { [ "$n" = 13 ] && grep -q '"\[tone:off\]"' "$TMP/v2/.obsidian/graph.json"; } && ok "P09 graph.json に値 13 段の色と未出題の灰" || ng "P09 graph.json" "tone queries=$n"
{ grep -q '^tone: v_m3$' "$TMP/v2/concepts/境界条件.md" && grep -q '^tone: off$' "$TMP/v2/concepts/入力検証.md" && grep -q '^tone: tent$' "$TMP/v2/concepts/起動と引数処理.md" && grep -q '| \[\[起動と引数処理\]\] | 未出題(仮) |' "$TMP/v2/repos/worker.md"; } && ok "P09b tone は値から(-3 → v_m3、未出題 → off、関数 1 つの未出題 → tent、表に 未出題(仮))" || ng "P09b tone" "$(grep tone "$TMP/v2/concepts/境界条件.md" "$TMP/v2/concepts/起動と引数処理.md")"

# P10 repo ページに概念と状態が重複なしで並ぶ
r="$V/repos/worker.md"
{ [ "$(grep -c '^| \[\[' "$r")" = 12 ] && grep -q '| \[\[停止フラグの伝搬\]\] | 非理解 | -4 |' "$r"; } && ok "P10 repo ページに 12 概念、重複なし" || ng "P10 repo" "$(grep -c '^| \[\[' "$r") rows"

# P11 index.md は map.sh の表と同じ
sed -n '/^| 概念 | 値/,$p' "$V/index.md" > "$TMP/idx"; diff -q tests/expected_map.md "$TMP/idx" >/dev/null && ok "P11 index.md の表 = map.sh の表(先頭に全体と最近の解説)" || ng "P11 index" "$(diff tests/expected_map.md "$TMP/idx" | head -3)"
{ grep -q '^## 全体$' "$V/index.md" && grep -q '^理解 0 / 曖昧 9 / 非理解 1 / 未出題 2$' "$V/index.md" && grep -q '^答えた問い 15、最後に答えた日 2026-09-08$' "$V/index.md" && grep -q '^## 最近求めた解説$' "$V/index.md" && grep -q '(まだ無い)' "$V/index.md"; } && ok "P15 index.md の先頭に全体の段階と最近の解説(無ければ「まだ無い」)" || ng "P15 index header" "$(head -12 "$V/index.md")"

# P12 概念名の / はファイル名で ／ になり、リンクも同じ
mkdir -p "$TMP/sl/x"; { head -2 $FX/api/log.md | tail -1; echo '|---|---|---|---|---|---|---|---|---|'; echo '| 2026-09-08 | a.c:1-2 | f | 入出力/バッファ, 境界条件 | trace | q | hit |  |  |'; } > "$TMP/sl/x/log.md"
sh scripts/pages.sh --root "$TMP/sl" --vault "$TMP/slv" --today 2026-09-08 >/dev/null 2>&1
{ [ -f "$TMP/slv/concepts/入出力／バッファ.md" ] && grep -q '\[\[入出力／バッファ\]\]' "$TMP/slv/concepts/境界条件.md"; } && ok "P12 概念名の / は ／ に" || ng "P12 スラッシュ" "$(ls "$TMP/slv/concepts")"

# P13 旧方式(state ごとの色)の graph.json は丸ごと作り直す(.bak を残す)。新方式のものは触らない
rm -rf "$TMP/v4"; sh scripts/pages.sh --root $FX --vault "$TMP/v4" --today 2026-09-08 >/dev/null 2>&1
printf '{"colorGroups":[{"query":"[state:霧]","color":{"a":1,"rgb": 10395294 }},{"query":"[state:known] -[state:unknown]","color":{"a":1,"rgb": 123 }}]}\n' > "$TMP/v4/.obsidian/graph.json"
sh scripts/pages.sh --root $FX --vault "$TMP/v4" --today 2026-09-08 >/dev/null 2>&1
{ grep -q '\[tone:v_p6\]' "$TMP/v4/.obsidian/graph.json" && ! grep -q 'state:' "$TMP/v4/.obsidian/graph.json" && grep -q 'state:霧' "$TMP/v4/.obsidian/graph.json.bak"; } \
  && ok "P13 旧方式の graph.json は作り直され、.bak が残る" || ng "P13 移行" "$(cat "$TMP/v4/.obsidian/graph.json")"
# P14 新方式で利用者が色を変えたものは触らない
sed 's/"rgb": 1566369/"rgb": 123/' "$TMP/v4/.obsidian/graph.json" > "$TMP/v4/g.tmp" && mv "$TMP/v4/g.tmp" "$TMP/v4/.obsidian/graph.json"
sh scripts/pages.sh --root $FX --vault "$TMP/v4" --today 2026-09-08 >/dev/null 2>&1
grep -q '"rgb": 123' "$TMP/v4/.obsidian/graph.json" && ok "P14 新方式の graph.json は上書きしない(利用者の色が残る)" || ng "P14 keep" "$(grep 123 "$TMP/v4/.obsidian/graph.json")"

# O01 open.sh: vault を作り直し、URL を出す。O02 open コマンドの差し替えで開く
rm -rf "$TMP/v3"; u=$(sh scripts/open.sh --root $FX --vault "$TMP/v3" --print)
{ echo "$u" | grep -q '^obsidian://open?path=%2F' && ! echo "$u" | grep -q ' ' && [ -f "$TMP/v3/index.md" ]; } && ok "O01 open.sh --print は vault を作って URL を出す" || ng "O01 open" "$u"
mkdir -p "$TMP/a b"; u=$(HIDANE_ROOT=$FX sh scripts/open.sh --vault "$TMP/a b/日本" --print)
[ "$u" = "obsidian://open?path=$(printf '%s' "$TMP" | od -An -tx1 -v | tr -d ' \n' | sed 's/../%&/g' | tr 'a-f' 'A-F')%2F%61%20%62%2F%E6%97%A5%E6%9C%AC" ] && ok "O03 空白と日本語のパスが %XX に符号化される(既知の答えと一致)" || ng "O03 encode" "$u"
o=$(HIDANE_OPEN=echo sh scripts/open.sh --root $FX --vault "$TMP/v3"); echo "$o" | grep -q '^obsidian://open?path=' && echo "$o" | grep -q 'Obsidian で開きました' && ok "O02 open コマンドで URL を開く" || ng "O02" "$o"

# P15 作業ツリーに無い関数は「未出題の関数」に (消えた) の印、repo ページに件数。path が無ければ確かめない
R5="$TMP/r5"; mkdir -p "$R5/w" "$TMP/wt5/src"; printf 'int alive_fn(void)\n{\n\treturn 1;\n}\n' > "$TMP/wt5/src/a.c"
printf '| 日付 | 場所 | 関数 | 概念 | commit | 備考 |\n|---|---|---|---|---|---|\n| 2026-09-08 | src/a.c:1-4 | alive_fn | 境界条件 | abc |  |\n| 2026-09-08 | src/b.c:1-4 | gone_fn | 境界条件 | abc |  |\n' > "$R5/w/functions.md"
printf '%s\n' "$TMP/wt5" > "$R5/w/path"
sh scripts/pages.sh --root "$R5" --vault "$TMP/v5" --today 2026-09-08 >/dev/null 2>&1
{ grep -q '`src/b.c:1-4` gone_fn (消えた)$' "$TMP/v5/concepts/境界条件.md" && grep -q '`src/a.c:1-4` alive_fn$' "$TMP/v5/concepts/境界条件.md" && grep -q '^作業ツリーに無い関数 1 件には (消えた) と印を付けた' "$TMP/v5/repos/w.md"; } \
  && ok "P15 消えた関数に印、repo ページに件数" || ng "P15 gone" "$(cat "$TMP/v5/concepts/境界条件.md" "$TMP/v5/repos/w.md")"
rm "$R5/w/path"; sh scripts/pages.sh --root "$R5" --vault "$TMP/v5" --today 2026-09-08 >/dev/null 2>&1
! grep -q '消えた' "$TMP/v5/concepts/境界条件.md" && ok "P15b repo の場所が分からなければ印を付けない" || ng "P15b" "$(cat "$TMP/v5/concepts/境界条件.md")"
printf '%s\n' "$TMP/no-such-dir" > "$R5/w/path"; sh scripts/pages.sh --root "$R5" --vault "$TMP/v5" --today 2026-09-08 >/dev/null 2>&1
{ grep -q '^リポジトリが .*no-such-dir に無い' "$TMP/v5/repos/w.md" && [ "$(grep -c '(消えた)' "$TMP/v5/concepts/境界条件.md")" = 2 ]; } && ok "P16 repo の場所が消えていれば全部 (消えた) と repo ページに案内" || ng "P16 lost" "$(cat "$TMP/v5/repos/w.md")"

# P17 仮(tent)の色が無い graph.json には足す(.bak を残す)。graph.json は毎回作り直さない
sed -i.orig '/tone:tent/d' "$TMP/v2/.obsidian/graph.json"; sh scripts/pages.sh --root $FX --vault "$TMP/v2" --today 2026-09-08 >/dev/null 2>&1
{ grep -q '"\[tone:tent\]"' "$TMP/v2/.obsidian/graph.json" && [ -f "$TMP/v2/.obsidian/graph.json.bak" ] && [ "$(grep -c '\[tone:' "$TMP/v2/.obsidian/graph.json")" = 15 ]; } && ok "P17 仮の色が無い graph.json に足す(15 群)" || ng "P17 tent upgrade" "$(grep tone "$TMP/v2/.obsidian/graph.json")"
echo; echo "PASS $pass / FAIL $fail"
[ $fail -eq 0 ]
