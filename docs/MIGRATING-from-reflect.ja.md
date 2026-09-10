# reflect から hidane へ

hidane は [reflect](https://github.com/kanaharu20/reflect) の後継ですが、記録の形が違うので**自動では移せません**。

| | reflect | hidane |
|---|---|---|
| 記録 | `~/.claude/reflect/<repo>/log.md`(日時・場所・見出し・問い・結果・Claude説明・備考・関数) | `~/.claude/hidane/<repo>/log.md`(日時・場所・関数・**概念**・型・問い・結果・ズレ・備考) |
| 状態 | 無し(記録の一覧) | 概念ごとに 理解 / 曖昧 / 非理解 / 未出題 |
| skill | `/reflect` | `/hidane` |

hidane の記録には**概念**の列が必須で、reflect の記録にはそれがありません。

## 移す場合(手作業)

1. reflect の各行に概念を 1〜3 個、自分で付ける(例: 境界条件、部分失敗の巻き戻し)。hidane の `tag.sh --all` を先に回すと、同じリポジトリの概念名の一覧が `~/Documents/hidane/index.md` にできるので、それに合わせる
2. 型を決める: 「どうなる」型の問いは `trace`、境界値を突いた問いは `edge`、「何をする」型は `summary`
3. 結果を記号に: 当たり・一致 → `hit`、ズレ・外れ → `miss`、分からない → `dunno`、未回答 → `skip`
4. 1 行ずつ `record.sh --free` で追記する:

```sh
sh ~/hidane/scripts/record.sh --free --repo <repo> "src/x.c:10-20" func "境界条件" trace "問いの要約" miss "ズレの中身" ""
```

作者は 15 行をこの手順で移した。1 行 1 分。

## 移さない場合

hidane は記録が無くても動く。`install.sh` を実行すれば、その時点の全関数が未出題として地図に載る。reflect の記録はそのまま残しておいて構わない(hidane は読まない)。

## reflect を外す

```sh
rm -rf ~/.claude/skills/reflect        # /reflect を消す
rm .git/hooks/post-commit              # reflect の hook を置いていたリポジトリで(先頭に "# reflect-hook" とあるもの)
```

`~/.claude/reflect/` の記録は消さなくてよい。
