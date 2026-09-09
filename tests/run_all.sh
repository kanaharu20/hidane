#!/bin/sh
# hidane の L0 検査を全部回す。LLM は呼ばない。数秒。
cd "$(dirname "$0")" || exit 2
rc=0
for t in test_map.sh test_pages.sh test_tag.sh test_record.sh test_next.sh test_lint.sh test_lang.sh test_keys.sh; do
  echo "### $t"; sh "$t" | grep -E '^FAIL|^PASS [0-9]+ / FAIL' || rc=1
  sh "$t" >/dev/null 2>&1 || rc=1
done
[ $rc = 0 ] && echo "ALL PASS" || echo "SOME FAIL"
exit $rc
