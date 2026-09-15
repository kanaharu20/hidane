#!/bin/sh
# hidane resolve.sh — 行の流れの中の概念名を、aliases.md(旧名 → 新名)で置き換えるフィルタ。
# 使い方: ... | resolve.sh [--root DIR]
#   入力: 先頭に何かタブ区切りの前置きがあってもよく、最初の | から先が log.md / functions.md の行
#   概念は 5 列目(| 日時 | 場所 | 関数 | 概念 | ... / | 日付 | 場所 | 関数 | 概念 | ...)
#   aliases.md の行: | 日付 | 旧名 | 新名 | 理由 |   連鎖(a→b, b→c)は 10 段まで追う。同名の重複は 1 つにする
# aliases.md が無ければそのまま通す。log.md 自体は書き換えない。
set -eu
ROOT="${HIDANE_ROOT:-$HOME/.claude/hidane}"
[ "${1:-}" = "--root" ] && ROOT="$2"
A="$ROOT/aliases.md"
[ -f "$A" ] || { cat; exit 0; }
awk -F'\t' -v aliases="$A" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function canon(c,   i) { for (i = 0; i < 10 && (c in to); i++) c = to[c]; return c }
BEGIN {
  while ((getline l < aliases) > 0) {
    if (l !~ /^\| 20/) continue
    split(l, a, "|"); o = trim(a[3]); n = trim(a[4]); if (o != "" && n != "" && o != n) to[o] = n
  }
}
{
  i = index($0, "|"); if (i == 0) { print; next }
  head = substr($0, 1, i - 1); tbl = substr($0, i)
  n = split(tbl, col, "|")
  k = split(col[5], cs, ","); out = ""; delete seen
  for (j = 1; j <= k; j++) { c = trim(cs[j]); m = (c ~ /^\*/) ? "*" : ""; sub(/^\*/, "", c); c = canon(c); if (c == "" || (c in seen)) continue; seen[c] = 1; out = (out == "" ? m c : out ", " m c) }
  col[5] = " " out " "
  line = col[1]; for (j = 2; j <= n; j++) line = line "|" col[j]
  print head line
}'
