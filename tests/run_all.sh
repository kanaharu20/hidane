#!/bin/sh
# hidane の L0 検査を全部回す。LLM は呼ばない。数秒。
# 最後に、検査の合計数が README のバッジと CHANGELOG の数字と一致するかも確かめる(文書とコードの一致)。
cd "$(dirname "$0")" || exit 2
rc=0; total=0
# 本物の記録に検査が触れていないことを、前後の一覧で確かめる(fixture の repo が ~/.claude/hidane に漏れた事故があった)
real="${HIDANE_ROOT:-$HOME/.claude/hidane}"; before=$(ls -A "$real" 2>/dev/null | sort)
for t in test_map.sh test_pages.sh test_tag.sh test_record.sh test_next.sh test_ask.sh test_init.sh test_lint.sh test_lang.sh test_keys.sh test_update.sh test_explain.sh test_weak.sh; do
  echo "### $t"
  out=$(sh "$t" 2>&1); r=$?
  echo "$out" | grep -E '^FAIL|^PASS [0-9]+ / FAIL'
  n=$(echo "$out" | sed -n 's/^PASS \([0-9]*\) \/ FAIL \([0-9]*\)$/\1 \2/p' | tail -1)
  total=$((total + ${n%% *} + ${n##* }))
  [ $r = 0 ] || rc=1
done
echo "### docs"
for f in ../README.md ../README.ja.md ../CHANGELOG.md; do
  if grep -q "\\b$total\\b" "$f"; then echo "PASS $f mentions $total tests"; else echo "FAIL $f does not mention the real test count ($total)"; rc=1; fi
done
after=$(ls -A "$real" 2>/dev/null | sort)
if [ "$before" = "$after" ]; then echo "PASS real records untouched ($real)"; else echo "FAIL tests wrote into the real records dir: $(printf '%s\n%s' "$before" "$after" | sort | uniq -u | tr '\n' ' ')"; rc=1; fi
echo "total: $total"
[ $rc = 0 ] && echo "ALL PASS" || echo "SOME FAIL"
exit $rc
