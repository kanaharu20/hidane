#!/bin/sh
# hidane help.sh — /hidane の使い方を固定の文で出す(Claude に組み立てさせない)。
# 使い方: help.sh [--root DIR]
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"
[ "${1:-}" = "--root" ] && ROOT="$2"
. "$HERE/lang.sh"
v=$(cat "$HERE/../VERSION" 2>/dev/null || echo "?")
if [ "$LANGX" = "ja" ]; then cat <<EOT
hidane $v — 自分のコードのどこを理解していて、どこをまだ確かめていないかを地図にする

  /hidane                    一問。まだ問うていない関数から 1 つ選び、答えを記録する
  /hidane <聞きたいこと>      解説。地図を先に読み、理解している概念は飛ばし、間違えた所から話す
                             例: /hidane printf って何？  /hidane 自分の弱い所は  /hidane さっきの問いで触れていなかった所
  /hidane --weak             弱い所を 1 枚に。ズレを型にまとめ、流れのどの段で躓いているかを自分のコードの行で示す
  /hidane --focus [概念]     集中。1 回の呼び出しで、1 つの概念の関数を 1 問ずつ 3 問出して決着をつける(省略なら順位最上位の概念)
  /hidane --dispute <番号> <理由>  直前の問いの鍵に異議を残す(値は変わらない。次にその関数を問うとき鍵を作る側に見せる)
  /hidane --map              概念ごとの値と状態の表
  /hidane --vault            地図を作り直して Obsidian で開く
  /hidane --lint             似た概念名を統合する(3 日に一度は自動)
  /hidane --init            今いるリポジトリを登録する(hook を置き、全関数に背景で概念を付ける。--no-tag で hook だけ)
  /hidane --tag              まだ地図に無い関数に概念を付ける(背景で。commit 前でも。commit 時は hook が自動)
  /hidane --update           最新版にして記録を移行する
  /hidane --help, -h         これ

  答え方: 自分の言葉で、具体的に。「分からない」も答え。
  結果:   当たり / 部分(鍵 k / n、触れていない行) / ズレ。点数は出ない。解説を読んでも色は変わらない。
  記録:   $ROOT   地図: ${HIDANE_VAULT:-$HOME/Documents/hidane}
  詳しく: docs/GUIDE.ja.md
EOT
else cat <<EOT
hidane $v — a map of which parts of your code you understand and which you have never checked

  /hidane                    one question about a function not yet asked; the answer is recorded
  /hidane <anything>         an explanation at your level: the map is read first, understood concepts are skipped
                             e.g. /hidane what is printf?   /hidane where am I weak   /hidane the part I missed in the last question
  /hidane --weak             weak spots on one page: misses folded into a pattern, the flow, the step you stumble on, in your own lines
  /hidane --focus [concept]  focus: 3 questions in one invocation, one at a time, on one concept to settle it (default: the top-ranked concept)
  /hidane --dispute <n> <reason>  dispute a key of the last question (value unchanged; shown when keys are next made for that function)
  /hidane --map              the table of concepts, values and states
  /hidane --vault            rebuild the map and open it in Obsidian
  /hidane --lint             merge concept names that mean the same (also automatic every 3 days)
  /hidane --init             register this repository (installs the hook, tags every function in the background; --no-tag for the hook only)
  /hidane --tag              tag functions not on the map yet, in the background (uncommitted too; the hook does it at commit)
  /hidane --update           latest version, records migrated
  /hidane --help, -h         this

  Answering: in your own words, concretely. "I don't know" is an answer.
  Results:   hit / partial (keys k / n, lines not mentioned) / miss. No scores. Explanations change no color.
  Records:   $ROOT   Map: ${HIDANE_VAULT:-$HOME/Documents/hidane}
  More:      docs/GUIDE.md
EOT
fi
