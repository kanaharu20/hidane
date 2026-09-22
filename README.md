# hidane 🔥

[日本語](README.ja.md)

A tool for telling Claude which parts of your code you understand and which you do not.

When an AI writes your code, the amount that works grows; the amount you can explain does not. And Claude explains
things without knowing what you are missing.
hidane builds a "map of understanding", not from self-report but from the record of questions you answered one at a time.
Claude reads that map before explaining: it skips what you know and starts from what you got wrong last time.
You look at the same map. Not a score, but which concepts are lit.

<p align="center">
  <img src="docs/graph.svg" alt="A map drawn from fictional data: 2 repositories, 42 concepts. Thirteen steps from red (-6) through amber (0) to green (+6); dark gray = never asked" width="820">
</p>

## What happens

Every commit tags the functions it touched with "concepts" (boundary conditions, rollback on partial failure, condition-variable wait and notify, and so on).
Type `/hidane` in Claude Code and it picks one of those functions and asks exactly one question.

```
src/main.c:19 is_valid_num
Given the string "+5", what does this function return? Include the condition that makes it so.
```

Answer in your own words. "I don't know" is an answer.

```
hit (keys 2 / 2)
| 2026-09-09 09:54 | src/main.c:19-33 | is_valid_num | input validation, boundary conditions | trace | "+5" → returns? | hit |  |  |
```

The elements of the correct answer were fixed as 2-5 "keys" before you answered, and each key is judged present / missing / contradicted. The last line of the question lists the kinds and counts of the keys, never their contents, so every key is inside what you were asked.
Fall short and you get "partial (keys 3 / 4), not mentioned: order L28-29", kind and line numbers only. It does not tell you what is there. You go and read. If reading is not enough, ask `/hidane the part I missed in the last question` and it explains from there.
No explanation, no summary. That is how the asking side behaves.

As answers accumulate, concepts light up in Obsidian's graph view. The color comes from one "value" per concept (-6 to +6): hits raise it, misses and "I don't know" lower it.
Thirteen steps from red (-6) through amber (0) to green (+6); one answer moves a concept one or two steps. Never-asked concepts stay unlit.

| Value | State | When |
|---|---|---|
| none (unlit) | unasked | no function with this concept has been asked yet |
| around -3 to +3 (amber) | fuzzy | answered but not settled: hits and misses mixed, only 1-2 answers, or no answer in 30 days |
| +4 and up (toward green) | understood | hits piled up |
| -4 and down (toward red) | not understood | misses piled up |

How far one answer moves it depends on the question type: tracing 1, boundary 2. The concept the question targeted gets the full amount, the other concepts on the same function half. Partial does not move it. Reading an explanation does not move it.
After 30 days without an answer, understood and not understood both fall back to amber. Only a hit brings a concept back to understood; only a miss brings it back to not understood. At first almost everything is dark, and it lights up one answer at a time.

When you want an explanation, just ask after `/hidane`: `/hidane what is printf?`. Claude reads the map first.
Concepts you understand are not even named; concepts you do not understand are explained carefully, starting from what you got wrong, using your own functions as examples.
Something outside the map, like printf, gets mapped to the nearest concepts on the spot. The explanation opens with two lines, "From the map: not understood …, skipped: …", so you can see what was read and what it changed.
Reading an explanation changes no color. Reading is not evidence of understanding.

`/hidane --weak` points that explanation at your own weak spots. It lays out every past miss, folds them into one pattern, lays the flow out in steps, and shows which step you stumble on, in the lines of your own code.

```
From the map: not understood stop-flag propagation, waking all waiters → starting there. Fuzzy timeout check. Used 3 past misses
Skipped: none

The pattern: "one more line after stop", "forgot wake_all", "the other workers' logs stop too; never mentioned wake_all and return 1".
All three end the story where stopped = 1 is set. Setting it stops nobody.
A thread stops only when it comes to read the flag itself.

The flow: 1 set (src/stop.c:30-35) → 2 wake (src/stop.c:41-53) → 3 the woken side reads it (src/slot.c:58) → 4 clean up and leave (src/slot.c:56-65)
The misses are at steps 2 and 4.
```

This page cannot be written without the map. Which misses fold into the pattern, and which step of the flow gets the careful treatment, both come from the records.

## Try it

git, [Claude Code](https://claude.com/claude-code), and ideally [Obsidian](https://obsidian.md).

```sh
git clone git@github.com:kanaharu20/hidane.git ~/hidane
cd your-repo && sh ~/hidane/install.sh
```

It asks en or ja, registers `/hidane`, adds a hook to this repository, tags every function (about a minute per 8 functions; a 50-function repository takes 6-7 minutes), and writes the map to `~/Documents/hidane`.
Open that folder in Obsidian with "Open folder as vault". Then `/hidane`.

| | |
|---|---|
| `/hidane` | one question |
| `/hidane <anything>` | an explanation at your level: a function, a concept, printf, "where am I weak" |
| `/hidane --weak` | weak spots on one page: misses folded into a pattern, the flow, the step you stumble on, in your own lines |
| `/hidane --dispute <n> <reason>` | dispute a key of the last question. The value does not change; the dispute is shown when keys are next made for that function |
| `/hidane --map` | the table of concepts, values and states |
| `/hidane --vault` | rebuild the map and open it in Obsidian |
| `/hidane --lint` | merge concept names that mean the same (also automatic every 3 days) |
| `/hidane --init` | register the current repository (installs the hook, tags every function in the background). Same as running install.sh again |
| `/hidane --tag` | tag functions not on the map yet, in the background, uncommitted ones too. The hook does it at every commit |
| `/hidane --update` | latest version, records migrated |
| `/hidane --help` | usage |

At commit time the source of the touched functions goes to your own Claude (`claude -p`) and concept names come back. The hook prints one line every time, so it never runs silently.
`HIDANE_HOOK_OFF=1` or `install.sh --unhook` stops it. Records and the map stay on your machine. Cost is on your Claude Code plan; a 40-function repository takes about 5 calls to tag.

The long version, with expected outputs and troubleshooting: [docs/GUIDE.md](docs/GUIDE.md).

## Decisions

No scores. Scores lower interest and turn attention from the code to the self (Butler 1988; Kluger & DeNisi 1996). The colors say which parts of the code are lit, not how good you are.

The record is append-only. Values and states are never stored; everything is recomputed from `log.md`. Merging concept names is done with aliases, never by rewriting rows. Delete the map and it comes back.

The LLM decides three things only: which concepts a function gets, which concept names mean the same, and the level of an explanation.
The first two choose from an existing list and are validated by scripts. Whether an answer was right, what to ask next, and the question type are all decided by scripts.
In the predecessor, judgments left to Claude and instructions given in prose drifted between runs on the same input. So scripts decide, and Claude fills in blanks.

"Never asked" and "asked and failed" are different states and are kept apart. Questions come from the second.

Concepts belong to you; functions belong to a repository. A concept you failed in repo A is the first thing asked when repo B commits.

The mechanics in detail: [docs/DESIGN.md](docs/DESIGN.md).

## Limits, and what is not done

- One author, two repositories, 32 answers so far. Weights (1 / 2 / 3), threshold (±4) and forgetting (30 days) are all provisional
- The "what does this function do" type (summary) was removed: there is no grading method for it (CGBG, generating code from the explanation). Two question types remain, follow and boundary
- Zero dependencies beyond git and POSIX sh came at the price of dense sh and awk. 228 tests are what make it safe to change
- Linux should work but is untested; `/hidane --vault` uses macOS `open`
- How closely Claude follows the SKILL steps is checked by reading real session transcripts. Prose instructions sometimes do not take

## Development

```sh
sh tests/run_all.sh     # 228 tests, no LLM, seconds
```

A new test is trusted only after breaking the implementation and watching it fail. `run_all.sh` also fails if the test count in this README drifts from reality.

| Variable | Default | |
|---|---|---|
| `HIDANE_LANG` | from config, else en | display and prompt language |
| `HIDANE_ROOT` | `~/.claude/hidane` | records |
| `HIDANE_VAULT` | `~/Documents/hidane` | the map |
| `HIDANE_W_TRACE` / `_EDGE` | 1 / 2 | type weights |
| `HIDANE_THRESHOLD` / `HIDANE_CAP` | 4 / 6 | threshold and clamp |
| `HIDANE_FRESH_DAYS` | 30 | forgetting |
| `HIDANE_MAX_FUNCS` | 8 | functions per LLM call |
| `HIDANE_LINT_DAYS` | 3 | lint interval |
| `HIDANE_WEAK_N` | 3 | concepts on the `--weak` page |
| `HIDANE_MODEL` | | `--model` passed to `claude -p` |
| `HIDANE_HOOK_OFF` | | 1 disables the hook |
| `HIDANE_SKILL_DIR` | `~/.claude/skills/hidane` | where the skill is installed |
| `HIDANE_CLAUDE` / `HIDANE_OPEN` | claude / open | substitutes for tests |

Forking, sending a PR, reviewing one: [CONTRIBUTING.md](CONTRIBUTING.md). Design items on hold: [docs/BACKLOG.ja.md](docs/BACKLOG.ja.md) (Japanese).
Records from reflect (the predecessor) have a different shape and are not imported automatically: [docs/MIGRATING-from-reflect.ja.md](docs/MIGRATING-from-reflect.ja.md).
Versions: [CHANGELOG.md](CHANGELOG.md).

## License

MIT
