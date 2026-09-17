# 開発に加わる人へ

fork する、PR を送る、PR をレビューする人向け。何をする道具かは [README.ja.md](README.ja.md)、なぜこの作りかは [docs/DESIGN.ja.md](docs/DESIGN.ja.md)。ここは「変えるとき」の話。

## まず検査を回す

```sh
sh tests/run_all.sh
```

LLM は呼ばない。検査の中では `claude` を偽の script(`HIDANE_CLAUDE`)に差し替えるので、数秒で終わり、オフラインでも動く。検査は一時的な `HIDANE_ROOT` と `HIDANE_VAULT` に書くので、`~/.claude/hidane` の本物の記録には触れない。

`run_all.sh` は検査の数が `README.md`、`README.ja.md`、`CHANGELOG.md` に書かれた数と違うと落ちる。検査を足したら 3 か所の数を直す。

## 配置

```
scripts/*.sh        本体(POSIX sh + awk。1 ファイル 1 役。下の表)
SKILL.ja.md / .en   /hidane の場で Claude がすること。~/.claude/skills/hidane/SKILL.md に置かれる
hooks/post-commit   git hook の雛形(install.sh が場所を埋める)
install.sh          セットアップ、hook、更新
tests/test_*.sh     script ごとに 1 本、L0(LLM なし)。tests/fixtures は架空の記録
docs/DESIGN*.md     決め事とその理由。docs/GUIDE*.md は使う人の手引き
```

記録はリポジトリの外: `~/.claude/hidane/<repo>/{log.md,functions.md,path,pending,keys}`、`aliases.md`、`explained.md`。地図は `~/Documents/hidane`。

| ファイル | 一言 |
|---|---|
| `hooks/post-commit` | commit 後に tag.sh を背景で呼ぶ。commit は止めない |
| `scripts/scope.sh` | リポジトリを関数単位に切って候補を出す |
| `scripts/tag.sh` | 関数に概念を付けて functions.md に追記する(LLM を呼ぶ 1 か所目) |
| `scripts/map.sh` | log.md から概念ごとの値と状態を毎回計算する |
| `scripts/next.sh` | 次に問う関数を 1 つ選び、pending に書く |
| `scripts/next.awk` | next.sh の順位付け・集中・型の決定(next.sh から awk -f で呼ぶ) |
| `scripts/keys.sh` | 答えを聞く前に正解の要素(鍵)を固定し、「答えに含めるもの」の行を出す |
| `scripts/ask.sh` | 問いの全文を検査して保存する(行数、場所と関数名、式・行番号・呼ぶ関数名の有無、結び) |
| `scripts/init.sh` | 今いるリポジトリを登録する(hook を置き、tag.sh --all --bg を回す) |
| `scripts/record.sh` | 鍵の判定から結果を決めて log.md に 1 行追記する(一次記録の唯一の書き口) |
| `scripts/resolve.sh` | 読むときに概念名を aliases.md で新名に置き換えるフィルタ |
| `scripts/pages.sh` | 地図(Obsidian の vault)を記録から作り直す |
| `scripts/open.sh` | 地図を作り直して Obsidian で開く |
| `scripts/lint.sh` | 似た概念名を統合して aliases.md に書く(LLM を呼ぶ 2 か所目) |
| `scripts/weak.sh` | 弱い所の材料(ズレのある概念、ズレ全件、関数)を集める |
| `scripts/explained.sh` | 解説を求めたことを explained.md に 1 行残す |
| `scripts/lang.sh` | ja/en の表示文字列と、記録の置き場の名前の決め方 |
| `scripts/help.sh` | `/hidane --help` の固定文 |
| `scripts/migrate.sh` | 記録の形式が変わったとき古い log.md を直す |
| `scripts/stats.sh` | 名前を出さない数字だけの要約(フィードバック用) |
| `install.sh` | セットアップ、hook の設置と撤去、更新 |
| `tests/run_all.sh` | 全検査を回し、README の検査数と照合する |

## 変更が壊してはいけない決め事

道具の土台。これを越える PR は、説明にそう書いてもらい、merge 前に話す。

- **log.md は追記だけ。** 追記するのは `record.sh` だけ、書き換えてよいのは `migrate.sh` だけ(`.bak` を残す)。値も状態も保存せず、`map.sh` が毎回行から計算する。
- **状態が動くのは答えたときだけ。** 解説(`explained.sh`、`weak.sh`)は値・状態・色を変えない。手で上書きする口は無い。
- **点数を出さない。** 割合も評価語も出さない。色は「どの概念が灯っているか」で、成績ではない。
- **LLM に判断させるのは 3 か所だけ。** 関数にどの概念を付けるか(`tag.sh`)、どの概念名が同じ意味か(`lint.sh`)、解説の文面(SKILL)。当たり/部分/ズレ も、次に何を問うかも、script が決める。Claude への規則が script で強制できるなら script で強制する。SKILL.md の文面は効かないことがある。
- **記録の語彙は言語に依らない記号**(`known/fuzzy/unknown/unasked`、`trace/edge/summary`、`hit/partial/miss/dunno/skip`)。表示は `scripts/lang.sh` を通す。新しい key には `ja:` と `en:` の両方を書く。
- **鍵は答えを聞く前に固定し、ユーザーには見せない。** 足りない鍵は種別と行番号でだけ指す。

## 移植性

macOS の `/bin/sh` と Linux の `dash` の両方で動くこと。bash 拡張(`[[`、配列)を使わない、`sed -i` を使わない(一時ファイルに書いて `mv`)、GNU だけの awk(`gensub`、名前としての `func`)を使わない、`date` は BSD と GNU の両方が受ける形だけ。検査は macOS で回している。Linux は未検証だが動く想定。

## script を足す・変えるとき

1. 使い方を先頭のコメント(`# 使い方:`)に書く。`--help` はその行を出す。
2. `ROOT` を決めてから `. "$HERE/lang.sh"`。文字列と `hidane_repo_key` はそこから。
3. LLM の出力は検査せずにファイルへ入れない。`tag.sh` と `lint.sh` が 1 行ずつ検査して、落ちた行を stderr に出す形を見る。
4. 記録や Claude から来た文字列を `eval` しない。
5. 検査を書いてから信じる。実装を壊して落ちるのを見てから直す。fixtures は架空の名前(`worker`、`api`)。本物のコードや関数名を `tests/` に貼らない。
6. 記録の形式を変えるなら `migrate.sh` に段を足す(冪等、`.bak` を残す、`.version` を上げる)。`VERSION` と `CHANGELOG.md` も。
7. `SKILL.*.md` を変えたら再配置(`sh install.sh --skill --lang ja`)して、新しい Claude Code のセッションで試す。Claude が手順を守ったかは会話記録を読んで確かめる。決めつけない。

## PR を送るとき

- 1 つの PR に 1 つの変更。何が悪かった(無かった)か、何をどう変えたか、どの検査が押さえているか。
- 自分のブランチで `sh tests/run_all.sh` が `ALL PASS`。
- 人に見える文は両言語で: `README.md` + `README.ja.md`、`docs/GUIDE.md` + `.ja.md`、`SKILL.en.md` + `SKILL.ja.md`、`help.sh`、`lang.sh`。
- `CHANGELOG.md` の次の版に 1 行。
- 本物の記録、本物の関数名、本物のリポジトリ名を diff に入れない(fixtures、docs、例)。README の地図はわざと架空。

## PR をレビューするとき

見る順:

1. 上の決め事を守っているか。特に、新しく log.md に書くもの、状態を保存するもの、点数を出すもの、判断を LLM に渡すものが無いか。
2. 新しい経路に、変更が無ければ落ちる検査があるか。
3. 記録を awk の列で読み、空白を落としているか。項目の中の `|` に耐えるか(record.sh は `｜` に置き換える)。
4. commit が無い、未追跡のファイル、消えたリポジトリ、同名のリポジトリ 2 つ、で動くか(`tag.sh`、`next.sh`、`weak.sh`、`pages.sh` は作業ツリーを確かめる)。
5. 背景の `tag.sh`(hook)と前景のものがぶつからないか(`tag.sh` は repo ごとに鍵を取る)。
6. 両言語、検査の数、CHANGELOG。

## 版

`VERSION` は semver に近い。修正は patch、旗の追加や記録の形式変更(`migrate.sh` の段つき)は minor。`install.sh --update` は `git pull` → skill の再配置 → `migrate.sh` の順なので、どの古い版が書いた記録にも安全に当たらなければならない。

## 不具合を報告するとき

`sh scripts/stats.sh` の出力(数字だけ、名前は出ない)と、`~/.claude/hidane/hook.log` の該当行を貼る。`/hidane` のセッションがおかしかったなら、役に立つのは script の呼び出しとその出力の並びで、それは会話記録にある。
