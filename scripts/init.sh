#!/bin/sh
# hidane init.sh — 今いる git リポジトリを hidane に登録する(/hidane --init)。
#   1. post-commit hook を置く(install.sh --hook と同じ。他人の hook があれば触らずに知らせる)
#   2. 作業ツリーの全関数に概念を付ける(tag.sh --all --bg。背景。commit が無くても動く)
# 使い方: init.sh [--root DIR] [--no-tag]
#   --no-tag  hook だけ置き、概念付けはしない(あとで /hidane --tag)
# install.sh の場所: <skill>/HOME(install.sh --skill が書く)。無ければ scripts/ の 1 つ上(git checkout の中で使うとき)
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"; NOTAG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --no-tag) NOTAG=1; shift ;;
    --help|-h) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "init.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done
. "$HERE/lang.sh"
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "init.sh: $(L r_norepo)" >&2; exit 3; }
home=$(cat "$HERE/../HOME" 2>/dev/null || true)
[ -n "$home" ] && [ -f "$home/install.sh" ] || home="$HERE/.."
[ -f "$home/install.sh" ] || { echo "init.sh: $(L i_noinstall)" >&2; exit 4; }
repo=$(hidane_repo_key "$top")
# install.sh は言語を <root>/config から読む。無ければ今の言語を書いておく
if ! grep -q '^lang=' "$ROOT/config" 2>/dev/null; then mkdir -p "$ROOT"; printf 'lang=%s\n' "$LANGX" >> "$ROOT/config"; fi
printf "$(L i_start)\n" "$repo" "$top"
HIDANE_ROOT="$ROOT" sh "$home/install.sh" --hook || true   # 他人の hook のときは exit 5。知らせて続ける
mkdir -p "$ROOT/$repo"; printf '%s\n' "$top" > "$ROOT/$repo/path"
if [ -z "$NOTAG" ]; then
  HIDANE_ROOT="$ROOT" sh "$HERE/tag.sh" --root "$ROOT" --repo "$top" --all --bg || true
fi
printf "$(L i_done)\n" "$repo" "$ROOT/$repo"
