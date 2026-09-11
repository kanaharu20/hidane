# hidane 🔥

[English](README.md)

自分のコードのうち、どこを理解していて、どこをまだ確かめていないのかを地図にする。
地図は二人が読む。自分と、Claude。

AI にコードを書かせると、動くものは増えるのに、自分が説明できる範囲は増えない。
その差を、点数ではなく色で見えるようにしたかった。そして同じ地図を Claude にも読ませれば、
解説の粒度がその人に合う。知っていることは飛ばし、前に間違えた所から話す。

<p align="center">
  <img src="docs/graph.svg" alt="架空のデータで描いた地図。2 リポジトリ、42 概念。青緑=理解、黄=曖昧、赤=非理解、暗い灰=未出題" width="820">
</p>

## 何が起きるか

commit するたび、触った関数に「概念」が付く(境界条件、部分失敗の巻き戻し、条件変数の待機と通知、など)。
Claude Code で `/hidane` と打つと、その中から関数が 1 つ選ばれ、一問だけ出る。

```
src/main.c:19 is_valid_num
引数に文字列 "+5" を渡したとき、この関数は何を返しますか。
```

自分の言葉で答える。「分からない」も答え。

```
当たり(鍵 2 / 2)
| 2026-09-09 09:54 | src/main.c:19-33 | is_valid_num | 入力検証, 境界条件 | trace | "+5" を渡すと何を返す | hit |  |  |
```

正解の要素は答える前に 2〜5 個「鍵」として固定されていて、鍵ごとに ある / ない / 逆 を判定する。
足りなければ「部分(鍵 3 / 4)、触れていない: L28-29」と行番号だけ返る。中身は教えない。読みに行く。
解説も総括も出ない。それが問う側の流儀。

答えが溜まると Obsidian の Graph view で概念に色が付く。理解は青緑、曖昧は黄、非理解は赤、まだ問われていないものは消灯。
信号機と同じ。最初はほぼ全部が消えていて、答えるたびに 1 つずつ灯る。

解説が欲しいときは `/hidane --explain printf` のように頼む。Claude は先に地図を読む。
理解している概念は名前も出さず、非理解の概念は前に間違えた所から丁寧に、自分の関数を例にして話す。
printf のように地図に無いものは、その場で近い概念に結びつける。解説を読んでも色は変わらない。読んだことは理解の証拠ではないから。

## 試す

git、[Claude Code](https://claude.com/claude-code)、できれば [Obsidian](https://obsidian.md)。

```sh
git clone git@github.com:kanaharu20/hidane.git ~/hidane
cd 使いたいリポジトリ && sh ~/hidane/install.sh
```

言語(en / ja)を聞かれ、`/hidane` が登録され、このリポジトリに hook が置かれ、全関数に概念が付き(1 分前後)、
地図が `~/Documents/hidane` にできる。Obsidian でそのフォルダを「Open folder as vault」で開く。あとは `/hidane`。

| | |
|---|---|
| `/hidane` | 一問 |
| `/hidane --explain <対象>` | 自分に合わせた解説。関数でも概念でも printf でも |
| `/hidane --map` | 概念ごとの値と状態の表 |
| `/hidane --vault` | 地図を作り直して Obsidian で開く |
| `/hidane --lint` | 似た概念名を統合(3 日に一度は自動) |
| `/hidane --update` | 最新版にして記録を移行 |

commit のとき、触った関数のソースが自分の Claude(`claude -p`)に送られて概念名が返る。hook はそのたびに 1 行出すので黙って動くことはない。
`HIDANE_HOOK_OFF=1` か `install.sh --unhook` で止まる。記録と地図は手元にだけある。費用は自分の Claude Code の範囲で、40 関数なら最初のタグ付けが 5 回前後。

詳しい手順と困ったときの対処は [docs/GUIDE.ja.md](docs/GUIDE.ja.md)。

## 決めていること

点数を出さない。点数は興味を下げ、注意をコードから自分に向ける(Butler 1988、Kluger & DeNisi 1996)。色は「このコードのどこが灯っているか」であって、成績ではない。

記録は追記だけ。値も状態も保存せず、毎回 `log.md` から計算する。概念名の統合も別名で行い、元の行は書き換えない。地図は消しても作り直せる。

LLM に判断させるのは 3 か所だけ。関数にどの概念を付けるか、どの概念名が同じ意味か、解説の粒度。
前の 2 つは既存の一覧から選ばせ、形式はスクリプトが検査する。当たりかどうか、次に何を問うか、問いの型は、全部スクリプトが決める。
前身の reflect で、Claude に任せた判断と文面の指示は同じ入力でもぶれた。だから決めるのはスクリプト、Claude が埋めるのは穴だけにした。

「まだ問うていない」と「問うて分からなかった」は別の状態。混ぜない。問いは後者から出す。

概念はその人に属し、関数はリポジトリに属する。A で分からなかった概念は、B の commit で最初に問われる。

仕組みの細部は [docs/DESIGN.ja.md](docs/DESIGN.ja.md)。

## できないこと、まだのこと

- 作者 1 人が 2 リポジトリで 25 問答えた段階。重み(1 / 2 / 3)、閾値(±4)、忘却(30 日)は全部仮置き
- 「何をするか」型の問い(summary)の判定は、まだ Claude の読みに頼っている。説明からコードを生成して照合する方式(CGBG)は入れていない
- 依存を git と POSIX sh だけにした代わりに、sh と awk が密で読みにくい。135 件の検査がそれを支えている
- Linux は動くはずだが未検証。`/hidane --vault` は macOS の `open` を使う
- Claude が SKILL の手順をどこまで守るかは、実走の会話記録で確かめている。文面の指示は効かないことがある

## 開発

```sh
sh tests/run_all.sh     # 135 件。LLM は呼ばない。数秒
```

新しい検査は、実装を壊して落ちるのを見てから信じる。`run_all.sh` は検査の数がこの README とずれると落ちる。

| 変数 | 既定 | |
|---|---|---|
| `HIDANE_LANG` | config、無ければ en | 表示とプロンプトの言語 |
| `HIDANE_ROOT` | `~/.claude/hidane` | 記録 |
| `HIDANE_VAULT` | `~/Documents/hidane` | 地図 |
| `HIDANE_W_TRACE` / `_EDGE` / `_SUMMARY` | 1 / 2 / 3 | 型の重み |
| `HIDANE_THRESHOLD` / `HIDANE_CAP` | 4 / 6 | 閾値と上限 |
| `HIDANE_FRESH_DAYS` | 30 | 忘却 |
| `HIDANE_MAX_FUNCS` | 8 | 1 回の LLM 呼び出しに載せる関数 |
| `HIDANE_LINT_DAYS` | 3 | lint の間隔 |
| `HIDANE_HOOK_OFF` | | 1 で hook を止める |

reflect(前身)の記録は形が違うので自動では移らない。[docs/MIGRATING-from-reflect.ja.md](docs/MIGRATING-from-reflect.ja.md)。
版は [CHANGELOG.md](CHANGELOG.md)。

## ライセンス

MIT
