#!/bin/sh
# hidane install.sh
#   install.sh                          セットアップ一式。言語を聞き、/hidane を登録し、今いる git リポジトリに hook を置き、
#                                       全関数に概念を付けて地図を作る(claude が要る。無ければ地図は次の commit から)
#   install.sh --skill [--lang en|ja]   /hidane の登録だけ(~/.claude/skills/hidane にコピー)
#   install.sh --hook                   今いるリポジトリに post-commit hook を置く(他人の hook があれば触らない)
#   install.sh --unhook                 hidane の hook なら消す
#   install.sh --lang en|ja             言語を指定してセットアップ一式(あとから言語を変えるときも同じ)
#   install.sh --update                 最新版にする(git pull → /hidane を更新 → 記録の形式を移行)。/hidane --update と同じ
#   install.sh --version                版を出す
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"
cmd="${1:-}"; lang=""
[ "${2:-}" = "--lang" ] && lang="${3:-}"
[ "$cmd" = "--lang" ] && { lang="${2:-}"; cmd=""; }

set_lang() {
  case "$1" in en|ja) ;; *) echo "install.sh: --lang en | ja" >&2; exit 2 ;; esac
  mkdir -p "$ROOT"
  if [ -f "$ROOT/config" ] && grep -q '^lang=' "$ROOT/config"; then sed "s/^lang=.*/lang=$1/" "$ROOT/config" > "$ROOT/config.tmp" && mv "$ROOT/config.tmp" "$ROOT/config"; else echo "lang=$1" >> "$ROOT/config"; fi
}
pick_lang() {  # 引数 > config > 端末で聞く > en
  if [ -z "$lang" ]; then
    if [ -f "$ROOT/config" ] && grep -q '^lang=' "$ROOT/config"; then lang=$(sed -n 's/^lang=//p' "$ROOT/config" | head -1)
    elif [ -t 0 ]; then printf 'Language / 言語 [en/ja] (en): '; read -r lang; [ -n "$lang" ] || lang=en
    else lang=en; fi
  fi
  set_lang "$lang"
}
say() { if [ "$lang" = "ja" ]; then printf '%s\n' "$1"; else printf '%s\n' "$2"; fi; }
install_skill() {
  dst="${HIDANE_SKILL_DIR:-$HOME/.claude/skills/hidane}"
  mkdir -p "$dst/scripts" "$dst/hooks"
  rm -f "$dst/scripts/"*   # 前の版の残骸を消してから置く
  cp "$HERE/SKILL.$lang.md" "$dst/SKILL.md"; cp "$HERE/scripts/"*.sh "$dst/scripts/"
  cp "$HERE/hooks/post-commit" "$dst/hooks/"; cp "$HERE/install.sh" "$HERE/SKILL.en.md" "$HERE/SKILL.ja.md" "$HERE/VERSION" "$dst/"
  printf '%s\n' "$HERE" > "$dst/HOME"
  say "  /hidane を登録した: $dst" "  /hidane registered: $dst"
}
hook_path() {  # $1 = git root。worktree や core.hooksPath でも正しい場所
  h=$(git -C "$1" rev-parse --git-path hooks 2>/dev/null) || h=".git/hooks"
  case "$h" in /*) ;; *) h="$1/$h" ;; esac
  printf '%s/post-commit\n' "$h"
}
install_hook() {  # $1 = git root
  hook=$(hook_path "$1")
  if [ -f "$hook" ] && ! grep -q '^# hidane-hook' "$hook"; then
    say "  別の post-commit hook があるので触らない: $hook" "  another post-commit hook exists; left alone: $hook"; return 1
  fi
  mkdir -p "$(dirname "$hook")" 2>/dev/null
  if ! { sed "s|__HIDANE_HOME__|$HERE|" "$HERE/hooks/post-commit" > "$hook" && chmod +x "$hook"; }; then
    say "  hook を置けなかった: $hook" "  could not write the hook: $hook"; return 1
  fi
  say "  hook を置いた: $hook" "  hook installed: $hook"
  say "    commit のたびに、触った関数のソースが背景で Claude(claude -p)に送られ、概念名が返る。commit は待たない。止めるには HIDANE_HOOK_OFF=1 か install.sh --unhook" \
      "    after every commit the touched functions' source is sent to Claude (claude -p) in the background and concept names come back. The commit never waits. Stop it with HIDANE_HOOK_OFF=1 or install.sh --unhook"
}

case "$cmd" in
  --version) cat "$HERE/VERSION" ;;
  --update)
    lang=$(sed -n 's/^lang=//p' "$ROOT/config" 2>/dev/null | head -1); [ -n "$lang" ] || lang=en
    before=$(cat "$HERE/VERSION")
    if [ -d "$HERE/.git" ]; then
      git -C "$HERE" pull --ff-only -q || { say "  git pull に失敗。$HERE で手で解決してから もう一度" "  git pull failed; fix it in $HERE and retry"; exit 4; }
    fi
    after=$(cat "$HERE/VERSION")
    install_skill
    sh "$HERE/scripts/migrate.sh"
    sh "$HERE/scripts/pages.sh" >/dev/null 2>&1 || true
    say "hidane $before → $after" "hidane $before → $after" ;;
  "")
    pick_lang
    say "hidane セットアップ(lang=$lang)" "hidane setup (lang=$lang)"
    install_skill
    sh "$HERE/scripts/migrate.sh" >/dev/null
    if top=$(git rev-parse --show-toplevel 2>/dev/null); then
      install_hook "$top" || true
      if command -v "${HIDANE_CLAUDE:-claude}" >/dev/null 2>&1; then
        say "  全関数に概念を付けている(1 分前後)…" "  tagging every function with concepts (about a minute)..."
        sh "$HERE/scripts/tag.sh" --all --repo "$top" || say "  タグ付けに失敗した。次の commit からでも動く" "  tagging failed; it will run again on the next commit"
      else
        say "  claude コマンドが無いのでタグ付けは飛ばした(次の commit で hook が試す)" "  claude not found; skipped tagging (the hook will try on the next commit)"
      fi
    else
      say "  git リポジトリの外なので hook は置かない。使いたいリポジトリで もう一度 install.sh を実行" "  not inside a git repository; run install.sh again inside one to add the hook"
    fi
    vault="${HIDANE_VAULT:-$HOME/Documents/hidane}"
    say "次: Obsidian で $vault を「Open folder as vault」で開く。Claude Code で /hidane" "Next: open $vault in Obsidian (Open folder as vault). Then run /hidane in Claude Code"
    ;;
  --skill) pick_lang; install_skill ;;
  --hook)
    top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "install.sh: run inside a git repository" >&2; exit 3; }
    lang=$(sed -n 's/^lang=//p' "$ROOT/config" 2>/dev/null | head -1); [ -n "$lang" ] || lang=en
    install_hook "$top" || exit 5 ;;
  --unhook)
    top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "install.sh: run inside a git repository" >&2; exit 3; }
    hook=$(hook_path "$top")
    if [ -f "$hook" ] && grep -q '^# hidane-hook' "$hook"; then rm -f "$hook"; echo "install.sh: hook removed"; else echo "install.sh: no hidane hook here"; fi ;;
  *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
