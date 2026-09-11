#!/bin/sh
# hidane lang.sh — 表示言語の表。各スクリプトが `. lang.sh` で読む。記録の中は言語に依らない記号。
#   言語の決め方: HIDANE_LANG > <root>/config の lang= > en
#   記号: 状態 known/fuzzy/unknown/unasked  型 trace/edge/summary  結果 hit/miss/dunno/skip
hidane_lang() {
  if [ -n "${HIDANE_LANG:-}" ]; then echo "$HIDANE_LANG"; return; fi
  c="${ROOT:-$HOME/.claude/hidane}/config"
  if [ -f "$c" ]; then l=$(sed -n 's/^lang=//p' "$c" | head -1); [ -n "$l" ] && { echo "$l"; return; }; fi
  echo en
}
LANGX=$(hidane_lang)
case "$LANGX" in ja|en) ;; *) LANGX=en ;; esac
L() {
  case "$LANGX:$1" in
    ja:st_known) echo "理解" ;;                 en:st_known) echo "understood" ;;
    ja:st_fuzzy) echo "曖昧" ;;                 en:st_fuzzy) echo "fuzzy" ;;
    ja:st_unknown) echo "非理解" ;;             en:st_unknown) echo "not understood" ;;
    ja:st_unasked) echo "未出題" ;;             en:st_unasked) echo "unasked" ;;
    ja:ty_trace) echo "追う" ;;                 en:ty_trace) echo "trace" ;;
    ja:ty_edge) echo "追う(境界・変異)" ;;      en:ty_edge) echo "trace (edge/mutation)" ;;
    ja:ty_summary) echo "要約" ;;               en:ty_summary) echo "summary" ;;
    ja:rs_hit) echo "当たり" ;;                 en:rs_hit) echo "hit" ;;
    ja:rs_miss) echo "ズレ" ;;                  en:rs_miss) echo "miss" ;;
    ja:rs_partial) echo "部分" ;;               en:rs_partial) echo "partial" ;;
    ja:rs_dunno) echo "分からない" ;;           en:rs_dunno) echo "don't know" ;;
    ja:rs_skip) echo "未回答" ;;                en:rs_skip) echo "unanswered" ;;
    ja:h_concept) echo "概念" ;;                en:h_concept) echo "Concept" ;;
    ja:h_value) echo "値" ;;                    en:h_value) echo "Value" ;;
    ja:h_evidence) echo "証拠" ;;               en:h_evidence) echo "Evidence" ;;
    ja:h_last) echo "最終" ;;                   en:h_last) echo "Last" ;;
    ja:h_state) echo "状態" ;;                  en:h_state) echo "State" ;;
    ja:h_repo) echo "repo" ;;                   en:h_repo) echo "Repo" ;;
    ja:log_header) echo "| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | ズレ | 備考 |" ;;
    en:log_header) echo "| Date | Place | Function | Concepts | Type | Question | Result | Miss | Note |" ;;
    ja:fn_header) echo "| 日付 | 場所 | 関数 | 概念 | commit | 備考 |" ;;
    en:fn_header) echo "| Date | Place | Function | Concepts | Commit | Note |" ;;
    ja:fn_title) echo "commit 時に付けた概念(まだ問うていない関数)" ;;
    en:fn_title) echo "concepts tagged at commit time (functions not yet asked)" ;;
    ja:al_header) echo "| 日付 | 旧名 | 新名 | 理由 |" ;;
    en:al_header) echo "| Date | Old | New | Reason |" ;;
    ja:al_title) echo "概念の別名(旧名 → 新名)。lint.sh が足す。取り消すときは行を消す" ;;
    en:al_title) echo "concept aliases (old → new). Appended by lint.sh; delete a line to undo" ;;
    ja:n_place) echo "場所" ;;                  en:n_place) echo "Place" ;;
    ja:n_func) echo "関数" ;;                   en:n_func) echo "Function" ;;
    ja:n_concepts) echo "概念" ;;               en:n_concepts) echo "Concepts" ;;
    ja:n_lead) echo "代表" ;;                   en:n_lead) echo "Lead concept" ;;
    ja:n_why) echo "理由" ;;                    en:n_why) echo "Why" ;;
    ja:n_zure) echo "過去のズレ" ;;             en:n_zure) echo "Past misses" ;;
    ja:n_type) echo "型" ;;                     en:n_type) echo "Type" ;;
    ja:n_inputs) echo "入力の候補" ;;           en:n_inputs) echo "Input candidates" ;;
    ja:n_form) echo "問いの形" ;;               en:n_form) echo "Question form" ;;
    ja:n_why_unknown) echo "非理解の概念に付いた、まだ問うていない関数" ;;
    en:n_why_unknown) echo "an unasked function tagged with a not-understood concept" ;;
    ja:n_why_fuzzy) echo "曖昧な概念に付いた、まだ問うていない関数" ;;
    en:n_why_fuzzy) echo "an unasked function tagged with a fuzzy concept" ;;
    ja:n_why_unasked) echo "まだ問うていない関数" ;;
    en:n_why_unasked) echo "a function not yet asked" ;;
    ja:n_inputs_edge) echo "空 / 1 個だけ / 末尾 / 上限ちょうど / 過去のズレの状況を再現する値、のどれか 1 つ" ;;
    en:n_inputs_edge) echo "one of: empty / a single element / the last element / exactly the limit / a value that reproduces a past miss" ;;
    ja:n_inputs_trace) echo "普通の値を 1 つ" ;;
    en:n_inputs_trace) echo "one ordinary value" ;;
    ja:n_form_text) echo "「<場所> <関数>。<入力> のとき、何を返す / 何が起きるか」の 1 問だけ。「なぜ」「何が必要か」は問わない" ;;
    en:n_form_text) echo "exactly one question: \"<place> <function>. Given <input>, what does it return / what happens?\" Never ask \"why\" or \"what is needed\"" ;;
    ja:n_edge_hint) echo "過去のズレを突く入力を選ぶ" ;;  en:n_edge_hint) echo "pick an input that hits a past miss" ;;
    ja:n_none_repo) echo "には記録が無い。commit するか tag.sh --commit HEAD を回して、関数に概念を付けてください" ;;
    en:n_none_repo) echo "has no records yet. Commit, or run tag.sh --commit HEAD, to tag functions with concepts" ;;
    ja:n_none_cand) echo "候補なし: この repo の関数は全部問うた(または理解のみ)。commit するか tag.sh --commit HEAD を回して関数に概念を付ける" ;;
    en:n_none_cand) echo "no candidates: every function in this repo has been asked (or is understood only). Commit, or run tag.sh --commit HEAD" ;;
    ja:n_stale) echo "作業ツリーに無い関数 %d 件は除いた" ;;  en:n_stale) echo "%d functions no longer in the working tree were skipped" ;;
    ja:x_usage) echo "引数は 対象 [概念, 概念]" ;;      en:x_usage) echo "args: topic [concept, concept]" ;;
    ja:x_unknown) echo "地図に無い概念は捨てた" ;;      en:x_unknown) echo "dropped a concept not on the map" ;;
    ja:x_title) echo "求めた解説(状態には影響しない)" ;;  en:x_title) echo "explanations requested (never affects state)" ;;
    ja:x_header) echo "| 日時 | repo | 対象 | 概念 |" ;;  en:x_header) echo "| Date | Repo | Topic | Concepts |" ;;
    ja:i_overall) echo "全体" ;;                         en:i_overall) echo "Overall" ;;
    ja:i_answered) echo "答えた問い %d、最後に答えた日 %s" ;;  en:i_answered) echo "%d questions answered, last on %s" ;;
    ja:i_recent) echo "最近求めた解説" ;;               en:i_recent) echo "Recent explanations requested" ;;
    ja:i_none) echo "(まだ無い)" ;;                     en:i_none) echo "(none yet)" ;;
    ja:i_table) echo "概念" ;;                          en:i_table) echo "Concepts" ;;
    ja:m_footer) echo "読んだ行 %d / 使えた行 %d(基準日 %s、閾値 ±%d、上限 ±%d、鮮度 %d 日)" ;;
    en:m_footer) echo "rows read %d / usable %d (as of %s, threshold ±%d, cap ±%d, fresh %d days)" ;;
    ja:m_bad) echo "読めない行" ;;              en:m_bad) echo "unreadable row" ;;
    ja:p_state) echo "状態" ;;                  en:p_state) echo "State" ;;
    ja:p_related) echo "関連" ;;                en:p_related) echo "Related" ;;
    ja:p_zure) echo "典型的なズレ" ;;           en:p_zure) echo "Typical misses" ;;
    ja:p_records) echo "記録" ;;                en:p_records) echo "Records" ;;
    ja:p_unasked) echo "未出題の関数" ;;        en:p_unasked) echo "Unasked functions" ;;
    ja:p_summary) echo "概念 %s / repo %s ページ。" ;;  en:p_summary) echo "%s concept / %s repo pages." ;;
    ja:r_usage) echo "引数は 場所 関数 概念 型 問い 結果 [ズレ] [備考] の 6〜8 個" ;;
    en:r_usage) echo "expected 6-8 args: place function concepts type question result [miss] [note]" ;;
    ja:r_type) echo "型は trace / edge / summary のどれか" ;;   en:r_type) echo "type must be one of trace / edge / summary" ;;
    ja:r_result) echo "結果は dunno / skip のどちらか。hit / partial / miss は --verdict から決まる(手動は --free)" ;;
    en:r_result) echo "result must be dunno or skip; hit / partial / miss are derived from --verdict (or use --free)" ;;
    ja:r_nokeys) echo "鍵が無い。keys.sh で先に鍵を置いてから --verdict で判定する" ;;
    en:r_nokeys) echo "no keys; run keys.sh first, then judge with --verdict" ;;
    ja:r_verdict) echo "--verdict は鍵の数と同じ個数の yes / no / contra をコンマ区切りで" ;;
    en:r_verdict) echo "--verdict needs one of yes / no / contra per key, comma-separated" ;;
    ja:r_missing) echo "触れていない" ;;          en:r_missing) echo "not mentioned" ;;
    ja:r_contra) echo "逆" ;;                    en:r_contra) echo "contradicted" ;;
    ja:r_keys_of) echo "鍵 %d / %d" ;;           en:r_keys_of) echo "keys %d / %d" ;;
    ja:r_hint) echo "解説が要るなら /hidane --explain(触れていない鍵から、地図に合わせて説明する)" ;;
    en:r_hint) echo "for an explanation: /hidane --explain (starts from the missing keys, at your level)" ;;
    ja:k_nopending) echo "next.sh の決定(pending)が無い。先に next.sh を回す" ;;
    en:k_nopending) echo "no pending decision from next.sh; run next.sh first" ;;
    ja:k_count) echo "鍵は 2〜5 個" ;;           en:k_count) echo "give 2-5 keys" ;;
    ja:k_empty) echo "空の鍵" ;;                 en:k_empty) echo "empty key" ;;
    ja:k_saved) echo "鍵 %d 個を固定した(ユーザーには見せない)" ;; en:k_saved) echo "%d keys fixed (do not show them to the user)" ;;
    ja:r_place) echo "場所は file:a-b の形" ;;   en:r_place) echo "place must look like file:a-b" ;;
    ja:r_concepts) echo "概念が空" ;;            en:r_concepts) echo "concepts are empty" ;;
    ja:r_pending) echo "next.sh が決めた内容と違うので書かない(exit 7)。" ;;
    en:r_pending) echo "does not match what next.sh decided; not written (exit 7)." ;;
    ja:r_decided) echo "決定" ;;                 en:r_decided) echo "decided" ;;
    ja:r_given) echo "今回" ;;                   en:r_given) echo "given" ;;
    ja:r_free) echo "手で記録するなら --free" ;; en:r_free) echo "use --free to record by hand" ;;
    ja:r_undo) echo "追記した行が読めないので取り消した" ;; en:r_undo) echo "appended row was unreadable; reverted" ;;
    ja:r_norepo) echo "git リポジトリの中で実行するか --repo を付けてください" ;;
    en:r_norepo) echo "run inside a git repository or pass --repo" ;;
    ja:t_none) echo "付ける関数なし" ;;          en:t_none) echo "nothing to tag" ;;
    ja:t_done) echo "候補 %d、呼び出し %d 回、追記 %d 行、捨てた %d 行" ;; en:t_done) echo "candidates %d, calls %d, appended %d, dropped %d" ;;
    ja:t_drop) echo "捨てた" ;;                  en:t_drop) echo "dropped" ;;
    ja:t_new) echo "新" ;;                       en:t_new) echo "new" ;;
    ja:t_fail) echo "claude が失敗" ;;           en:t_fail) echo "claude failed" ;;
    ja:t_batch) echo "束" ;;                     en:t_batch) echo "batch" ;;
    ja:l_done) echo "統合 %d 組、捨てた %d 行" ;; en:l_done) echo "merged %d, dropped %d" ;;
    ja:l_few) echo "概念が %d 個なので何もしない" ;; en:l_few) echo "only %d concepts; nothing to do" ;;
    ja:o_opened) echo "Obsidian で開きました" ;; en:o_opened) echo "opened in Obsidian" ;;
    *) echo "$1" ;;
  esac
}
# 記号 → 表示。awk に渡す用
label_state() { case "$1" in known) L st_known ;; fuzzy) L st_fuzzy ;; unknown) L st_unknown ;; unasked) L st_unasked ;; *) echo "$1" ;; esac; }
