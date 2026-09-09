<h1 align="center">hidane 🔥</h1>

<p align="center">
  <b>自分のコードのうち、どこを理解していて、どこが霧なのかを地図にする。</b><br>
  A map of what you actually understand in your own code — built only from your answers.
</p>

<p align="center">
  <img alt="tests" src="https://img.shields.io/badge/tests-83%20passing-brightgreen">
  <img alt="deps" src="https://img.shields.io/badge/deps-git%20%2B%20POSIX%20sh-blue">
  <img alt="llm" src="https://img.shields.io/badge/LLM%20decisions-2%20places-orange">
  <img alt="status" src="https://img.shields.io/badge/status-alpha-lightgrey">
</p>

---

AI にコードを書かせると、動くものは増えるのに、自分が説明できる範囲は増えない。
hidane は、あなたのコードの関数について**一問だけ**投げ、答えを記録し、
記録だけから「理解 / 曖昧 / 非理解 / 霧」を計算して、Obsidian のグラフに**色**で見せる。点数は出さない。

## Demo

```
$ /hidane

  src/main.c:19 is_valid_num
  引数に文字列 "+5" を渡したとき、この関数は何を返しますか。

> false を返します

  当たり

  | 2026-09-09 09:54 | src/main.c:19-33 | is_valid_num | 入力検証, 境界条件 | 追う | "+5" を渡すと何を返す | 当たり |  |  |
```

これで終わり。解説も総括も出ない。Obsidian を開くと「入力検証」のノードが灰(霧)から黄(曖昧)に変わっている。

```
$ /hidane --map

| 概念             | 値 | 証拠 | 最終       | 状態   | repo         |
|------------------|----|------|------------|--------|--------------|
| 停止フラグの伝搬 | -6 |  4   | 2026-09-09 | 非理解 | codexion     |
| 境界条件         | -2 |  4   | 2026-09-09 | 曖昧   | RAG,codexion |
| 入力検証         | +1 |  1   | 2026-09-09 | 曖昧   | RAG,codexion |
| 転置索引の構築   | +0 |  0   | -          | 霧     | RAG          |
```

## Features

- **一問だけ。** 一回の呼び出しで一関数、一問。「分からない」も答え。答え直しは記録しない
- **解説しない。** 問う前にコードを説明しない。ズレは行番号で指すだけ。点数も評価語も出さない
- **記録だけが真実。** 値も状態も保存しない。毎回 `log.md` から計算する。地図は消しても作り直せる
- **霧が育つ。** commit のたびに、触った関数に概念タグが付く。問われていない関数は灰色の霧として地図に出る
- **リポジトリをまたぐ。** 概念はあなたに属し、関数はリポジトリに属する。A で分からなかった概念は、B の commit で最初に問われる
- **LLM の判断は 2 か所だけ。** 「この関数はどの概念か」と「どの概念名が同じ意味か」。状態・型・順位・記録の形はスクリプトが決める
- **依存は git と POSIX sh。** LLM 呼び出しは Claude Code(`claude -p`)。地図の表示は Obsidian(無くても Markdown として読める)

## Quick start

必要なもの: git、POSIX sh、[Claude Code](https://claude.com/claude-code)。地図を見るなら [Obsidian](https://obsidian.md)。

```sh
git clone git@github.com:kanaharu20/hidane.git ~/CODE/hidane
sh ~/CODE/hidane/install.sh --skill                     # /hidane を Claude Code に登録

cd ~/your-repo
sh ~/CODE/hidane/install.sh --hook                      # commit 後にタグ付けする hook を置く
sh ~/CODE/hidane/scripts/tag.sh --all                   # 最初に一度、全体に霧を敷く
```

Obsidian で `~/Documents/hidane` を「Open folder as vault」で開く(初回だけ。以降は `/hidane --vault`)。
Graph view で 理解 = 黄緑、曖昧 = 黄、非理解 = 赤、霧 = 灰 に色が付く。

## Usage

| コマンド | すること |
|---|---|
| `/hidane` | 一問出る。答える。記録される |
| `/hidane --map` | 概念ごとの値・状態・repo の表 |
| `/hidane --vault` | 地図を作り直して Obsidian で開く |
| `/hidane --lint` | 似た概念名を統合する(3 日に一度は自動で走る) |
| `git commit` | いつも通り。背景で触った関数に概念が付く。commit は止まらない |

スクリプトを直接使うこともできる。すべて `--help` で使い方が出る。

```sh
sh scripts/map.sh            # 表(--tsv で機械向け)
sh scripts/pages.sh          # Obsidian vault を生成
sh scripts/next.sh           # 次に問う関数と型を決める
sh scripts/tag.sh --all      # 全関数にタグ付け(--commit REV でそのコミット分)
sh scripts/lint.sh --dry-run # 統合のプロンプトを見る
```

## How it works

```
 git commit ─▶ hook ─▶ tag.sh ─▶ functions.md   関数 → 概念(霧が増える)
                                       │
 /hidane ─▶ next.sh(次の関数と型を決める)◀┘
        ─▶ Claude が一問(解説なし)
        ─▶ あなたが答える
        ─▶ Claude が実コードと照合、ズレなら行番号
        ─▶ record.sh ─▶ log.md ─▶ pages.sh ─▶ Obsidian vault(色が変わる)
```

<details>
<summary><b>状態はどう決まるか</b></summary>

保存するのは `log.md` の行だけ。値と状態は毎回そこから計算する。

**値** = 各行の(問いの型の重み × 結果の符号)の合計。1 行ごとに足し、±6 で止める。

| 型 | 重み | 問い |
|---|---|---|
| 追う | 1 | 「この入力のとき何を返す / 何が起きるか」 |
| 追う(境界・変異) | 2 | 空・1 個・末尾・上限、または過去のズレを再現する入力で同じことを問う |
| 要約 | 3 | 「この関数は何をするか」 |

| 結果 | 符号 |
|---|---|
| 当たり | +1 |
| ズレ、分からない | −1 |
| 未回答 | 0(証拠にしない) |

| 状態 | 条件 |
|---|---|
| 理解 | 値 ≥ +4 かつ 最後の答えから 30 日以内 |
| 非理解 | 値 ≤ −4 かつ 30 日以内 |
| 曖昧 | −4 < 値 < +4、または 30 日を過ぎた(値は下げない。確かさだけ落ちる) |
| 霧 | 証拠が無い(タグだけ、または未回答だけ) |

難しい問いに当たると大きく上がり、易しい問いを外すと大きく下がる。1 回では状態は動かない。
忘却は時間だけで起こり、答えると戻る。手で状態を変える手段は無い。

</details>

<details>
<summary><b>次にどの関数を問うか</b></summary>

概念の順位は**全リポジトリの記録**から: 非理解 > 曖昧 > 霧、同じ状態なら値の低い順。理解の概念からは出さない。
候補の関数は**今いるリポジトリ**の、まだ問われていないものから。

問いの型も `next.sh` が決める(過去にズレのある概念なら 追う(境界・変異))。決定は `pending` に置かれ、
`record.sh` はそれと一致する記録しか受け付けない。Claude が変えられるのは問いの文だけ。

</details>

<details>
<summary><b>概念名の統合(lint)</b></summary>

タグ付けは自由に新しい名前を作れるので、似た名前が増える。数日に一度、Claude に概念一覧を見せて
「同じ意味の組」を挙げさせ、`aliases.md` に「旧名 → 新名」を 1 行足す。

- **`log.md` は書き換えない。** 読む側(`resolve.sh`)が別名を解いて読む
- 統合後の値は両方の証拠の合計。repo は合わさり、関連は付け直される
- 新名は既存の名前に限る。同名・存在しない名前・循環はスクリプトが捨てる
- 間違った統合は `aliases.md` の行を消せば戻る

</details>

## Configuration

すべて環境変数。**定数は全部仮置き**で、使いながら決める段階。

| 変数 | 既定 | 意味 |
|---|---|---|
| `HIDANE_ROOT` | `~/.claude/hidane` | 記録の場所 |
| `HIDANE_VAULT` | `~/Documents/hidane` | 地図(Obsidian vault)の場所 |
| `HIDANE_W_TRACE` / `HIDANE_W_EDGE` / `HIDANE_W_SUMMARY` | 1 / 2 / 3 | 問いの型の重み |
| `HIDANE_THRESHOLD` | 4 | 理解 / 非理解 の閾値 |
| `HIDANE_CAP` | 6 | 値の上限・下限 |
| `HIDANE_FRESH_DAYS` | 30 | これを過ぎると曖昧に落ちる |
| `HIDANE_MAX_FUNCS` | 8 | 1 回の LLM 呼び出しに載せる関数の数(候補が尽きるまで繰り返す) |
| `HIDANE_LINT_DAYS` | 3 | lint の間隔 |
| `HIDANE_MODEL` | (Claude Code の既定) | タグ付けと lint に使うモデル |
| `HIDANE_HOOK_OFF` | | 1 で hook を止める |

<details>
<summary><b>どこに何があるか</b></summary>

```
~/.claude/hidane/                 記録(一次データ。消すと戻らない)
  <repo>/log.md                     問いと答え。1 回 1 行。唯一の書き込み口は record.sh
  <repo>/functions.md               commit 時に付いた「関数 → 概念」
  <repo>/pending                    next.sh が決めた次の一問
  aliases.md                        概念の別名(旧名 → 新名)
  .lint-stamp                       最後に lint を回した日
  hook.log                          hook の出力
~/Documents/hidane/               地図(派生データ。消しても pages.sh で戻る)
  concepts/<概念>.md                概念 1 つ = 1 ページ。人は書かない
  repos/<repo>.md                   そのリポジトリに出た概念
  index.md                          全概念の表
  .obsidian/graph.json              Graph の色(初回だけ生成)
```

</details>

## Philosophy

- **LLM に決めさせない。** 前身の reflect で、文面の指示(「前置きを書くな」)は 10 回中 0 回しか効かず、Claude に組み立てさせた文面や判定はぶれた。だから決めるのはスクリプト、Claude が埋めるのは「一覧から選ぶ」穴だけ
- **点数を見せない。** 点数は興味を下げ、注意をコードから自分に向ける(Butler 1988、Kluger & DeNisi 1996)。色は「このコードの霧」であって「あなたの成績」ではない
- **霧と非理解は別。** 「まだ確かめていない」と「確かめて分からなかった」を混ぜない。出題は非理解から
- **記録は書き換えない。** 統合も別名で行い、一次記録は追記だけ。壊れる経路を作らない
- **検査は空振りする。** 新しい検査を書いたら、実装を壊して落ちることを確かめてから信じる。83 件の L0 検査はすべてそうしてある

## Development

```sh
sh tests/run_all.sh          # 83 件。LLM なし、数秒
sh tests/test_tag.sh         # LLM 呼び出しは HIDANE_CLAUDE で偽物に差し替えて検査
```

| 部品 | 役割 | LLM |
|---|---|---|
| `scripts/map.sh` | 値と状態の表 | |
| `scripts/pages.sh` | Obsidian vault を生成(冪等、掃除つき) | |
| `scripts/next.sh` | 次の関数と型を決めて `pending` に置く | |
| `scripts/record.sh` | `log.md` に 1 行追記。`pending` と照合 | |
| `scripts/tag.sh` | 関数に概念を付ける | ● |
| `scripts/lint.sh` | 似た概念名を統合(`aliases.md` に追記) | ● |
| `scripts/resolve.sh` | 別名を解くフィルタ | |
| `scripts/open.sh` | vault を作り直して Obsidian で開く | |
| `scripts/scope.sh` | commit が触った関数を 15 言語で切り出す([reflect](https://github.com/kanaharu20/reflect) から) | |
| `hooks/post-commit` | commit 後に tag.sh を背景で走らせる。何が起きても commit は通す | |
| `SKILL.md` | Claude Code の `/hidane` の手順 | 問いの文と照合 |

## Related work

[reflect](https://github.com/kanaharu20/reflect) の後継。関数の切り出しなどの機構を引き継ぎ、記憶の形と状態の計算を作り直した。

- **Knowledge Tracing**(BKT 以降): 解答の時系列から概念ごとの習得状態を推定する。「1 回の正解はまぐれかもしれない」を閾値で取り込んだ
- [KCGen-KT](https://arxiv.org/abs/2502.18632): LLM によるコードへの概念(KC)自動付与。既存一覧を見せて選ばせる作法
- [Explain in Plain English / CGBG](https://arxiv.org/abs/2403.06050): 説明文を採点しない判定(要約型の判定に予定)
- Open Learner Model / [Mastery Grids](https://people.cs.pitt.edu/~hosseini/papers/ectel2014.pdf): 概念単位の理解の可視化
- [Anthropic, How AI Impacts Skill Formation](https://arxiv.org/abs/2601.20245): AI 利用で理解が落ちる条件と、保たれる使い方
- Butler 1988、Kluger & DeNisi 1996: 点数と自己注意がフィードバックの効果を下げる

## Status

alpha。作者 1 人の実データ(2 リポジトリ、21 問、39 概念)で毎日回している段階。

- 定数(重み、閾値、忘却)は仮置き
- 概念名は日本語。プロンプトを変えれば他言語でも動くはずだが未検証
- 「要約」型の判定(CGBG 方式)は未実装。今は「追う」型のみ
- `tag.sh` と `lint.sh` は `claude -p` を呼ぶ。関数 8 個ごとに 1 回、1 回 10〜60 秒

## License

未定(TBD)。
