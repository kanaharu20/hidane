#!/bin/sh
# hidane scope.sh — 関数単位の候補(場所 名前 行数 分岐)を出す。tag.sh が使う。
#   scope.sh --all [dir]      配下の全ファイル(未 commit の新規ファイルも)から候補を全部出す(分岐の多い順。上限なし)
#   scope.sh --commit <rev>   その commit が触ったファイルだけ。行番号も中身もその commit の木で数える(hook 用)
# 既に問うた関数(log.md の 場所のファイル + 関数名)は除く。記録の場所は HIDANE_ROOT。
set -eu
all=""; rev=""; dir="."
while [ $# -gt 0 ]; do
  case "$1" in
    --all)   all=1; shift ;;
    --commit) all=1; rev="$2"; shift 2 ;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) dir="$1"; shift ;;
  esac
done
[ -n "$all" ] || { sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repository: $PWD" >&2; exit 3; }
cd "$(git rev-parse --show-toplevel)"
tmpf=$(mktemp); trap 'rm -f "$tmpf"' EXIT

# 除外: 文書・ロック・生成物。判断が要るものは残す。
# パス頭の目印に空白を含めるのは、一覧側では numstat を整形した後の行に対して
# grep をかけるため(`   1 +/   0 -  package-lock.json`)。^ も / も直前に来ない。
excl='\.(md|txt|lock|min\.js|map|svg|png|jpg|gif|pdf|mk|cmake)$|(^|/)(Makefile|makefile|GNUmakefile|CMakeLists\.txt)$|(^|/|[[:space:]])(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|go\.sum|poetry\.lock|uv\.lock)$|(^|/|[[:space:]])(LICENSE|COPYING|NOTICE)[^/]*$|(^|/|[[:space:]])\.[^/]+$'

# 並び: (1) 分岐・ループ・return が多い順 (2) 同数なら短い順。
# 関数の切り出しは列 0 か字下げの def/func/fn/class … と、C 風の「型 名前(」の行。粗いが、範囲は Claude が読んでから合わせる。
if [ -n "$all" ]; then
  [ -d "$dir" ] || { echo "no such directory: $dir" >&2; exit 4; }
  # 既に問うた関数。log.md の 場所(3 列目)のファイル + 関数(4 列目)
  log=$("$(dirname "$0")/record.sh" --path 2>/dev/null || true)
  asked=""
  [ -f "$log" ] && asked=$(awk -F'|' '/^\| 20/ {
      gsub(/^ +| +$/, "", $3); gsub(/^ +| +$/, "", $4)
      f = $3; sub(/:.*/, "", f); print f ":" $4 }' "$log" | tr '\n' '\001')
  if [ -n "$rev" ]; then
    files=$(git diff-tree --root --no-commit-id --name-only -r "$rev" -- "$dir" 2>/dev/null) || { echo "no such commit: $rev" >&2; exit 4; }
  else
    files=$(git ls-files --cached --others --exclude-standard -- "$dir")   # 未追跡(未 commit)のファイルも。無視されるものは除く
  fi
  printf '%s\n' "$files" | grep -Ev "$excl" | grep -Ev '(^|/)(test|tests|spec|__tests__|node_modules|vendor|dist|build)/' \
  | while IFS= read -r f; do
      # 読む木: --commit ならその commit の版(作業ツリーと行がずれていても、行番号と中身が一致する)
      if [ -n "$rev" ]; then git show "$rev:$f" > "$tmpf" 2>/dev/null || continue; src="$tmpf"; else [ -f "$f" ] || continue; src="$f"; fi
      awk -v F="$f" '
        function has_brace(a, b,   i) { for (i = a; i <= b; i++) if (buf[i] ~ /\{/) return 1; return 0 }
        function flush(   n, i, k, name, key) {
          if (!start) return
          e = NR - 1
          while (e > start && buf[e] ~ /^[[:space:]]*$/) e--
          n = e - start + 1
          if (n >= 3 && (!brace_needed || has_brace(start, e))) {
            k = 0
            for (i = start; i <= e; i++)
              if (buf[i] ~ /(^|[^A-Za-z0-9_])(if|else|elif|for|while|switch|case|return|raise|throw|try|catch|except|break|continue)([^A-Za-z0-9_]|$)/) k++
            printf "%s:%d-%d\t%s\t%d\t%d\n", F, start, e, head, n, k
          }
        }
        { buf[NR] = $0 }
        # 言語のキーワードで始まる定義(字下げも可)
        (/^[[:space:]]*(async[[:space:]]+)?(def|class|fn|func|function|sub|impl|struct|enum|interface|trait|proc)[[:space:]]+[A-Za-z_]/ && $0 !~ /;[[:space:]]*$/) ||
        # C 風: 列 0 から始まり ( を含み ; で終わらず、制御構文で始まらない
        (/^[A-Za-z_][^;=]*\(/ && $0 !~ /;[[:space:]]*$/ && $0 !~ /^(if|for|while|switch|return|else|do|case|from|import)[^A-Za-z0-9_]/ && $0 !~ /^#/) ||
        # Java/C#/TS のメソッド: 字下げ + 修飾子 + 名前(
        /^[[:space:]]+(public|private|protected|static|export|override|final)[^;=]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\([^;]*$/ {
          flush()
          start = NR
          brace_needed = ($0 !~ /^[[:space:]]*(async[[:space:]]+)?(def|class|fn|func|function|sub|impl|struct|enum|interface|trait|proc)[[:space:]]/)
          head = $0; sub(/^[[:space:]]+/, "", head)
          gsub(/[[:space:]]+/, " ", head)
        }
        END { NR++; flush() }' "$src"
    done \
  | awk -F'\t' -v asked="$asked" '
      BEGIN { n = split(asked, a, "\001"); for (i = 1; i <= n; i++) if (a[i] != "") seen[a[i]] = 1 }
      {
        # 見出しから関数名だけを取る
        h = $2; sub(/[[:space:]]*\(.*$/, "", h); sub(/[[:space:]]*[{:;][[:space:]]*$/, "", h)
        m = h; sub(/.*[^A-Za-z0-9_$]/, "", m)
        f = $1; sub(/:.*/, "", f)
        if ((f ":" m) in seen) next
        print $4 "\t" $3 "\t" $1 "\t" m "\t" $2
      }' \
  | sort -t"$(printf '\t')" -k1,1nr -k2,2n \
  | awk -F'\t' 'BEGIN { print "# 候補(上ほど優先)。分岐 = if/for/while/return などの行数。聞いた関数は除いてある" }
                { printf "%-32s %-20s %3d行 分岐%-3d %s\n", $3, $4, $2, $1, $5 }'
  exit 0
fi
