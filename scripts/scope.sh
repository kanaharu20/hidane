#!/bin/sh
# reflect の対象範囲を出す。
#   scope.sh [--since DATE | --days N] [--author PAT]          変更ファイル一覧(基準コミットつき)
#   scope.sh [--since DATE | --days N] [--author PAT] <file>   そのファイルのハンク(-U0、新規行番号は @@ +c,d @@)
#   scope.sh --all [dir]      日付に関係なく、配下の全ファイル(未 commit の新規ファイルも)から関数単位の候補を全部出す(上ほど優先。上限なし)
#   scope.sh --commit <rev>   そのコミットが触ったファイルだけから、同じ形で候補を出す(フック用)
# 基準 = 範囲開始日時より前の最後のコミット。無ければ空ツリー。
# 未追跡の新規ファイルも一覧に出す(git diff は追跡ファイルしか見ないため)。
set -eu
since=""; days=""; author=""; file=""; all=""; rev=""
while [ $# -gt 0 ]; do
  case "$1" in
    --all)   all=1; shift ;;
    --commit) all=1; rev="$2"; shift 2 ;;
    --since) since="$2"; shift 2 ;;
    --days)  days="$2";  shift 2 ;;
    --author) author="$2"; shift 2 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    --) shift; file="${1:-}"; break ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) file="$1"; shift ;;
  esac
done

# 言語ごとの関数名の見つけ方。git に -c で渡すだけで、リポジトリには書き込まない。
# ルートへ移る前に絶対パスにしておく。
attr="$(cd "$(dirname "$0")" && pwd -P)/gitattributes"
# js/ts は git に組み込みが無いので自前。export/async/static などの修飾を飛ばして
# 名前 + 引数 + { に当てる。字下げされたメソッドも拾う。
#
# 1 行目の ! は否定パターン(git が対応している)。これが無いと
# `if (!uid) {` が「名前 + 引数 + {」に当たり、ネストしたブロックの中を
# 変えたときに見出しが `if (...)` になる。git の組み込みドライバが
# 制御構文を除いているのと同じ理由。
xfn='!^[[:space:]]*(if|for|while|switch|catch|return|typeof|await|yield|delete|void|new)[[:space:]]*\(
^[[:space:]]*(((export|default|async|static|public|private|protected|readonly|abstract|get|set)[[:space:]]+)*(function|class|interface|type|enum|const|let|var)[[:space:]]+[A-Za-z_$][A-Za-z0-9_$]*|[A-Za-z_$][A-Za-z0-9_$]*[[:space:]]*\([^;]*\)[[:space:]]*(:[^;{]*)?\{).*$'
gitd() {
  if [ -f "$attr" ]; then
    git -c core.attributesFile="$attr" -c diff.reflectjs.xfuncname="$xfn" "$@"
  else
    git "$@"
  fi
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repository: $PWD" >&2; exit 3; }
# ルートへ移る前に相対パスを解決する。移ってから解決すると、
# サブディレクトリで `scope.sh api.py` と打ったときに見つからなくなる。
if [ -n "$file" ] && [ -e "$file" ]; then
  file="$(cd "$(dirname "$file")" && pwd -P)/$(basename "$file")"
fi
cd "$(git rev-parse --show-toplevel)"

# 除外: 文書・ロック・生成物。判断が要るものは残す。
# パス頭の目印に空白を含めるのは、一覧側では numstat を整形した後の行に対して
# grep をかけるため(`   1 +/   0 -  package-lock.json`)。^ も / も直前に来ない。
excl='\.(md|txt|lock|min\.js|map|svg|png|jpg|gif|pdf|mk|cmake)$|(^|/)(Makefile|makefile|GNUmakefile|CMakeLists\.txt)$|(^|/|[[:space:]])(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|go\.sum|poetry\.lock|uv\.lock)$|(^|/|[[:space:]])(LICENSE|COPYING|NOTICE)[^/]*$|(^|/|[[:space:]])\.[^/]+$'

# --- 日付に関係なく、配下の全ファイルから関数単位の候補を出す ---
# diff が無いので「Claude が決めた変更」は判定できない。代わりに
#   (1) まだ聞いていない関数  (2) 分岐・ループ・return が多い順  (3) 同数なら短い順
# で並べる。Claude はファイルを読まず、先頭の 1 件を sed -n で読むだけ。
# 関数の切り出しは列 0 か字下げの def/func/fn/class … と、C 風の「型 名前(」の行。
# 粗いが、行の範囲は Claude が読んでから構文のまとまりに合わせる(手順1)。
if [ -n "$all" ]; then
  dir="${file:-.}"
  [ -d "$dir" ] || { echo "no such directory: $dir" >&2; exit 4; }
  # 既に聞いた関数。記録の 関数 列(8 列目)と場所のファイルで突き合わせる
  log=$("$(dirname "$0")/record.sh" --path 2>/dev/null || true)
  asked=""
  [ -f "$log" ] && asked=$(awk -F'|' '/^\| 20/ {
      gsub(/^ +| +$/, "", $3); gsub(/^ +| +$/, "", $9)
      f = $3; sub(/:.*/, "", f)
      if ($9 != "") print f ":" $9; else print $3 }' "$log" | tr '\n' '\001')
  if [ -n "$rev" ]; then
    files=$(git diff-tree --root --no-commit-id --name-only -r "$rev" -- "$dir" 2>/dev/null) || { echo "no such commit: $rev" >&2; exit 4; }
  else
    files=$(git ls-files --cached --others --exclude-standard -- "$dir")   # 未追跡(未 commit)のファイルも。無視されるものは除く
  fi
  printf '%s\n' "$files" | grep -Ev "$excl" | grep -Ev '(^|/)(test|tests|spec|__tests__|node_modules|vendor|dist|build)/' \
  | while IFS= read -r f; do
      [ -f "$f" ] || continue
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
        END { NR++; flush() }' "$f"
    done \
  | awk -F'\t' -v asked="$asked" '
      BEGIN { n = split(asked, a, "\001"); for (i = 1; i <= n; i++) if (a[i] != "") seen[a[i]] = 1 }
      {
        # 見出しから関数名だけを取る(record.sh の fnkey と同じ削り方)
        h = $2; sub(/[[:space:]]*\(.*$/, "", h); sub(/[[:space:]]*[{:;][[:space:]]*$/, "", h)
        m = h; sub(/.*[^A-Za-z0-9_$]/, "", m)
        f = $1; sub(/:.*/, "", f)
        if ((f ":" m) in seen || ($1 in seen)) next
        print $4 "\t" $3 "\t" $1 "\t" m "\t" $2
      }' \
  | sort -t"$(printf '\t')" -k1,1nr -k2,2n \
  | awk -F'\t' 'BEGIN { print "# 候補(上ほど優先)。分岐 = if/for/while/return などの行数。聞いた関数は除いてある" }
                { printf "%-32s %-20s %3d行 分岐%-3d %s\n", $3, $4, $2, $1, $5 }'
  exit 0
fi


# 範囲の開始日時
if [ -n "$since" ]; then
  case "$since" in *:*) start="$since" ;; *) start="$since 00:00" ;; esac
elif [ -n "$days" ]; then
  d=$(date -v-"$days"d +%F 2>/dev/null || date -d "$days days ago" +%F)
  start="$d 00:00"
else
  start="$(date +%F) 00:00"
fi

empty=$(git hash-object -t tree /dev/null)
if git rev-parse -q --verify HEAD >/dev/null 2>&1; then
  base=$(git rev-list -n1 --before="$start" HEAD || true)
else
  base=""
fi
[ -n "$base" ] || base="$empty"

# --- 単一ファイルのハンク ---
if [ -n "$file" ]; then
  if git ls-files --error-unmatch -- "$file" >/dev/null 2>&1; then
    gitd diff -U0 "$base" -- "$file"
  elif [ -f "$file" ]; then
    gitd diff -U0 --no-index -- /dev/null "$file" || true   # 未追跡: 全行が新規
  else
    echo "no such file: $file" >&2; exit 4
  fi
  exit 0
fi

# --- 一覧 ---
if [ "$base" = "$empty" ]; then
  echo "base: (空ツリー。$start より前のコミットなし)"
else
  echo "base: $(git log -1 --format='%h %ad %s' --date='format:%Y-%m-%d %H:%M' "$base")"
fi
echo "range: $start 以降(コミット済み + 未コミット)"

if [ -n "$author" ]; then
  # 自分のコミットが触ったファイル + 未コミット分。
  # 一時ファイルは作らない。TMPDIR を見ておらず、名前も予測できたため
  # (共有の /tmp では衝突と symlink の的になる)。印を付けて 1 本の流れにする。
  T=$(printf '\t')
  { { git log --author="$author" --since="$start" --name-only --format= "$base"..HEAD 2>/dev/null
      git diff --name-only HEAD; } | sort -u | sed "s|^|K$T|"
    git diff --numstat "$base" | sed "s|^|N$T|"
  } | awk -F'\t' '$1=="K" {keep[$2]=1} $1=="N" && ($4 in keep) {printf "%4s +/%4s -  %s\n",$2,$3,$4}'
else
  git diff --numstat "$base" | awk -F'\t' '{printf "%4s +/%4s -  %s\n",$1,$2,$3}'
fi | grep -Ev "$excl" || true
git ls-files --others --exclude-standard | grep -Ev "$excl" | sed 's/^/ new         /' || true
