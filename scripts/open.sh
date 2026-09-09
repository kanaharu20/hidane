#!/bin/sh
# hidane open.sh — vault を作り直してから Obsidian で開く。
# 使い方: open.sh [--root DIR] [--vault DIR] [--print]
#   --print  開かずに URL だけ出す
# 環境変数: HIDANE_OPEN(open コマンドの差し替え。検査用)
# Obsidian に一度「Open folder as vault」で登録してある vault にだけ飛べる(初回は手で開く)。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; VAULT="${HIDANE_VAULT:-$HOME/Documents/hidane}"; PRINT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --vault) VAULT="$2"; shift 2 ;;
    --print) PRINT=1; shift ;;
    --help|-h) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "open.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done
sh "$HERE/pages.sh" --root "$ROOT" --vault "$VAULT" >/dev/null
# URL エンコード(空白と日本語を含むパスに備える)
enc=$(printf '%s' "$VAULT" | od -An -tx1 -v | tr -d ' \n' | sed 's/../%&/g' | tr 'a-f' 'A-F')
url="obsidian://open?path=$enc"
if [ -n "$PRINT" ]; then echo "$url"; exit 0; fi
"${HIDANE_OPEN:-open}" "$url"
echo "open.sh: Obsidian で開きました: $VAULT"
