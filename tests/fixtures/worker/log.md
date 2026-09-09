# hidane — worker

| 日時 | 場所 | 関数 | 概念 | 型 | 問い | 結果 | miss | 備考 |
|---|---|---|---|---|---|---|---|---|
| 2026-09-03 14:28 | src/pool.c:57-68 | take_slot | 境界条件, 資源獲得の順序 | trace | worker が 1 人のときの slot 取得 | dunno |  |  |
| 2026-09-03 14:35 | src/pair.c:14-27 | bind_pair | 隣接要素の対応付け | summary | 左右の slot の紐付け | hit |  |  |
| 2026-09-05 15:03 | src/log.c:20-29 | log_line | 停止フラグの伝搬 | trace | 停止後のログ抑止 | miss | 停止後も1行出る |  |
| 2026-09-05 15:32 | src/watch.c:22-38 | check_expiry | タイムアウト判定 | trace | 完了済み worker の期限判定 | dunno |  |  |
| 2026-09-05 15:54 | src/heap.c:3-16 | heap_push | 境界条件, ヒープ操作 | trace | size2でのheap_push | dunno |  |  |
| 2026-09-05 16:02 | src/backoff.c:8-19 | backoff_until | 時刻の単位換算 | trace | timeval→timespec換算 | dunno |  |  |
| 2026-09-06 01:25 | src/backoff.c:8-19 | backoff_until | 時刻の単位換算 | trace | timeval→timespec換算 | dunno |  | 再確認 |
| 2026-09-06 12:36 | src/stop.c:3-41 | request_stop | 条件変数の一斉起床, 停止フラグの伝搬 | summary | 停止シグナルの伝搬 | miss | wake_all の書き忘れ |  |
| 2026-09-06 12:53 | src/app.c:57-76 | run | 部分失敗の巻き戻し | summary | runの失敗経路と解放 | miss | init_shared失敗時の解放出し分け |  |
| 2026-09-07 11:08 | src/stop.c:49-55 | wait_until_stopped | 条件変数の待機と通知 | trace | 停止待ちのbroadcast取りこぼし | hit |  |  |
| 2026-09-07 13:46 | src/pool.c:81-86 | take_two_slots | 境界条件, 資源獲得の順序 | trace | worker が 1 人のときの待機と解放 | skip |  |  |
| 2026-09-07 14:05 | src/main.c:69-70 | parse_numbers | 入力検証 | trace | 引数の下限チェック | skip |  |  |
| 2026-09-07 23:18 | src/shared.c:37-56 | init_shared | 部分失敗の巻き戻し | trace | init_shared の巻き戻し | hit |  |  |
| 2026-09-08 17:33 | src/slot.c:27-47 | init_slots | 部分失敗の巻き戻し | trace | init_slots の部分失敗巻き戻し | hit |  |  |
