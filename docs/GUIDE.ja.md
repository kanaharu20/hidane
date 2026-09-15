# hidane 手順書(日本語)

初めて使う人のための、最初から最後までの手順。README より細かい。

## 0. 前提

| 必要なもの | 確認のしかた |
|---|---|
| macOS または Linux(Linux は動くはずだが作者の環境は macOS) | |
| git | `git --version` |
| POSIX sh(macOS / Linux なら入っている) | |
| [Claude Code](https://claude.com/claude-code)。ログイン済みで `claude` コマンドが通ること | `claude --version` |
| [Obsidian](https://obsidian.md)(地図を見るため。無くても記録と Markdown は生成される) | |
| 対象のコードが **git リポジトリ**であること | `git status` が通る |

対応言語(関数を切り出せる言語): C、C++、Python、JavaScript / TypeScript、Go、Rust、Java、Ruby、PHP、Swift、Kotlin、Shell など 15 言語。

**Claude に送られるもの**: commit 時と `--all` のとき、対象の**関数のソースコード**が `claude -p` で Claude に送られ、概念名が返る。
`/hidane` のときは Claude Code が普通に関数を読む。記録(`~/.claude/hidane/`)と地図(`~/Documents/hidane/`)は手元にだけ置かれ、どこにも送られない。

## 1. 入れる

```sh
git clone git@github.com:kanaharu20/hidane.git ~/hidane
cd ~/your-repo && sh ~/hidane/install.sh
```

`https://github.com/kanaharu20/hidane.git` でも同じ。実行すると:

```
Language / 言語 [en/ja] (en): ja
hidane セットアップ(lang=ja)
  /hidane を登録した: /Users/you/.claude/skills/hidane
  hook を置いた: /Users/you/your-repo/.git/hooks/post-commit
  全関数に概念を付けている(1 分前後)…
tag.sh: 候補 20、呼び出し 3 回、追記 20 行、捨てた 0 行 → /Users/you/.claude/hidane/your-repo/functions.md
次: Obsidian で /Users/you/Documents/hidane を「Open folder as vault」で開く。Claude Code で /hidane
```

- 「別の post-commit hook があるので触らない」と出たら、既存の hook の末尾に `sh ~/hidane/hooks/post-commit` を呼ぶ行を自分で足す
- 「claude コマンドが無い」と出たら、Claude Code を入れて `claude` が通るようにしてから、もう一度 `install.sh`
- 別のリポジトリでも使うなら、そのリポジトリの中でもう一度 `install.sh`(言語は 2 回目から聞かれない)

## 2. 地図を開く(初回だけ)

Obsidian を起動 → 左下の vault 切替 → **Open folder as vault** → `~/Documents/hidane` を選ぶ。
左のファイル一覧に `concepts/`、`repos/`、`index.md` が見える。左の **Graph view** アイコンを押すと、概念のノードが出る。

| 色 | 意味 |
|---|---|
| 青緑寄り | 理解(値 +4 以上で、30 日以内に当たっている) |
| 黄のあたり | 曖昧(当たりと外れが混ざっている、または 30 日以上確かめていない) |
| 赤寄り | 非理解(値 −4 以下で、30 日以内にズレがある。「分からない」は値を動かさない) |

色は値(−6〜+6)の 13 段で、赤 → 黄 → 青緑と少しずつ変わる。1 問答えると 1〜2 段動く。
| 暗い灰 | 未出題(概念は付いたが、まだ一度も問われていない) |
| もっと暗い灰 | 仮(関数が 1 つしか付いていない未出題の概念。名前がまだ定まっていない。表には 未出題(仮)) |
| 白灰 | リポジトリ |

最初は**ほぼ全部が暗い灰**です。これは正常で、問いに答えるたびに 1 つずつ灯っていく。

色が付かないときは Graph view 右上の歯車 → Groups に `[tone:v_m6]` … `[tone:v_p6]` と `[tone:off]` の行があるか確認する。0.5.0 より前の vault は自動で作り直される(古い設定は graph.json.bak)。Graph view を開いたままだと反映されないので、タブを閉じて開き直す。無ければ `~/Documents/hidane/.obsidian/graph.json` を消して `/hidane --vault` を打つと作り直される。

## 3. 一問答える

Claude Code を対象のリポジトリで開き、`/hidane` と打つ。

```
src/pool.c:57-68 take_slot
worker が 1 人だけのとき、この関数は何を返しますか。
```

答える。**自分の言葉で、具体的に**。「エラーになる」ではなく「NULL を返して、lock は解放される」のように。
「分からない」も正当な答えで、そのまま記録される(正直に言った方が地図は正しくなる)。

答えると、こう返る:

```
部分(鍵 3 / 4) — 触れていない: 分岐 L64-65
| 2026-09-09 10:12 | src/pool.c:57-68 | take_slot | 境界条件, 資源獲得の順序 | edge | worker 1 人のとき | partial | ... |
```

- **当たり(鍵 n / n)**: 正解の要素を全部言えた
- **部分(鍵 k / n) — 触れていない: 分岐 L64-65**: 言えていない要素がある。中身は教えず、その要素の種類(返り値 / 分岐 / 呼び出し / 順序 / 状態)とコードの行を指すだけ。自分で読みに行く
- **ズレ — 逆: L63**: 逆のことを言った箇所がある
- 解説や正解の文は出ない。それが設計。もっと聞きたければ、もう一度 `/hidane`

Claude Code が `sh .../scripts/next.sh` などの実行許可を毎回聞いてくる場合は、`~/.claude/settings.json` に次を足すと聞かれなくなる:

```json
{ "permissions": { "allow": [ "Bash(sh /Users/you/.claude/skills/hidane/scripts/*)" ] } }
```

その他のコマンド:

| | |
|---|---|
| `/hidane --weak` | 弱い所を 1 枚に。ズレを型にまとめ、流れのどの段で躓いているかを自分のコードの行で示す |
| `/hidane --focus [概念]` | 集中。1 回の呼び出しで 1 つの概念の関数を 1 問ずつ 3 問。72 概念に薄く散らず、1 回の座りで 1 概念を灯す |
| `/hidane --map` | 概念ごとの値・状態・repo の表をその場に出す |
| `/hidane --vault` | 地図を作り直して Obsidian で開く |
| `/hidane --lint` | 似た概念名を統合する(3 日に一度は自動) |
| `/hidane --tag` | まだ地図に無い関数に概念を付ける。install 前から触っていない関数や、commit 前の関数を載せたいとき |
| `/hidane --help` | 使い方を出す |
| `/hidane <聞きたいこと>` | 自分に合わせた解説。`/hidane printf って何？`、`/hidane さっきの問いで触れていなかった所`、`/hidane 自分の弱い所は`。Claude が先に地図を読み、理解している概念は飛ばし、間違えた所から話す。解説を読んでも色は変わらない |

## 4. 普段

いつも通り commit するだけ。背景で、触った関数に概念が付く(1 commit につき claude 呼び出し 1 回、10 秒前後。commit は待たされない)。
結果は `~/.claude/hidane/hook.log` に残る。地図の暗い灰のノードが増えていく。

1 日 1〜3 問答えるくらいで十分。同じ概念に 4〜5 問答えると色が動く。

## 5. 困ったとき

| 症状 | 見るところ・直し方 |
|---|---|
| `/hidane` で「候補なし」 | そのリポジトリの関数は全部問うた。commit するか `sh ~/hidane/scripts/tag.sh --all` |
| 「作業ツリーに無い関数 N 件は除いた」 | 消したり動かしたりした関数が記録に残っているだけ。放置でよい |
| `record.sh ... (exit 7)` | Claude が next.sh の決定と違う場所・型で記録しようとした。もう一度 `/hidane` |
| commit してもタグが付かない | `cat ~/.claude/hidane/hook.log`。`claude` が通るか、`.git/hooks/post-commit` があるか |
| Obsidian のノードに色が無い | 上の 2. の最後 |
| 地図がおかしい | `~/Documents/hidane` を丸ごと消して `/hidane --vault`。記録から作り直される |
| 記録を最初からやり直したい | `rm -rf ~/.claude/hidane`(**戻らない**) |
| 1 つの repo をやめる | そのリポジトリで `sh ~/hidane/install.sh --unhook`、`rm -rf ~/.claude/hidane/<repo>`、`/hidane --vault`。その repo だけの概念と、そこで答えた記録は地図から消える。残したいなら消さない(repo が無くなっても記録は残り、地図には「消えた」と出る) |
| 全部やめる | リポジトリで `sh ~/hidane/install.sh --unhook`、`rm -rf ~/.claude/skills/hidane ~/.claude/hidane ~/Documents/hidane` |

## 6. どこに何があるか

```
~/.claude/hidane/            記録(一次データ)
  config                       lang=ja
  <repo>/log.md                問いと答え。1 回 1 行。人が読める Markdown の表
  <repo>/functions.md          関数 → 概念
  aliases.md                   統合した概念名
  hook.log                     hook の出力
~/Documents/hidane/          地図(記録から毎回作り直せる)
~/.claude/skills/hidane/     /hidane の本体(install.sh --skill で更新)
```

hidane を更新するには `sh ~/hidane/install.sh --update`(または Claude Code で `/hidane --update`)。記録の形式が変わっていても自動で移行される。

## 7. 仕組みを少しだけ

- 値 = 答えの重み付き合計。易しい問い(追う)1、境界を突く問い 2。問いが狙った概念は満額、同じ関数の他の概念は半分。当たり +、外れ・分からない −、部分 0。±6 で止まる
- ±4 を越えると 理解 / 非理解 に灯る。30 日確かめないと 曖昧 に落ちる(値は減らない)。理解に戻れるのは当たりだけ、非理解に戻れるのはズレだけ
- 問う順は 非理解 > 曖昧 > 未出題。概念の順位は全リポジトリの記録から決まるので、A で分からなかった概念は B でも先に問われる
- 点数は出さない。色だけ。研究では、点数を見せると興味が落ち、注意がコードから自分に向くとされている

詳しくは [README.ja.md](../README.ja.md)。
