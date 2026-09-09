# hidane(火種)

自分が書いた(書かせた)コードのうち、どの概念を理解していて、どこが霧なのかを、
問いへの答えだけから計算して Obsidian の地図にする。LLM の判断は概念タグ付けの 1 か所だけ。

## 仕組み

- `<root>/<repo>/log.md` — 問いと答えの記録。唯一の一次記録(1 回 1 行)
- `<root>/<repo>/functions.md` — commit 時に付けた概念タグ(未出題の関数 = 霧の入口)
- `~/Documents/hidane/` — 上の 2 つから毎回生成される Obsidian vault(`HIDANE_VAULT` で変更可)。概念 1 つ = 1 ページ。人は書かない

値・状態は保存しない。毎回計算する。

| 状態 | 条件 |
|---|---|
| 理解 | 値 ≥ +4 かつ最後の答えから 30 日以内 |
| 非理解 | 値 ≤ −4 かつ 30 日以内 |
| 曖昧 | −4 < 値 < +4、または 30 日を過ぎた |
| 霧 | 証拠なし(タグだけ、または未回答だけ) |

値 = Σ(問いの型の重み × 符号)。追う 1 / 追う(境界・変異) 2 / 要約 3。当たり +、ズレ・分からない −、未回答 0。±6 で止める。定数は全部仮置き(環境変数 `HIDANE_*` で変えられる)。

## 部品

| | |
|---|---|
| `scripts/map.sh` | 値と状態の表。`--tsv` で機械向け |
| `scripts/pages.sh` | vault を生成(概念ページ、repo ページ、index、Graph の色) |
| `scripts/tag.sh` | commit が触った関数に概念を付ける(唯一の LLM 呼び出し) |
| `scripts/scope.sh` | commit が触った関数を 15 言語で切り出す(reflect から) |
| `hooks/post-commit` | commit 後に tag.sh を背景で走らせる。commit は止めない |
| `install.sh --hook` | 今の repo に hook を置く |
| `scripts/next.sh` | 次に問う関数を選ぶ(非理解 > 曖昧 > 霧、repo をまたいで概念の順位を見る) |
| `scripts/open.sh` | vault を作り直して Obsidian で開く(`/hidane --vault`) |
| `scripts/record.sh` | 問いと答えを log.md に 1 行追記(唯一の書き込み口) |
| `SKILL.md` | Claude Code の `/hidane`。一関数一問、解説なし、行番号で指す |
| `install.sh --skill` | ~/.claude/skills/hidane に配置 |
| `tests/run_all.sh` | L0 検査(LLM なし、数秒) |

## 使う

```sh
cd your-repo && sh /path/to/hidane/install.sh --hook   # commit のたびに霧が育つ
sh /path/to/hidane/scripts/pages.sh                      # vault を作り直す
```

Obsidian で `~/Documents/hidane` を「Open folder as vault」で開く。Graph view で
理解 = 黄緑、曖昧 = 黄、非理解 = 赤、霧 = 灰。

## 由来

reflect(https://github.com/kanaharu20/reflect)の後継。部品(scope.sh など)を引き継ぎ、
記憶の形と状態の計算を新しくした。先行研究: Knowledge Tracing、KC 自動生成(KCGen-KT)、
Explain in Plain English / CGBG、Open Learner Model、Anthropic "How AI Impacts Skill Formation"。
