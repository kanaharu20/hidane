# Changelog

## 0.5.5 — 2026-09-15

Decisions from the defect discussion.

- "I don't know" (dunno) no longer moves the value: sign 0, still counted as evidence, not counted for miss freshness.
  An honest "I don't know" no longer pushes a concept toward red; only a wrong answer does.
- On partial or miss, record.sh prints the full key list after the record (each marked hit / not mentioned / contra),
  then the explanation hint. Keys stay hidden before the answer.
- Tentative concepts: an unasked concept attached to only one function gets tone `tent` (a darker gray) and
  "unasked(tentative)" in tables. Existing graph.json files get the new color group added (.bak kept).
- scope.sh detects JS/TS arrow functions (`const f = (…) =>`, `async`, `= function (`) and indented class methods
  (`name(…) {`), excluding control keywords and test helpers (it / test / describe).
- open.sh uses `xdg-open` outside macOS.
- next.sh's awk program moved to `scripts/next.awk` (run via `awk -f`); install.sh copies `*.awk`.
- 208 tests.

## 0.5.4 — 2026-09-15

The last line of a question no longer names key kinds or counts ("何を呼ぶか(2 つ)" read as a hint, and "呼ぶ"
was ambiguous between the user's functions and pthread calls).

- `keys.sh` now prints a "question ending" derived from the key kinds, and the question's last sentence ends with it:
  return → "何を返しますか", call → "どの関数が呼ばれますか", call+order → "どの関数がどの順で呼ばれますか",
  order → "何がどの順で起きますか", state → "何が書き換わりますか"; a branch key appends "そうなる条件も添えてください".
- One thing asked per question: keys of return / call / order / state may not be mixed (call+order is allowed as
  "in what order"); branch keys only support it; branch-only keys are rejected. Replaces the "at most 2 kinds" rule.
- 204 tests.

## 0.5.3 — 2026-09-15

Question quality, after a focus run produced "from line 20's mark_waiters_unblocked, which path leaves the function"
with keys spanning branch / call / order and one key inside the callee.

- `keys.sh` rejects keys whose `@ line` falls outside the asked function's range or names another file: keys are
  facts on the function's own lines, and what a callee does inside is another question.
- `keys.sh` rejects keys spanning 3 or more kinds. One question asks for one observable thing plus the branch that
  decides it, so the last line names at most two things.
- The guidance line lists the thing asked first and the branch last.
- SKILL: "where does it exit" only for functions with 2+ ways out; no expressions, line numbers or callee names in
  the question text; describe the input in words.
- 201 tests.

## 0.5.2 — 2026-09-15

- `--focus` now asks its 3 questions inside one invocation, still one at a time (ask, wait, record, then the
  next). Before, each `/hidane` call consumed one of the 3 and the user had to call again. Scripts unchanged; the
  rule lives in SKILL.md.
- The last line of a question now puts the key kinds into words instead of counts: "答えには 何を返すか、どの条件で
  どちらへ進むか(2 か所) を含めてください" / "Your answer should cover what it returns, which way it goes at the
  condition (2 places)." The old "分岐 1、呼び出し 1、順序 1" form was unreadable to the person answering.

## 0.5.1 — 2026-09-15

Three rules of the value model, after the outside review.

- Freshness is tracked per direction: a concept returns to understood only through a hit and to not understood only
  through a miss. A miss recorded after 30 days of silence used to re-certify a decayed concept as understood.
- The concept a question targets (the lead, marked `*` in the concept column) is credited in full; the other concepts
  on the same function get half (0 for a trace question, 1 for a boundary question). Older rows without the mark are
  credited in full as before.
- The summary question type (weight 3) is retired: it was never asked by `next.sh` and had no grading method.
  Old summary rows are still read at weight 3. `HIDANE_W_SUMMARY` is gone.
- 197 L0 tests.

## 0.5.0 — 2026-09-15

Color and pace, after a week of use: a concept took 4-5 answers to change color, and nothing moved in between.

- Graph colors are a 13-step gradient over the value (-6 red → 0 amber → +6 green); every answer moves the node one
  or two steps. Never-asked stays gray. Old `graph.json` files are rebuilt (the old one is kept as `.bak`); close and
  reopen the Graph view once.
- `/hidane --focus [concept]`: three questions in a row on one concept, so one sitting settles one concept.
- A concept answered once (including "I don't know") gets the boundary question type from then on (weight 2); the
  weight-2 type used to require a recorded miss, so "I don't know" never led to it.
- `alive()` matches the function name as a whole identifier (`run` no longer matches `running`).
- `tag.sh` rejects concept names that cannot be file names (leading `.`, `..`, `/`).
- 190 L0 tests.

## 0.4.0 — 2026-09-15

Fixes from a full self-review of the scripts.

- `record.sh` no longer passes key text through `eval`; a key containing backticks or `$( )` was executed as shell.
- The hook resolves the commit hash before going to the background, so a second commit or `--amend` during the
  LLM call no longer swaps which commit gets tagged.
- `scope.sh` read the miss column as the function name (a reflect leftover), so an asked function whose lines
  shifted was sent to the LLM again. It now keys on file + function. Reflect-only modes were removed.
- `tag.sh` takes a per-repository lock; the hook and `--tag` running together no longer duplicate rows.
- `tag.sh --commit` reads line ranges and bodies from the commit's tree, not a mix of working tree and HEAD.
- `record.sh --path` is a pure query (it created directories and rewrote `path`); scope.sh honors `HIDANE_ROOT`.
- A header-only functions.md made tag.sh skip log.md when computing known functions (`set -e` + `&&`).
- `install.sh` finds the hooks directory through git (worktrees, `core.hooksPath`) and reports a failed write.
- Keys are bound to the pending question (`keys.pending`); `record.sh` refuses stale keys and, without `--free`,
  any record with no pending decision (exit 7).
- Records directories: two repositories with the same basename in different places get separate directories
  (`api`, `api-<n>`); names differing only by case on macOS stay together.
- `install.sh --skill` clears old scripts before copying; the English lint prompt no longer carries Japanese labels.
- 181 L0 tests.

## 0.3.5 — 2026-09-15

- `/hidane --tag` works in a repository with no commits yet, and picks up untracked files (not ignored ones).
  It failed with "Needed a single revision" and read function bodies from HEAD instead of the working tree.
- 168 L0 tests.

## 0.3.4 — 2026-09-15

- Functions no longer in the working tree are marked "(gone)" in the concept pages' unasked lists, and each
  repository page says how many. They were already excluded from questions and `--weak`; the vault now agrees.
  `tag.sh` and `record.sh` remember the repository path in `<root>/<repo>/path` so `pages.sh` can check from anywhere.
- A repository whose directory is gone: every function is marked (gone) and the repository page says where it was
  looked for and how to drop it. Records are never deleted by hidane itself.
- 166 L0 tests.

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
