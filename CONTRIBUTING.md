# Contributing

For people who fork, send a PR, or review one. What the tool does is in [README.md](README.md); why it is built this way is in [docs/DESIGN.md](docs/DESIGN.md). This file is about changing it.

## Run the tests first

```sh
sh tests/run_all.sh
```

No LLM is called. `claude` is replaced by a fake script through `HIDANE_CLAUDE` inside the tests, so a run takes seconds and works offline. Every test writes under a temporary `HIDANE_ROOT` and `HIDANE_VAULT`; your real records in `~/.claude/hidane` are never touched.

`run_all.sh` fails when the number of tests differs from the number written in `README.md`, `README.ja.md` and `CHANGELOG.md`. If you add a test, update those three numbers.

## Layout

```
scripts/*.sh        the tool (POSIX sh + awk; one job per file; table below)
SKILL.ja.md / .en   what Claude does in a /hidane session; installed as ~/.claude/skills/hidane/SKILL.md
hooks/post-commit   the git hook (template; install.sh fills in the path)
install.sh          setup, hook, update
tests/test_*.sh     one file per script, L0 (no LLM); tests/fixtures are anonymized records
docs/DESIGN*.md     the rules and the reasons; docs/GUIDE*.md the user manual
```

Records live outside the repo: `~/.claude/hidane/<repo>/{log.md,functions.md,path,pending,keys}`, `aliases.md`, `explained.md`. The map is `~/Documents/hidane`.

| File | In one line |
|---|---|
| `hooks/post-commit` | after a commit, runs tag.sh in the background; never blocks the commit |
| `scripts/scope.sh` | cuts a repository into functions and lists the candidates |
| `scripts/tag.sh` | tags functions with concepts and appends to functions.md (LLM call 1 of 2) |
| `scripts/map.sh` | computes each concept's value and state from log.md, every time |
| `scripts/next.sh` | picks the one function to ask next and writes pending |
| `scripts/next.awk` | ranking, focus and question-type logic, run by next.sh via awk -f |
| `scripts/keys.sh` | fixes the elements of the correct answer before asking, prints the "Include in your answer" line |
| `scripts/record.sh` | derives the result from the per-key verdicts and appends one row to log.md (the only writer of the primary record) |
| `scripts/resolve.sh` | read-side filter that maps concept names through aliases.md |
| `scripts/pages.sh` | rebuilds the map (the Obsidian vault) from the records |
| `scripts/open.sh` | rebuilds the map and opens it in Obsidian |
| `scripts/lint.sh` | merges concept names that mean the same into aliases.md (LLM call 2 of 2) |
| `scripts/weak.sh` | gathers the material for the weak-spots page (concepts with misses, every miss, the functions) |
| `scripts/explained.sh` | logs one line per explanation requested to explained.md |
| `scripts/lang.sh` | ja/en display strings, and how a repository's records directory is named |
| `scripts/help.sh` | the fixed text behind `/hidane --help` |
| `scripts/migrate.sh` | rewrites old log.md when the record format changes |
| `scripts/stats.sh` | numbers-only summary with no names (for feedback) |
| `install.sh` | setup, hook install and removal, update |
| `tests/run_all.sh` | runs every test and checks the count against the README |

## Rules that a change must not break

These are the decisions the tool is built on. A PR that crosses one needs to say so in its description, and will be discussed before it is merged.

- **log.md is append-only.** Only `record.sh` appends to it and only `migrate.sh` may rewrite it (with a `.bak`). Values and states are never stored; `map.sh` recomputes them from the rows every time.
- **State moves only by answering.** Explanations (`explained.sh`, `weak.sh`) never change a value, a state or a color. There is no manual override.
- **No scores.** Nothing prints a percentage or a judgement word. Colors mean "which concepts are lit", not a grade.
- **The LLM decides in three places only**: which concepts a function gets (`tag.sh`), which concept names mean the same (`lint.sh`), and the wording of an explanation (SKILL). Everything else, including hit / partial / miss and which function is asked next, is decided by a script. If a rule for Claude can be enforced by a script, enforce it by a script; prose in SKILL.md sometimes does not take.
- **Record vocabulary is language-neutral** (`known/fuzzy/unknown/unasked`, `trace/edge/summary`, `hit/partial/miss/dunno/skip`). Display strings go through `scripts/lang.sh`; add both `ja:` and `en:` for every new key.
- **Keys are fixed before the answer is heard** and never shown to the user; missing keys are pointed at by kind and line number only.

## Portability

macOS `/bin/sh` and Linux `dash` both run the scripts. That means: no bashisms (`[[`, arrays, `local` is fine but avoided), no `sed -i` (write to a temp file and `mv`), no GNU-only `awk` (no `gensub`, no `func` as a name), `date` only in the forms both BSD and GNU accept. Tests run on macOS; Linux is untested but intended.

## Adding or changing a script

1. Put the usage in the header comment (`# 使い方:` / usage lines); `--help` prints those lines.
2. Read `ROOT` before sourcing `lang.sh`, then `. "$HERE/lang.sh"` for strings and `hidane_repo_key`.
3. Never let LLM output reach a file without validation. Look at how `tag.sh` and `lint.sh` check each line and drop the rest to stderr.
4. Never `eval` anything that came from a record or from Claude.
5. Write the test before trusting the code: break the implementation, watch the test fail, then fix it. Fixtures use fictional names (`worker`, `api`); do not paste real code or real function names into `tests/`.
6. If the record format changes, add a step to `migrate.sh` (idempotent, `.bak` kept, `.version` bumped) and bump `VERSION` and `CHANGELOG.md`.
7. If `SKILL.*.md` changes, reinstall (`sh install.sh --skill --lang ja`) and try it in a fresh Claude Code session. Whether Claude follows a step is verified by reading the session transcript, not by assuming.

## Sending a PR

- One change per PR. Say what was wrong or missing, what the change does, and which tests cover it.
- `sh tests/run_all.sh` prints `ALL PASS` on your branch.
- User-facing text exists in both languages: `README.md` + `README.ja.md`, `docs/GUIDE.md` + `.ja.md`, `SKILL.en.md` + `SKILL.ja.md`, `help.sh`, `lang.sh`.
- `CHANGELOG.md` has an entry under the next version.
- No real records, real function names or real repository names in the diff (fixtures, docs, examples). The graph in the README is fictional on purpose.

## Reviewing a PR

Things worth checking, in order:

1. Does it keep the rules above? Especially: does anything new write to log.md, store a state, print a score, or hand a decision to the LLM?
2. Does every new script path have a test that fails without the change?
3. Does it parse records by column with awk (`| a | b |`), trimming spaces, and does it survive a `|` inside a field (record.sh replaces it with `｜`)?
4. Does it work with no commits, untracked files, a deleted repository directory, and two repositories with the same basename? (`tag.sh`, `next.sh`, `weak.sh`, `pages.sh` all check the working tree.)
5. Does a background `tag.sh` (the hook) and a foreground one collide? (`tag.sh` takes a per-repository lock.)
6. Both languages, test counts, CHANGELOG.

## Versioning

`VERSION` is semver-ish: patch for fixes, minor for a new flag or a record-format change (with a `migrate.sh` step). `install.sh --update` runs `git pull`, reinstalls the skill, then `migrate.sh`, so an update must be safe to apply to records written by any earlier version.

## Reporting a problem

Paste the output of `sh scripts/stats.sh` (numbers only, no names) and the relevant lines of `~/.claude/hidane/hook.log`. If a `/hidane` session misbehaved, the useful evidence is the sequence of script calls and their outputs; those are in the session transcript.
