<h1 align="center">hidane 🔥</h1>

<p align="center">
  <b>A map of what you actually understand in your own code — built only from your answers.</b><br>
  <a href="README.ja.md">日本語</a>
</p>

<p align="center">
  <img alt="tests" src="https://img.shields.io/badge/tests-112%20passing-brightgreen">
  <img alt="deps" src="https://img.shields.io/badge/deps-git%20%2B%20POSIX%20sh-blue">
  <img alt="llm" src="https://img.shields.io/badge/LLM%20decisions-2%20places-orange">
  <img alt="status" src="https://img.shields.io/badge/status-alpha-lightgrey">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-green">
</p>

<p align="center">
  <img src="docs/graph.svg" alt="hidane map drawn from fictional data: 2 repositories, 42 concepts. Traffic-light colors: understood=green, fuzzy=amber, not understood=red, unasked=unlit" width="820">
</p>

When an AI writes your code, the amount that *works* grows; the amount you can *explain* does not.
hidane asks you **one question** about one of your own functions, records the answer, and computes
"understood / fuzzy / not understood / unasked" from the record alone. The result is a graph in Obsidian,
colored like a traffic light. No scores.

## Demo

```
$ /hidane

  src/main.c:19 is_valid_num
  Given the string "+5", what does this function return?

> It returns false, because '+' is not a digit.

  hit (keys 2 / 2)
  | 2026-09-09 09:54 | src/main.c:19-33 | is_valid_num | input validation, boundary conditions | trace | "+5" → returns? | hit |  |  |
```

A vague answer does not pass. Before asking, Claude fixes 2-5 "keys" (concrete facts of the correct answer) on disk;
after the answer each key is judged present / missing / contradicted, and the script derives the result:

```
  partial (keys 3 / 4) — not mentioned: L28-29
```

Missing keys are pointed at by line number only; the fact itself is never revealed. That is all. No explanation, no summary. Open Obsidian and the "input validation" node has lit up from unlit (unasked) to amber (fuzzy).

```
$ /hidane --map

| Concept              | Value | Evidence | Last       | State          | Repo       |
|----------------------|-------|----------|------------|----------------|------------|
| stop flag propagation|  -6   |    4     | 2026-09-09 | not understood | worker     |
| boundary conditions  |  -2   |    4     | 2026-09-09 | fuzzy          | api,worker |
| input validation     |  +1   |    1     | 2026-09-09 | fuzzy          | api,worker |
| inverted index build |  +0   |    0     | -          | unasked        | api        |
```

## Features

- **One question.** One function, one question per call. "I don't know" is an answer. Re-answers are not recorded.
- **Strict, mechanical judging.** The correct answer is fixed as 2-5 keys *before* you answer; each key is judged present / missing / contradicted and the script decides hit / partial / miss. Vague answers earn nothing.
- **No explaining.** The code is never explained before the question. A missing key is pointed at by line number. No scores, no evaluative words.
- **The record is the only truth.** Values and states are never stored; they are recomputed from `log.md` every time. Delete the map and it comes back.
- **Unasked code is on the map.** Every commit tags the functions it touched with concepts. Functions you have never been asked about show up as unlit nodes.
- **Across repositories.** Concepts belong to you; functions belong to a repository. A concept you failed in repo A is the first thing asked when repo B commits.
- **The LLM decides only two things.** Which concepts a function belongs to, and which concept names mean the same thing. State, question type, priority and record format are all decided by scripts.
- **Depends on git and POSIX sh.** LLM calls go through Claude Code (`claude -p`). The map is rendered by Obsidian (optional; it is plain Markdown either way).
- **English or Japanese.** Chosen once at setup; the record format is language-neutral.

## Quick start

Requires git, POSIX sh, and [Claude Code](https://claude.com/claude-code). [Obsidian](https://obsidian.md) to see the map.

```sh
git clone git@github.com:kanaharu20/hidane.git ~/hidane
cd ~/your-repo && sh ~/hidane/install.sh
```

That asks `en` or `ja`, registers `/hidane` in Claude Code, adds the post-commit hook to this repository,
tags every function with concepts (about a minute), and writes the map to `~/Documents/hidane`.

Then open `~/Documents/hidane` in Obsidian with "Open folder as vault" (first time only; afterwards `/hidane --vault`)
and run `/hidane` in Claude Code. Graph view shows traffic-light colors: understood = green, fuzzy = amber,
not understood = red, unasked = unlit.

More repositories: run `install.sh` again inside each one. Change the language later: `sh ~/hidane/install.sh --lang ja`.

Step-by-step walkthrough with expected outputs and troubleshooting: [docs/GUIDE.md](docs/GUIDE.md).
Trying it out for me? Please fill in [docs/FEEDBACK.md](docs/FEEDBACK.md); `scripts/stats.sh` prints numbers only, no code.

## Usage

| Command | What it does |
|---|---|
| `/hidane` | One question. Answer. Recorded. |
| `/hidane --map` | Table of concepts: value, state, repos |
| `/hidane --vault` | Rebuild the map and open it in Obsidian |
| `/hidane --lint` | Merge concept names that mean the same thing (also runs automatically every 3 days) |
| `git commit` | As usual. Functions touched are tagged in the background. The commit never blocks. |

The scripts work on their own too; every one prints usage with `--help`.

```sh
sh scripts/map.sh            # table (--tsv for machines)
sh scripts/pages.sh          # generate the Obsidian vault
sh scripts/next.sh           # decide the next function and question type
sh scripts/tag.sh --all      # tag every function (--commit REV for one commit)
sh scripts/lint.sh --dry-run # see the merge prompt
```

## How it works

```
 git commit ─▶ hook ─▶ tag.sh ─▶ functions.md   function → concepts (appears on the map as unasked)
                                       │
 /hidane ─▶ next.sh (picks the function and the question type) ◀┘
        ─▶ Claude asks one question (no explanation)
        ─▶ you answer
        ─▶ Claude checks against the real code; a miss is a line number
        ─▶ record.sh ─▶ log.md ─▶ pages.sh ─▶ Obsidian vault (the color changes)
```

<details>
<summary><b>How the state is computed</b></summary>

Only the rows of `log.md` are stored. Value and state are recomputed every time.

**Value** = sum over rows of (question-type weight × result sign), added one row at a time and clamped at ±6.

| Type | Weight | Question |
|---|---|---|
| `trace` | 1 | "Given this input, what does it return / what happens?" |
| `edge` | 2 | The same, with an empty / single / last / limit input, or one that reproduces a past miss |
| `summary` | 3 | "What does this function do?" |

| Result | Sign | How it is decided |
|---|---|---|
| `hit` | +1 | every key present |
| `partial` | 0 (counts as evidence) | some keys missing, none contradicted |
| `miss`, `dunno` | −1 | any key contradicted / "I don't know" |
| `skip` | 0 (not evidence) | no answer |

| State | Condition |
|---|---|
| understood | value ≥ +4 and last answer within 30 days |
| not understood | value ≤ −4 and within 30 days |
| fuzzy | −4 < value < +4, or more than 30 days old (the value is kept; only certainty decays) |
| unasked | never asked (tag only, or unanswered only) |

A hit on a hard question moves the value a lot; a miss on an easy one moves it a lot the other way. One answer never flips the state.
Forgetting is time-based only and answering restores it. There is no way to set a state by hand.

</details>

<details>
<summary><b>Which function is asked next</b></summary>

Concepts are ranked from **all repositories**: not understood > fuzzy > unasked, lower value first. Understood concepts are never asked.
Candidate functions come from **the current repository**, excluding those already asked.

`next.sh` also decides the question type (`edge` if the concept has past misses, else `trace`). The decision is written to
`pending`, and `record.sh` refuses any record that does not match it. Claude then writes the keys (`keys.sh`) before asking,
and after the answer passes one verdict per key (`--verdict "yes,no,contra"`); `record.sh` derives hit / partial / miss.
Claude chooses the wording of the question and judges each key; it never decides the result.

</details>

<details>
<summary><b>Merging concept names (lint)</b></summary>

Tagging may invent new names, so near-duplicates accumulate. Every few days Claude is shown the concept list and asked for
"old → new" pairs, which are appended to `aliases.md`.

- **`log.md` is never rewritten.** Readers resolve aliases on the fly (`resolve.sh`).
- A merged concept's value is the sum of both sides' evidence; repos are unioned; links are recomputed.
- The new name must already exist. Self-merges, unknown names and cycles are dropped by the script.
- Undo a merge by deleting its line in `aliases.md`.

</details>

## Configuration

All via environment variables. **Every constant is provisional** and tuned by use.

| Variable | Default | Meaning |
|---|---|---|
| `HIDANE_LANG` | from `<root>/config`, else `en` | Display and prompt language (`en` / `ja`) |
| `HIDANE_ROOT` | `~/.claude/hidane` | Where records live |
| `HIDANE_VAULT` | `~/Documents/hidane` | Where the map (Obsidian vault) is written |
| `HIDANE_W_TRACE` / `HIDANE_W_EDGE` / `HIDANE_W_SUMMARY` | 1 / 2 / 3 | Question-type weights |
| `HIDANE_THRESHOLD` | 4 | Threshold for understood / not understood |
| `HIDANE_CAP` | 6 | Value clamp |
| `HIDANE_FRESH_DAYS` | 30 | Older than this becomes fuzzy |
| `HIDANE_MAX_FUNCS` | 8 | Functions per LLM call (loops until all are tagged) |
| `HIDANE_LINT_DAYS` | 3 | Lint interval |
| `HIDANE_MODEL` | (Claude Code default) | Model for tagging and lint |
| `HIDANE_HOOK_OFF` | | Set to 1 to disable the hook |

<details>
<summary><b>Where things live</b></summary>

```
~/.claude/hidane/                 records (primary data; not recoverable if deleted)
  config                            lang=en|ja
  <repo>/log.md                     questions and answers, one row each; written only by record.sh
  <repo>/functions.md               function → concepts, tagged at commit time
  <repo>/pending                    the next question as decided by next.sh
  <repo>/keys                       the keys fixed before the question; deleted by record.sh
  aliases.md                        concept aliases (old → new)
  .lint-stamp                       last lint date
  hook.log                          hook output
~/Documents/hidane/               the map (derived; pages.sh rebuilds it)
  concepts/<concept>.md             one page per concept; never hand-edited
  repos/<repo>.md                   concepts seen in that repository
  index.md                          the full table
  .obsidian/graph.json              graph colors (written once)
```

</details>

## Philosophy

- **Don't let the LLM decide.** In the predecessor, textual instructions ("no preamble") worked 0 times out of 10, and anything Claude assembled drifted. So scripts decide and Claude fills in blanks from a list.
- **No scores.** Scores lower interest and turn attention from the code to the self (Butler 1988; Kluger & DeNisi 1996). The colors say which parts of the code are lit, not how good you are.
- **Unasked ≠ not understood.** "Never checked" and "checked and failed" are kept apart. Questions start from the failures.
- **Never rewrite the record.** Merges are aliases; the primary record is append-only.
- **Tests miss.** Every new test is trusted only after breaking the implementation and watching it fail. All 112 L0 tests were checked that way.

## Development

```sh
sh tests/run_all.sh          # 112 tests, no LLM, seconds
sh tests/test_tag.sh         # LLM calls are replaced by a fake via HIDANE_CLAUDE
```

| Part | Role | LLM |
|---|---|---|
| `scripts/map.sh` | value and state table | |
| `scripts/pages.sh` | generate the Obsidian vault (idempotent, prunes) | |
| `scripts/next.sh` | pick the next function and type; write `pending` | |
| `scripts/keys.sh` | fix the keys (facts of the correct answer) before the question | |
| `scripts/record.sh` | derive hit / partial / miss from per-key verdicts; append one row to `log.md`; verify against `pending` | |
| `scripts/tag.sh` | tag functions with concepts | ● |
| `scripts/lint.sh` | merge concept names (appends to `aliases.md`) | ● |
| `scripts/resolve.sh` | alias-resolving filter | |
| `scripts/open.sh` | rebuild and open the vault in Obsidian | |
| `scripts/stats.sh` | numbers-only summary for feedback (no names) | |
| `scripts/lang.sh` | display strings for en / ja | |
| `scripts/scope.sh` | cut a commit into functions, 15 languages (from [reflect](https://github.com/kanaharu20/reflect)) | |
| `hooks/post-commit` | run tag.sh in the background after a commit; never blocks | |
| `SKILL.en.md` / `SKILL.ja.md` | the `/hidane` procedure for Claude Code | wording and checking |

## Related work

Successor to [reflect](https://github.com/kanaharu20/reflect): the function extraction is inherited; the memory and state model are new.

- **Knowledge Tracing** (BKT onward): estimating per-concept mastery from answer sequences. "One hit may be luck" is folded into the threshold.
- [KCGen-KT](https://arxiv.org/abs/2502.18632): LLM-generated knowledge components for code; show the existing list and let it choose.
- [Explain in Plain English / CGBG](https://arxiv.org/abs/2403.06050): grading without grading the explanation (planned for the `summary` type).
- Open Learner Models / [Mastery Grids](https://people.cs.pitt.edu/~hosseini/papers/ectel2014.pdf): concept-level visualization of a learner.
- [Anthropic, How AI Impacts Skill Formation](https://arxiv.org/abs/2601.20245): when AI use erodes understanding, and which habits preserve it.
- Butler 1988; Kluger & DeNisi 1996: scores and self-focused feedback reduce learning.

## Status

Alpha. Run daily by one author on two repositories (21 questions, 38 concepts).

- Constants (weights, thresholds, forgetting) are provisional.
- Concept names follow the chosen language; mixed-language repositories work, and lint can merge across languages.
- The `summary` question type is not judged yet (CGBG planned); only `trace` / `edge` are asked today.
- `tag.sh` and `lint.sh` call `claude -p`: one call per 8 functions, 10-60 s each.

## License

[MIT](LICENSE)
