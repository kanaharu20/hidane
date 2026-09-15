# Inside hidane

Details that do not fit the README. Not needed to use it.

## The record

Only the rows of `~/.claude/hidane/<repo>/log.md` are stored. One question, one row.

```
| Date | Place | Function | Concepts | Type | Question | Result | Miss | Note |
```

Type and result are language-neutral tokens. Type `trace` (follow the code) / `edge` (boundary or mutation).
Result `hit` / `partial` / `miss` / `dunno` / `skip`. `scripts/lang.sh` turns them into English or Japanese only for display.

Values and states are never stored; they are recomputed from these rows every time, so the record and the map cannot disagree.

## Value and state

Value = the sum over rows of (type weight × result sign), added one row at a time, clamped at ±6.

| Type | Weight |
|---|---|
| trace (follow) | 1 |
| edge (boundary) | 2 |

summary (weight 3) was retired in 0.5.1: the type existed without a grading method (CGBG, generating code from the explanation and comparing). Old summary rows are still read at weight 3.

Lead concept: a question targets the one concept next.sh chose (the lead). record.sh marks it with `*` in the concept column and map.sh credits the lead in full and the other concepts on the row at half (rounded down: 0 for trace, 1 for edge), so a concept the question did not test does not light up as a side effect. Rows without `*` (older) are credited in full.

| Result | Sign |
|---|---|
| hit | +1 |
| partial | 0 (counted as evidence) |
| miss, dunno | −1 |
| skip | 0 (not evidence) |

| State | Condition |
|---|---|
| understood | value ≥ +4, last **hit** within 30 days |
| not understood | value ≤ −4, last **miss or "I don't know"** within 30 days |
| fuzzy | −4 < value < +4, or older than 30 days (the value is kept; only certainty decays) |

Freshness is tracked separately for hits and misses (0.5.1) so that a concept that decayed to fuzzy cannot be re-certified as understood by a miss whose date happens to be fresh. Only a hit brings it back to understood; only a miss brings it back to not understood.
| unasked | no evidence (tag only, or unanswered only) |

A hit on a hard question moves the value a lot; a miss on an easy one moves it a lot the other way. One answer never flips a state.
Every constant is provisional and can be changed through environment variables (see the README).

## Keys

Before the answer is heard, Claude fixes 2-5 elements of the correct answer with `keys.sh` ("state: sets stopped @ 26"; kinds are return / branch / call / order / state). Key lines must fall inside the function's range, one thing is asked (return / call / order / state; call+order allowed) and branch keys only support it (`keys.sh` rejects the rest, which keeps out callee internals and "explain everything" questions). From the key kinds `keys.sh` returns a "question ending" ("what does it return? Include the condition that makes it so."), and the question's last sentence ends with it. No kind names or counts are shown. It stops the mismatch where the question asks only for a return value while the keys demand the steps in between. A key is an outcome, never a reason: `keys.sh` rejects keys containing "because" (exit 2).
After the answer, each key gets yes / no / contra, and `record.sh --verdict` derives the result:

- all yes → hit
- some no, no contra → partial
- any contra → miss

The user sees only the line numbers of missing keys ("not mentioned: L28-29"). The text stays in the log's miss column and feeds later questions.
Claude cannot write hit / miss directly (`--free` is for hand entry).

## Which function is asked next

Focus (`--focus [concept]`): `<repo>/focus` holds "concept<TAB>remaining"; while it lasts, next.sh picks only from that concept's functions. record.sh decrements it; at 0 it ends. Default 3 questions (`HIDANE_FOCUS_N`).
Type: a concept answered at least once (including "I don't know") gets edge (boundary, weight 2); a first-time concept gets trace.

Concepts are ranked from all repositories: not understood > fuzzy > unasked, lower value first. Understood concepts are never asked.
Candidates come from the current repository, excluding functions already asked (same file and function name, so a shifted line range does not bring a function back) and functions no longer present in the working tree.

The question type is decided here too (`edge` if the concept has past misses, else `trace`). The decision goes to `pending`,
and `record.sh` refuses a record with no pending decision, one that does not match it, or keys fixed for another question (exit 7). Claude decides only the wording and the keys.

## Tagging

After every commit, the hook sends the source of the touched functions to `claude -p` and asks for 1-3 concepts each.
The existing concept list is shown with "reuse an existing name whenever one fits", but new names are allowed.
The script validates the format and drops bad lines.
Two entry points: the hook at commit time (touched functions only) and `/hidane --tag` (`tag.sh --all`: every function of the current repository not on the map yet, no cap; it reads the working tree, so uncommitted functions count). Setup uses the latter once.
Concepts name what a function does, never a library.

## Merging names (lint)

Near-duplicate names accumulate, so every few days Claude is shown the list and asked for pairs that mean the same.
Pairs are appended to `aliases.md` as "old → new"; `log.md` is never rewritten. Readers resolve aliases (`resolve.sh`).
The new name must already exist; self-merges, unknown names and cycles are dropped. Delete a line to undo.

## Explaining

`/hidane <anything>` (text without a flag) is the one place hidane explains, and it treats the map as a memory of what the person understands.

1. Read `index.md`: overall stage (counts per state, questions answered), the last 5 explanations requested, the concept table
2. Pick the 3-5 concepts nearest to the topic and read their pages (past misses, the person's functions, records). Topics outside the vocabulary are mapped to the nearest concepts by Claude on the spot
3. Two opening lines "From the map" (the not-understood concepts it starts from, how many past misses were used, what was skipped). No values, no evaluative words
4. Understood: skipped. Not understood: carefully, from the past misses, pointing at lines. Fuzzy: normal. Unasked: one sentence
5. `explained.sh` logs the topic and the mapped concepts

The map hands Claude a trail, not the whole map: `index.md` grows only with the number of concepts.
Explanations never change values, states or colors. Reading is not evidence of understanding.

## Weak spots (`--weak`)

The one explanation that worked best, "where am I weak", made into a fixed form. The map-reading side moved into a script.

1. `weak.sh` assembles the material: among not-understood and fuzzy concepts, those with recorded misses (miss / partial), lowest value first, 3 of them (`HIDANE_WEAK_N`); every miss per concept (across repositories, newest first); the functions tagged with the concept in the current repository (only those still in the working tree). The two opening "From the map" lines are written by the script too
2. Claude keeps those two lines verbatim, reads 3-5 of the functions, and writes three sections: the pattern, the flow, step by step. Misses folded into one shape, the flow as 3-5 steps, which steps the misses land on, each step pointed at in the reader's own lines
3. `explained.sh "weak spots"` logs it

Concepts with only "I don't know" answers are not selected: that is not weakness, it is missing material. With no misses at all, exit 1. Values, states and colors do not change.

## Where things live

```
~/.claude/hidane/            records (primary data)
  config                       lang=en
  <repo>/log.md                questions and answers
  <repo>/functions.md          function → concepts
  <repo>/pending, keys         the next question and its keys (deleted by record.sh)
  <repo>/path                  where the repository lives (so pages.sh can check the working tree)
  aliases.md                   merged names
  explained.md                 explanations requested
  .version                     record-format version (migrate.sh)
~/Documents/hidane/          the map (rebuilt from records at any time)
  index.md                     entry point
  concepts/<concept>.md        one page per concept; never hand-edited
  repos/<repo>.md
  .obsidian/graph.json         colors (written once)
```

## Parts

| | Role | LLM |
|---|---|---|
| `map.sh` | value and state table | |
| `pages.sh` | generate the map | |
| `next.sh` | next function and type | |
| `keys.sh` / `record.sh` | keys and the record | |
| `tag.sh` | tag functions with concepts | ● |
| `lint.sh` | merge concept names | ● |
| `resolve.sh` | resolve aliases | |
| `explained.sh` | log an explanation request | |
| `weak.sh` | material for the weak-spots page (concepts with misses, every miss, the functions) | |
| `help.sh` | fixed usage text (en / ja) | |
| (no script) | explanation level, decided by Claude from index and concept pages | ● |
| `scope.sh` | cut a commit or a working tree into functions (keyword and C-style definitions; asked ones excluded) | |
| `migrate.sh` | record-format migrations | |
| `hooks/post-commit` | run tag.sh in the background after a commit | |

The LLM decides three things: tags, merges, and the level of an explanation. The first two choose from a list and are validated by scripts.
The third only shapes prose and never touches the record.

## Research this leans on

Knowledge Tracing (BKT: one hit may be luck). KCGen-KT (show the existing list when asking an LLM for concepts).
Explain in Plain English / CGBG (do not grade the explanation text). Open Learner Models / Mastery Grids (concept-level visualization).
Anthropic, How AI Impacts Skill Formation (when AI use erodes understanding). Butler 1988; Kluger & DeNisi 1996 (scores reduce learning).
Kalyuga 2003 (explanations pitched at the wrong level hurt).
