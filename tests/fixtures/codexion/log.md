# hidane — /Users/kanemitsuyuuhi/CODE/42tokyo/codexion

| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | ズレ | 備考 |
|---|---|---|---|---|---|---|---|---|
| 2026-09-03 14:28 | src/dongle_acquire.c:57-68 | acquire | 境界条件, 資源獲得の順序 | 追う | coder1人時のdongle取得 | 分からない |  |  |
| 2026-09-03 14:35 | src/coder.c:14-27 | bind_dongles | 隣接要素の対応付け | 要約 | coder左右のdongle紐付け | 一致 |  |  |
| 2026-09-05 15:03 | src/log.c:20-29 | log_line | 停止フラグの伝搬 | 追う | 停止後のログ抑止 | ズレ | 停止後も1行出る |  |
| 2026-09-05 15:32 | src/monitor.c:22-38 | check_burnout | タイムアウト判定 | 追う | 達成済みcoderのburnout判定 | 分からない |  |  |
| 2026-09-05 15:54 | src/heap.c:3-16 | heap_push | 境界条件, ヒープ操作 | 追う | size2でのheap_push | 分からない |  |  |
| 2026-09-05 16:02 | src/dongle_cooldown.c:8-19 | cooldown_until | 時刻の単位換算 | 追う | timeval→timespec換算 | 分からない |  |  |
| 2026-09-06 01:25 | src/dongle_cooldown.c:8-19 | cooldown_until | 時刻の単位換算 | 追う | timeval→timespec換算 | 分からない |  | 再確認 |
| 2026-09-06 12:36 | src/stop.c:3-41 | request_stop | 条件変数の一斉起床, 停止フラグの伝搬 | 要約 | 停止シグナルの伝搬 | ズレ | wake_all_dongles の書き忘れ |  |
| 2026-09-06 12:53 | src/codexion.c:57-76 | run | 部分失敗の巻き戻し | 要約 | runの失敗経路と解放 | ズレ | init_shared失敗時の解放出し分け |  |
| 2026-09-07 11:08 | src/stop.c:49-55 | wait_until_stopped | 条件変数の待機と通知 | 追う | 停止待ちのbroadcast取りこぼし | 当たり |  |  |
| 2026-09-07 13:46 | src/dongle_acquire.c:81-86 | acquire_two_dongles | 境界条件, 資源獲得の順序 | 追う | coder1人時の待機と解放 | 未回答 |  |  |
| 2026-09-07 14:05 | src/main.c:69-70 | parse_numbers | 入力検証 | 追う | num_compile_req の下限チェック | 未回答 |  |  |
| 2026-09-07 23:18 | src/shared.c:37-56 | init_shared | 部分失敗の巻き戻し | 追う | init_shared の巻き戻し | 当たり |  |  |
| 2026-09-08 17:33 | src/dongle.c:27-47 | init_dongles | 部分失敗の巻き戻し | 追う | init_dongles の部分失敗巻き戻し | 当たり |  |  |
