#!/bin/sh
# init.sh(/hidane --init: hook を置き、全関数に概念を付ける)の L0 検査。
set -u
cd "$(dirname "$0")/.." || exit 2
export HIDANE_LANG=ja
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/root"; export HIDANE_VAULT="$TMP/vault"; export FAKE_COUNT="$TMP/count"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ng() { fail=$((fail+1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "     $2"; }
FAKE="$TMP/claude"; cat > "$FAKE" <<'F'
#!/bin/sh
echo x >> "$FAKE_COUNT"
cat > /dev/null
printf 'k1.c:1-4\tk1\t境界条件\n'
F
chmod +x "$FAKE"; : > "$FAKE_COUNT"
I="sh $PWD/scripts/init.sh --root $ROOT"

mkdir -p "$TMP/notgit"; o=$(cd "$TMP/notgit" && $I 2>&1); rc=$?; [ $rc = 3 ] && ok "I01 git リポジトリの外は exit 3" || ng "I01" "rc=$rc $o"

R="$TMP/newrepo"; mkdir -p "$R"; (cd "$R" && git init -q && git config user.email t@t && git config user.name t && printf 'int k1(int x)\n{\n\treturn x;\n}\n' > k1.c && git add -A && git commit -qm init)
o=$(cd "$R" && HIDANE_CLAUDE="$FAKE" $I 2>&1); rc=$?
hook="$R/.git/hooks/post-commit"
i=0; while [ $i -lt 40 ] && ! grep -q '候補' "$ROOT/hook.log" 2>/dev/null; do sleep 0.25; i=$((i+1)); done
{ [ $rc = 0 ] && echo "$o" | sed -n 1p | grep -q '^登録: newrepo(' && [ -f "$hook" ] && grep -q '^# hidane-hook' "$hook" && [ -x "$hook" ] && echo "$o" | grep -q '^tag.sh: 候補 1 件。背景で' && [ "$(cat "$ROOT/newrepo/path")" -ef "$R" ] && grep -q '^| 20' "$ROOT/newrepo/functions.md" && echo "$o" | tail -1 | grep -q '^登録した: newrepo。'; } \
  && ok "I02 hook を置き、path を書き、背景で概念を付け、最後に登録したと出す" || ng "I02" "rc=$rc $o $(ls -R "$ROOT" 2>&1)"
o=$(cd "$R" && HIDANE_CLAUDE="$FAKE" $I --no-tag 2>&1); rc=$?; n=$(wc -l < "$FAKE_COUNT" | tr -d ' ')
{ [ $rc = 0 ] && [ "$n" = 1 ] && grep -q '^# hidane-hook' "$hook" && ! echo "$o" | grep -q 'tag.sh:'; } && ok "I03 2 回目(--no-tag)は hook を置き直すだけで claude は呼ばない" || ng "I03" "rc=$rc n=$n $o"

R2="$TMP/other"; mkdir -p "$R2"; (cd "$R2" && git init -q && printf '#!/bin/sh\necho mine\n' > .git/hooks/post-commit && chmod +x .git/hooks/post-commit)
o=$(cd "$R2" && HIDANE_CLAUDE="$FAKE" $I --no-tag 2>&1); rc=$?
{ [ $rc = 0 ] && echo "$o" | grep -q '別の post-commit hook' && [ "$(cat "$R2/.git/hooks/post-commit")" = "$(printf '#!/bin/sh\necho mine')" ] && [ -f "$ROOT/other/path" ]; } && ok "I04 他人の hook は触らず知らせて続ける(path は書く)" || ng "I04" "rc=$rc $o"

echo; echo "PASS $pass / FAIL $fail"
[ $fail -eq 0 ]
