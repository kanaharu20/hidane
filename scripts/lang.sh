#!/bin/sh
# hidane lang.sh — 表示言語の表。各スクリプトが `. lang.sh` で読む。記録の中は言語に依らない記号。
#   言語の決め方: HIDANE_LANG > <root>/config の lang= > en
#   記号: 状態 known/fuzzy/unknown/unasked  型 trace/edge(summary は旧記録のみ)  結果 hit/partial/miss/dunno/skip
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
    ja:n_form_text) echo "「<場所> <関数>。<入力> のとき、何を返す / 次に何が呼ばれる / どこで抜けるか」の 1 問だけ。観測できるものを 1 つ名指しする(「どこで抜けるか」は抜け方が 2 つ以上ある関数だけ。分岐の無い関数には何を返すか・何を呼ぶか)(「ループはどうなるか」のような曖昧な対象は不可)。「なぜ」「何が必要か」は問わない" ;;
    en:n_form_text) echo "exactly one question: \"<place> <function>. Given <input>, what does it return / what is called next / where does it exit?\" Name one observable thing (not \"what happens to the loop\"; \"where does it exit\" only for a function with 2+ ways out, otherwise ask what it returns or what it calls). Never ask \"why\" or \"what is needed\"" ;;
    ja:n_edge_hint) echo "境界か、過去のズレを突く入力を選ぶ" ;;  en:n_edge_hint) echo "pick a boundary input, or one that hits a past miss" ;;
    ja:n_none_repo) echo "には記録が無い。commit するか tag.sh --commit HEAD を回して、関数に概念を付けてください" ;;
    en:n_none_repo) echo "has no records yet. Commit, or run tag.sh --commit HEAD, to tag functions with concepts" ;;
    ja:n_none_cand) echo "候補なし: この repo の関数は全部問うた(または理解のみ)。commit するか tag.sh --commit HEAD を回して関数に概念を付ける" ;;
    en:n_none_cand) echo "no candidates: every function in this repo has been asked (or is understood only). Commit, or run tag.sh --commit HEAD" ;;
    ja:n_stale) echo "作業ツリーに無い関数 %d 件は除いた" ;;  en:n_stale) echo "%d functions no longer in the working tree were skipped" ;;
    ja:x_usage) echo "引数は 対象 [概念, 概念]" ;;      en:x_usage) echo "args: topic [concept, concept]" ;;
    ja:x_unknown) echo "地図に無い概念は捨てた" ;;      en:x_unknown) echo "dropped a concept not on the map" ;;
    ja:x_title) echo "求めた解説(状態には影響しない)" ;;  en:x_title) echo "explanations requested (never affects state)" ;;
    ja:x_header) echo "| 日時 | repo | 対象 | 概念 |" ;;
    ja:w_head1) echo "地図から: 非理解 %s → ここから書く。曖昧 %s。過去のズレ %d 件を使った" ;;
    en:w_head1) echo "From the map: not understood %s → starting there. Fuzzy %s. Used %d past misses" ;;
    ja:w_head2) echo "飛ばした概念: %s" ;;                en:w_head2) echo "Skipped: %s" ;;
    ja:w_none_skip) echo "なし" ;;                       en:w_none_skip) echo "none" ;;
    ja:w_concept) echo "ズレ %d 件" ;;                    en:w_concept) echo "%d misses" ;;
    ja:w_funcs) echo "%s でこの概念が付いた関数" ;;        en:w_funcs) echo "functions tagged with it in %s" ;;
    ja:w_nofuncs) echo "(今いる repo にこの概念の関数は無い)" ;;  en:w_nofuncs) echo "(no function with this concept in the current repo)" ;;
    ja:w_none) echo "ズレの記録がまだ無い。一問答えると材料ができる" ;;  en:w_none) echo "no misses recorded yet; answer a question first" ;;  en:x_header) echo "| Date | Repo | Topic | Concepts |" ;;
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
    ja:p_gone) echo "(消えた)" ;;               en:p_gone) echo "(gone)" ;;
    ja:p_lost) echo "リポジトリが %s に無い。記録は残る(答えは自分のもの)。やめるなら ~/.claude/hidane/<repo> を消して /hidane --vault" ;;
    en:p_lost) echo "repository not found at %s. The records stay (answers are yours). To drop it, delete ~/.claude/hidane/<repo> and run /hidane --vault" ;;
    ja:p_gone_n) echo "作業ツリーに無い関数 %d 件には (消えた) と印を付けた。出題からは外れている" ;;
    en:p_gone_n) echo "%d functions no longer in the working tree are marked (gone) and are not asked" ;;
    ja:p_summary) echo "概念 %s / repo %s ページ。" ;;  en:p_summary) echo "%s concept / %s repo pages." ;;
    ja:r_usage) echo "引数は 場所 関数 概念 型 問い 結果 [ズレ] [備考] の 6〜8 個" ;;
    en:r_usage) echo "expected 6-8 args: place function concepts type question result [miss] [note]" ;;
    ja:r_type) echo "型は trace / edge のどちらか" ;;   en:r_type) echo "type must be trace or edge" ;;
    ja:r_result) echo "結果は dunno / skip のどちらか。hit / partial / miss は --verdict から決まる(手動は --free)" ;;
    en:r_result) echo "result must be dunno or skip; hit / partial / miss are derived from --verdict (or use --free)" ;;
    ja:r_nokeys) echo "鍵が無い。keys.sh で先に鍵を置いてから --verdict で判定する" ;;
    ja:r_nopending) echo "next.sh の決定(pending)が無いので書かない(exit 7)。先に next.sh を回す。手で書くなら --free" ;;
    en:r_nopending) echo "no decision from next.sh (pending); not recorded (exit 7). Run next.sh first, or use --free" ;;
    ja:r_keysstale) echo "鍵が別の問いのもの(next.sh を回した後に置いていない)。keys.sh で置き直す(exit 7)" ;;
    en:r_keysstale) echo "the keys belong to another question (fixed before this next.sh run). Fix them again with keys.sh (exit 7)" ;;
    ja:t_locked) echo "別の tag.sh がこの repo で動いている(hook か --tag)。終わってからもう一度" ;;
    en:t_locked) echo "another tag.sh is running for this repository (the hook or --tag); retry when it is done" ;;
    en:r_nokeys) echo "no keys; run keys.sh first, then judge with --verdict" ;;
    ja:r_verdict) echo "--verdict は鍵の数と同じ個数の yes / no / contra をコンマ区切りで" ;;
    en:r_verdict) echo "--verdict needs one of yes / no / contra per key, comma-separated" ;;
    ja:r_missing) echo "触れていない" ;;          en:r_missing) echo "not mentioned" ;;
    ja:r_contra) echo "逆" ;;                    en:r_contra) echo "contradicted" ;;
    ja:r_keys_of) echo "鍵 %d / %d" ;;           en:r_keys_of) echo "keys %d / %d" ;;
    ja:r_keys_show) echo "鍵(答えたあとに見せる。行は問うた関数の中):" ;;  en:r_keys_show) echo "Keys (shown only after the answer; lines are inside the asked function):" ;;
    ja:st_tent) echo "仮" ;;                    en:st_tent) echo "tentative" ;;
    ja:r_hint) echo "解説が要るなら「/hidane さっきの問いで触れていなかった所」のように聞く(地図に合わせて説明する)" ;;
    en:r_hint) echo "for an explanation, ask in words: \"/hidane the part I missed in the last question\" (explained at your level)" ;;
    ja:k_nopending) echo "next.sh の決定(pending)が無い。先に next.sh を回す" ;;
    en:k_nopending) echo "no pending decision from next.sh; run next.sh first" ;;
    ja:k_count) echo "鍵は 2〜5 個" ;;           en:k_count) echo "give 2-5 keys" ;;
    ja:k_empty) echo "空の鍵" ;;                 en:k_empty) echo "empty key" ;;
    ja:k_reason) echo "鍵 %d は理由を含む(「ので」「because」)。鍵は起きる結果だけ(何を返す、何が呼ばれる、どこで抜ける)" ;;
    en:k_reason) echo "key %d carries a reason (\"because\"). A key is only an outcome (what is returned, what is called, where it exits)" ;;
    ja:k_saved) echo "鍵 %d 個を固定した(ユーザーには見せない)" ;; en:k_saved) echo "%d keys fixed (do not show them to the user)" ;;
    ja:k_cat) echo "鍵 %d に種別が無い。「返り値: 」「分岐: 」「呼び出し: 」「順序: 」「状態: 」のどれかで始める" ;;
    en:k_cat) echo "key %d has no kind. Start it with \"return: \", \"branch: \", \"call: \", \"order: \" or \"state: \"" ;;
    ja:k_c_ret) echo "返り値" ;;     en:k_c_ret) echo "return value" ;;
    ja:k_c_branch) echo "分岐" ;;    en:k_c_branch) echo "branch" ;;
    ja:k_c_call) echo "呼び出し" ;;  en:k_c_call) echo "call" ;;
    ja:k_c_order) echo "順序" ;;     en:k_c_order) echo "order" ;;
    ja:k_c_state) echo "状態" ;;     en:k_c_state) echo "state" ;;
    ja:k_p_ret) echo "何を返すか" ;;            en:k_p_ret) echo "what it returns" ;;
    ja:k_p_branch) echo "どの条件でどちらへ進むか" ;;  en:k_p_branch) echo "which way it goes at the condition" ;;
    ja:k_p_call) echo "何を呼ぶか" ;;            en:k_p_call) echo "what it calls" ;;
    ja:k_p_order) echo "どの順で起きるか" ;;       en:k_p_order) echo "in what order things happen" ;;
    ja:k_p_state) echo "何が書き換わるか" ;;       en:k_p_state) echo "what gets changed" ;;
    ja:k_end) echo "問いの結び: 「%s」" ;;   en:k_end) echo "Question ending: \"%s\"" ;;
    ja:k_end_note) echo "(問いの最後の文をこの結びで終える。「答えには…を含めて」のような誘導、種別の名前、数は書かない)" ;;
    en:k_end_note) echo "(end the question's last sentence with this; no \"include in your answer\" line, no kind names, no counts)" ;;
    ja:k_e_ret) echo "何を返しますか" ;;                 en:k_e_ret) echo "what does it return?" ;;
    ja:k_e_call) echo "どの関数が呼ばれますか" ;;        en:k_e_call) echo "which functions are called?" ;;
    ja:k_e_order) echo "何がどの順で起きますか" ;;       en:k_e_order) echo "what happens, in what order?" ;;
    ja:k_e_state) echo "何が書き換わりますか" ;;         en:k_e_state) echo "what is changed?" ;;
    ja:k_e_callorder) echo "どの関数がどの順で呼ばれますか" ;;  en:k_e_callorder) echo "which functions are called, in what order?" ;;
    ja:k_e_branch) echo "。そうなる条件も添えてください" ;;  en:k_e_branch) echo " Include the condition that makes it so." ;;
    ja:k_noprim) echo "鍵が分岐だけ。聞くもの(返り値 / 呼び出し / 順序 / 状態)の鍵が 1 つ以上要る" ;;
    en:k_noprim) echo "only branch keys. Add at least one key for the thing asked (return / call / order / state)" ;;
    ja:k_one) echo "聞くものが %d つ(%s)。問いは 1 つを聞く(返り値 / 呼び出し / 順序 / 状態のどれか。呼び出しと順序は「どの順で呼ばれるか」として一緒に可)。分岐はそれを決めるものとして添える" ;;
    en:k_one) echo "%d things asked (%s). A question asks one thing (return / call / order / state; call and order together are allowed as \"in what order\"). Branch keys only support it" ;;
    ja:a_usage) echo "問いの全文を 1 つ渡す" ;;   en:a_usage) echo "pass the full question text as one argument" ;;
    ja:a_nokeys) echo "鍵が無い。先に keys.sh を回す" ;;  en:a_nokeys) echo "no keys yet; run keys.sh first" ;;
    ja:a_lines) echo "問いは 4 行以内(%s 行ある)" ;;  en:a_lines) echo "a question is at most 4 lines (got %s)" ;;
    ja:a_head) echo "1 行目に場所(ファイル名)と関数名を書く: %s" ;;  en:a_head) echo "line 1 must name the file and the function: %s" ;;
    ja:a_code) echo "2 行目以降にコードの式や呼び出しの形がある(%s)。言葉で言い換える" ;;  en:a_code) echo "line 2+ contains a code expression or call syntax (%s); say it in words" ;;
    ja:a_lineno) echo "2 行目以降に行番号がある(%s)。問いに行番号は書かない" ;;  en:a_lineno) echo "line 2+ contains a line number (%s); never put line numbers in the question" ;;
    ja:a_callee) echo "呼び出しの鍵にある名前 %s が問いに出ている。呼ぶ関数の名前は答えなので書かない" ;;  en:a_callee) echo "%s appears in a call key and in the question; the callee's name is the answer, do not write it" ;;
    ja:a_end) echo "最後の行が keys.sh の結び「%s」で終わっていない" ;;  en:a_end) echo "the last line does not end with the ending keys.sh gave: \"%s\"" ;;
    ja:r_noquestion) echo "問いが ask.sh を通っていない。keys.sh → ask.sh の順で通してから記録する" ;;
    en:r_noquestion) echo "the question did not go through ask.sh; run keys.sh then ask.sh before recording" ;;
    ja:rs_dispute) echo "異議" ;;               en:rs_dispute) echo "dispute" ;;
    ja:h_key) echo "鍵" ;;                    en:h_key) echo "key" ;;
    ja:r_dispute_usage) echo "--dispute <鍵番号> <理由>" ;;  en:r_dispute_usage) echo "--dispute <key number> <reason>" ;;
    ja:r_nolast) echo "異議を付けられる記録が無い(直前の問いの鍵が残っていない。異議は直前の記録にだけ付けられる)" ;;
    en:r_nolast) echo "nothing to dispute (no keys kept from the last question; a dispute applies only to the most recent record)" ;;
    ja:r_nokeyn) echo "鍵 %s は無い(1〜%s)" ;;  en:r_nokeyn) echo "no key %s (1-%s)" ;;
    ja:r_disputed) echo "異議を記録した。値と状態は変わらない(次にこの関数を問うとき、鍵を作る側に見せる)" ;;
    en:r_disputed) echo "dispute recorded. Value and state do not change (it is shown when keys are next made for this function)" ;;
    ja:i_start) echo "登録: %s(%s)" ;;            en:i_start) echo "registering: %s (%s)" ;;
    ja:i_noinstall) echo "install.sh が見つからない。<skill>/HOME か scripts/ の 1 つ上に要る" ;;
    en:i_noinstall) echo "install.sh not found (expected via <skill>/HOME or one level above scripts/)" ;;
    ja:i_done) echo "登録した: %s。記録は %s。次の commit から hook が動く。概念が付いたら /hidane で一問" ;;
    en:i_done) echo "registered: %s. Records in %s. The hook runs from the next commit; once concepts are tagged, /hidane asks one question" ;;
    ja:k_range) echo "鍵 %d の行(@%s)が、問う関数の範囲 %s の外。鍵はこの関数の行にある事実だけ(呼んだ関数の中身は別の問い)" ;;
    en:k_range) echo "key %d points at @%s, outside the asked function's range %s. Keys are facts on this function's own lines (what a callee does inside is another question)" ;;
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
    ja:t_bg) echo "候補 %d 件。背景で概念を付けている(%d 束、1 束 1 分前後)。終わると %s に集計 1 行。地図は次の /hidane から" ;;
    en:t_bg) echo "%d candidates. Tagging in the background (%d batches, about a minute each). A summary line lands in %s when done; the map picks it up on the next /hidane" ;;
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
# 記録の置き場の名前。基本は repo の basename。同じ名前で別の場所の repo が先に居れば basename-<数字> に分ける(-ef で同じ場所かを見る。大文字小文字だけ違う名前は同じ場所)
hidane_repo_key() {
  b=$(basename "$1"); pf="$ROOT/$b/path"
  if [ -f "$pf" ]; then p=$(cat "$pf"); if [ -d "$p" ] && ! [ "$p" -ef "$1" ]; then printf '%s-%s\n' "$b" "$(printf '%s' "$(cd "$1" && pwd -P)" | cksum | cut -d' ' -f1)"; return; fi; fi
  printf '%s\n' "$b"
}
# 記号 → 表示。awk に渡す用
label_state() { case "$1" in known) L st_known ;; fuzzy) L st_fuzzy ;; unknown) L st_unknown ;; unasked) L st_unasked ;; *) echo "$1" ;; esac; }
