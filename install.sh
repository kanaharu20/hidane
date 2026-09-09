#!/bin/sh
# hidane install.sh — 今いる git リポジトリに post-commit hook を置く / 外す。
#   install.sh --hook        .git/hooks/post-commit を置く(他人の hook があれば触らない)
#   install.sh --unhook      hidane の hook なら消す
#   install.sh --skill       ~/.claude/skills/hidane に SKILL.md と scripts を配置(コピー)
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
case "${1:-}" in
  --skill)
    dst="${HIDANE_SKILL_DIR:-$HOME/.claude/skills/hidane}"
    mkdir -p "$dst/scripts" "$dst/hooks"
    cp "$HERE/SKILL.md" "$dst/" && cp "$HERE/scripts/"*.sh "$HERE/scripts/gitattributes" "$dst/scripts/" && cp "$HERE/hooks/post-commit" "$dst/hooks/" && cp "$HERE/install.sh" "$dst/"
    echo "install.sh: 配置しました: $dst"; exit 0 ;;
esac
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "install.sh: git リポジトリの中で実行してください" >&2; exit 3; }
hook="$top/.git/hooks/post-commit"
case "${1:-}" in
  --hook)
    if [ -f "$hook" ] && ! grep -q '^# hidane-hook' "$hook"; then
      echo "install.sh: 別の post-commit hook があるので触りません: $hook" >&2; exit 5
    fi
    sed "s|__HIDANE_HOME__|$HERE|" "$HERE/hooks/post-commit" > "$hook" && chmod +x "$hook"
    echo "install.sh: 置きました: $hook"
    echo "  最初に一度、全体に霧を敷く: sh $HERE/scripts/tag.sh --all" ;;
  --unhook)
    if [ -f "$hook" ] && grep -q '^# hidane-hook' "$hook"; then rm -f "$hook"; echo "install.sh: 外しました"; else echo "install.sh: hidane の hook は無い"; fi ;;
  *) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
