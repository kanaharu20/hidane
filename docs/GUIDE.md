# hidane guide (English)

A step-by-step walkthrough for first-time users. More detail than the README.

## 0. Prerequisites

| Need | Check |
|---|---|
| macOS or Linux (the author uses macOS; Linux should work) | |
| git | `git --version` |
| POSIX sh (present on macOS / Linux) | |
| [Claude Code](https://claude.com/claude-code), logged in, with `claude` on PATH | `claude --version` |
| [Obsidian](https://obsidian.md) to see the map (records and Markdown are generated without it) | |
| Your code lives in a **git repository** | `git status` works |

Supported languages (function extraction): C, C++, Python, JavaScript / TypeScript, Go, Rust, Java, Ruby, PHP, Swift, Kotlin, Shell and others, 15 in total.

**What is sent to Claude**: at commit time and with `--all`, the **source of the touched functions** goes to Claude via `claude -p` and concept names come back.
During `/hidane`, Claude Code reads the function as it normally would. Records (`~/.claude/hidane/`) and the map (`~/Documents/hidane/`) stay on your machine.

## 1. Install

```sh
git clone git@github.com:kanaharu20/hidane.git ~/hidane
cd ~/your-repo && sh ~/hidane/install.sh
```

(`https://github.com/kanaharu20/hidane.git` works too.) You will see:

```
Language / 言語 [en/ja] (en): en
hidane setup (lang=en)
  /hidane registered: /Users/you/.claude/skills/hidane
  hook installed: /Users/you/your-repo/.git/hooks/post-commit
  tagging every function with concepts (about a minute)...
tag.sh: candidates 20, calls 3, appended 20, dropped 0 → /Users/you/.claude/hidane/your-repo/functions.md
Next: open /Users/you/Documents/hidane in Obsidian (Open folder as vault). Then run /hidane in Claude Code
```

- "another post-commit hook exists": add a line calling `sh ~/hidane/hooks/post-commit` to your existing hook.
- "claude not found": install Claude Code, make sure `claude` runs, then run `install.sh` again.
- For another repository, run `install.sh` inside it (the language is not asked again).

## 2. Open the map (first time only)

Start Obsidian → vault switcher (bottom left) → **Open folder as vault** → choose `~/Documents/hidane`.
You will see `concepts/`, `repos/`, `index.md`. Click the **Graph view** icon.

| Color | Meaning |
|---|---|
| green | understood (repeated hits, checked within 30 days) |
| amber | fuzzy (mixed results, or not checked for 30 days) |
| red | not understood (misses and "don't know" have piled up) |
| dark gray | unasked (tagged, never asked) |
| light gray | repository |

At first **almost everything is dark gray**. That is normal; nodes light up one answer at a time.

No colors? Open the gear in Graph view → Groups and check the four `[state:...]` entries exist. If not, delete `~/Documents/hidane/.obsidian/graph.json` and run `/hidane --vault`.

## 3. Answer one question

Open Claude Code in the repository and type `/hidane`.

```
src/pool.c:57-68 take_slot
When there is only one worker, what does this function return?
```

Answer **in your own words, concretely**: not "it errors" but "it returns NULL and releases the lock".
"I don't know" is a valid answer and is recorded as such (honesty makes the map more accurate).

The reply looks like:

```
partial (keys 3 / 4) — not mentioned: L64-65
| 2026-09-09 10:12 | src/pool.c:57-68 | take_slot | boundary conditions, lock ordering | edge | one worker | partial | ... |
```

- **hit (keys n / n)**: every element of the correct answer was there.
- **partial (keys k / n) — not mentioned: L64-65**: something is missing. It is not revealed; the line where it lives is pointed at. Go read it.
- **miss — contradicted: L63**: something was stated backwards.
- No explanation, no model answer. That is by design. Want more? `/hidane` again.

If Claude Code asks permission for `sh .../scripts/next.sh` every time, add to `~/.claude/settings.json`:

```json
{ "permissions": { "allow": [ "Bash(sh /Users/you/.claude/skills/hidane/scripts/*)" ] } }
```

Other commands:

| | |
|---|---|
| `/hidane --map` | table of concepts: value, state, repos |
| `/hidane --vault` | rebuild the map and open it in Obsidian |
| `/hidane --lint` | merge concept names that mean the same (also automatic every 3 days) |

## 4. Day to day

Just commit. In the background, touched functions get concepts (one `claude` call per commit, ~10 s; the commit itself never waits).
Output goes to `~/.claude/hidane/hook.log`. Dark gray nodes accumulate.

One to three questions a day is plenty. A concept changes color after about 4-5 answers.

## 5. Troubleshooting

| Symptom | Where to look / fix |
|---|---|
| `/hidane` says "no candidates" | every function in this repo has been asked. Commit, or `sh ~/hidane/scripts/tag.sh --all` |
| "N functions no longer in the working tree were skipped" | deleted or moved functions are still in the record; harmless |
| `record.sh ... (exit 7)` | Claude tried to record a different place/type than next.sh decided. Run `/hidane` again |
| commits are not tagged | `cat ~/.claude/hidane/hook.log`; check `claude` runs and `.git/hooks/post-commit` exists |
| no colors in Obsidian | end of section 2 |
| the map looks wrong | delete `~/Documents/hidane` and run `/hidane --vault`; it is rebuilt from the records |
| start over | `rm -rf ~/.claude/hidane` (**not recoverable**) |
| remove everything | in the repo `sh ~/hidane/install.sh --unhook`, then `rm -rf ~/.claude/skills/hidane ~/.claude/hidane ~/Documents/hidane` |

## 6. Where things live

```
~/.claude/hidane/            records (primary data)
  config                       lang=en
  <repo>/log.md                questions and answers, one row each; a readable Markdown table
  <repo>/functions.md          function → concepts
  aliases.md                   merged concept names
  hook.log                     hook output
~/Documents/hidane/          the map (rebuilt from records at any time)
~/.claude/skills/hidane/     the /hidane skill (updated by install.sh --skill)
```

To update hidane: `cd ~/hidane && git pull && sh install.sh --skill`.

## 7. A little of the mechanics

- Value = weighted sum of answers. Easy (trace) 1, edge 2, summary 3. hit +, miss / don't know −, partial 0. Clamped at ±6.
- Beyond ±4 a concept lights green / red. Not checked for 30 days → amber (the value is kept).
- Order of questions: not understood > fuzzy > unasked. Ranking uses records from all repositories, so a concept you failed in A is asked first in B.
- No scores, only colors. Research shows scores lower interest and shift attention from the code to the self.

See [README.md](../README.md) for the rest.
