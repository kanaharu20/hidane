# Changelog

## 0.3.4 — 2026-09-15

- Functions no longer in the working tree are marked "(gone)" in the concept pages' unasked lists, and each
  repository page says how many. They were already excluded from questions and `--weak`; the vault now agrees.
  `tag.sh` and `record.sh` remember the repository path in `<root>/<repo>/path` so `pages.sh` can check from anywhere.
- 165 L0 tests.

## 0.3.3 — 2026-09-15

- Keys carry a kind (return / branch / call / order / state) and `keys.sh` prints "Include in your answer: return
  value 1, branch 2", which becomes the last line of the question. A question that asked only for a return value
  while the keys demanded the steps in between was scored partial; now every key is inside what the user is asked.
- The result line names the kind of each missing key: "not mentioned: branch L49-51".
- 163 L0 tests.

## 0.3.2 — 2026-09-15

- Not-understood concepts were drawn in the understood color: Obsidian's `[state:known]` group matches by substring,
  so it also caught `unknown`, and it came first. The understood group is now `[state:known] -[state:unknown]`;
  existing `graph.json` files are migrated on the next `pages.sh` run.
- 159 L0 tests.

## 0.3.1 — 2026-09-14

- `tag.sh --all` no longer stops at the 20 functions with the most branches (a reflect leftover in `scope.sh`).
  A 47-function repository had 20 on the map; setup now tags every function as the README says.
- `/hidane --tag`: tag the functions of the current repository that are not on the map yet, uncommitted ones
  included. Commit time is no longer the only entry for new concepts.
- `scope.sh` no longer mistakes a multi-line Python `from x import (` for a function, and a 3-line function
  (def, docstring, one statement) is now a candidate; the floor was 4 lines.
- `scope.sh` no longer splits a C function at a local `struct timeval x;` declaration, and no longer takes multi-line
  prototypes in headers or Makefile rules for functions (C-style blocks must contain a `{`; Makefiles are skipped).
- `tag.sh --bg`: `/hidane --tag` returns in seconds with the candidate count; the LLM calls run in the background
  and the summary lands in `hook.log`, like the commit hook.
- 158 L0 tests.

## 0.3.0 — 2026-09-13

- `/hidane --weak`: weak spots on one page. `weak.sh` picks the not-understood / fuzzy concepts that have recorded
  misses, lists every miss (across repositories, newest first) and the functions tagged with them in the current
  repository, and writes the two opening lines. Claude folds the misses into a pattern, lays out the flow, and
  points at the step where the misses land, in the reader's own lines. Logged via `explained.sh`; no state change.
- 154 L0 tests.

## 0.2.1 — 2026-09-13

- `next.sh` excludes asked functions by file + function name, not by line range. A function whose lines shifted after an
  edit was being asked again (one function was asked four times).
- `keys.sh` rejects keys that carry a reason ("because" / 「ので」). Keys are outcomes only; the SKILL says a key runs
  to the end of the flow (what the called function returns, where it exits).
- Question form: name one observable (what it returns / what is called next / where it exits). "What happens to the
  loop" is no longer an allowed form.
- 142 L0 tests.

## 0.2.0 — 2026-09-11

- `/hidane <anything>`: the map as memory. Claude reads `index.md` (overall stage, recent explanations, concept
  table) and the pages of the 3-5 nearest concepts, then explains at the reader's level: understood skipped,
  not-understood from past misses, unasked in a sentence. Any topic, including ones outside the map's vocabulary.
- `index.md` now opens with the overall stage and the last 5 explanations requested.
- `explained.sh` logs requests; explanations never change values, states or colors.
- Keys fixed before the question; hit / partial / miss derived from per-key verdicts; `partial` result.
- `next.sh` skips functions no longer present in the working tree.
- 139 L0 tests.

## 0.1.0 — 2026-09-09

First version shared with testers.

- One question per `/hidane`; keys fixed before the answer; hit / partial / miss derived from per-key verdicts
- Concept tagging at commit time (`tag.sh`, hook) and `--all` for the whole repository
- Map as an Obsidian vault with traffic-light colors; state computed from `log.md` only
- Cross-repository concept ranking; `lint` merges concept names via aliases without rewriting records
- English / Japanese chosen at setup; language-neutral record vocabulary
- One-command setup (`install.sh`), `install.sh --update`, `migrate.sh` for record-format changes
- 125 L0 tests, no LLM needed; run_all.sh checks that the READMEs state the real count
