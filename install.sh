#!/bin/sh
# hidane install.sh — 今いる git リポジトリに post-commit hook を置く / 外す。
#   install.sh --hook        .git/hooks/post-commit を置く(他人の hook があれば触らない)
#   install.sh --unhook      hidane の hook なら消す
#   install.sh --skill [--lang en|ja]   ~/.claude/skills/hidane に SKILL.md と scripts を配置(コピー)。
#                                        --lang で表示言語を決めて <root>/config に書く(省略時は端末で聞く。既定 en)
#   install.sh --lang en|ja             言語だけ変える
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"
cmd="${1:-}"; lang=""
[ "${2:-}" = "--lang" ] && lang="${3:-}"
[ "$cmd" = "--lang" ] && { lang="${2:-}"; cmd="--lang-only"; }
set_lang() {
  case "$1" in en|ja) ;; *) echo "install.sh: --lang en | ja" >&2; exit 2 ;; esac
  mkdir -p "$ROOT"
  if [ -f "$ROOT/config" ] && grep -q '^lang=' "$ROOT/config"; then sed -i '' "s/^lang=.*/lang=$1/" "$ROOT/config"; else echo "lang=$1" >> "$ROOT/config"; fi
  echo "install.sh: lang=$1 → $ROOT/config"
}
case "$cmd" in
  --lang-only) set_lang "$lang"; exit 0 ;;
  --skill)
    if [ -z "$lang" ]; then
      if [ -f "$ROOT/config" ] && grep -q '^lang=' "$ROOT/config"; then lang=$(sed -n 's/^lang=//p' "$ROOT/config" | head -1)
      elif [ -t 0 ]; then printf 'Language / 言語 [en/ja] (en): '; read -r lang; [ -n "$lang" ] || lang=en
      else lang=en; fi
    fi
    set_lang "$lang"
    dst="${HIDANE_SKILL_DIR:-$HOME/.claude/skills/hidane}"
    mkdir -p "$dst/scripts" "$dst/hooks"
    cp "$HERE/SKILL.$lang.md" "$dst/SKILL.md" && cp "$HERE/scripts/"*.sh "$HERE/scripts/gitattributes" "$dst/scripts/" && cp "$HERE/hooks/post-commit" "$dst/hooks/" && cp "$HERE/install.sh" "$dst/" && cp "$HERE/SKILL.en.md" "$HERE/SKILL.ja.md" "$dst/"
    echo "install.sh: installed ($lang): $dst"; exit 0 ;;
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
    echo "  最初に一度、全体に未出題を敷く: sh $HERE/scripts/tag.sh --all" ;;
  --unhook)
    if [ -f "$hook" ] && grep -q '^# hidane-hook' "$hook"; then rm -f "$hook"; echo "install.sh: 外しました"; else echo "install.sh: hidane の hook は無い"; fi ;;
  *) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
