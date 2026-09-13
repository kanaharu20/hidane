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
  /hidane --weak             弱い所を 1 枚に。ズレを型にまとめ、鎖のどの段で躓いているかを自分のコードの行で示す
  /hidane --map              概念ごとの値と状態の表
  /hidane --vault            地図を作り直して Obsidian で開く
  /hidane --lint             似た概念名を統合する(3 日に一度は自動)
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
  /hidane --weak             weak spots on one page: misses folded into a pattern, the chain, the step you stumble on, in your own lines
  /hidane --map              the table of concepts, values and states
  /hidane --vault            rebuild the map and open it in Obsidian
  /hidane --lint             merge concept names that mean the same (also automatic every 3 days)
  /hidane --update           latest version, records migrated
  /hidane --help, -h         this

  Answering: in your own words, concretely. "I don't know" is an answer.
  Results:   hit / partial (keys k / n, lines not mentioned) / miss. No scores. Explanations change no color.
  Records:   $ROOT   Map: ${HIDANE_VAULT:-$HOME/Documents/hidane}
  More:      docs/GUIDE.md
EOT
fi
