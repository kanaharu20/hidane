# Inside hidane

Details that do not fit the README. Not needed to use it.

## The record

Only the rows of `~/.claude/hidane/<repo>/log.md` are stored. One question, one row.

```
| Date | Place | Function | Concepts | Type | Question | Result | Miss | Note |
```

Type and result are language-neutral tokens. Type `trace` (follow the code) / `edge` (boundary or mutation) / `summary`.
Result `hit` / `partial` / `miss` / `dunno` / `skip`. `scripts/lang.sh` turns them into English or Japanese only for display.

Values and states are never stored; they are recomputed from these rows every time, so the record and the map cannot disagree.

## Value and state

Value = the sum over rows of (type weight × result sign), added one row at a time, clamped at ±6.

| Type | Weight |
|---|---|
| trace | 1 |
| edge | 2 |
| summary | 3 |

| Result | Sign |
|---|---|
| hit | +1 |
| partial | 0 (counted as evidence) |
| miss, dunno | −1 |
| skip | 0 (not evidence) |

| State | Condition |
|---|---|
| understood | value ≥ +4, last answer within 30 days |
| not understood | value ≤ −4, within 30 days |
| fuzzy | −4 < value < +4, or older than 30 days (the value is kept; only certainty decays) |
| unasked | no evidence (tag only, or unanswered only) |

A hit on a hard question moves the value a lot; a miss on an easy one moves it a lot the other way. One answer never flips a state.
Every constant is provisional and can be changed through environment variables (see the README).

## Keys

Before the answer is heard, Claude fixes 2-5 elements of the correct answer with `keys.sh` ("sets stopped @ 26").
After the answer, each key gets yes / no / contra, and `record.sh --verdict` derives the result:

- all yes → hit
- some no, no contra → partial
- any contra → miss

The user sees only the line numbers of missing keys ("not mentioned: L28-29"). The text stays in the log's miss column and feeds later questions.
Claude cannot write hit / miss directly (`--free` is for hand entry).

## Which function is asked next

Concepts are ranked from all repositories: not understood > fuzzy > unasked, lower value first. Understood concepts are never asked.
Candidates come from the current repository, excluding functions already asked and functions no longer present in the working tree.

The question type is decided here too (`edge` if the concept has past misses, else `trace`). The decision goes to `pending`,
and `record.sh` refuses any record that does not match it (exit 7). Claude decides only the wording and the keys.

## Tagging

After every commit, the hook sends the source of the touched functions to `claude -p` and asks for 1-3 concepts each.
The existing concept list is shown with "reuse an existing name whenever one fits", but new names are allowed.
The script validates the format and drops bad lines. `tag.sh --all` tags a whole repository at once.

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

## Where things live

```
~/.claude/hidane/            records (primary data)
  config                       lang=en
  <repo>/log.md                questions and answers
  <repo>/functions.md          function → concepts
  <repo>/pending, keys         the next question and its keys (deleted by record.sh)
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
| `help.sh` | fixed usage text (en / ja) | |
| (no script) | explanation level, decided by Claude from index and concept pages | ● |
| `scope.sh` | cut a commit into functions (15 languages, from reflect) | |
| `migrate.sh` | record-format migrations | |
| `hooks/post-commit` | run tag.sh in the background after a commit | |

The LLM decides three things: tags, merges, and the level of an explanation. The first two choose from a list and are validated by scripts.
The third only shapes prose and never touches the record.

## Research this leans on

Knowledge Tracing (BKT: one hit may be luck). KCGen-KT (show the existing list when asking an LLM for concepts).
Explain in Plain English / CGBG (do not grade the explanation text). Open Learner Models / Mastery Grids (concept-level visualization).
Anthropic, How AI Impacts Skill Formation (when AI use erodes understanding). Butler 1988; Kluger & DeNisi 1996 (scores reduce learning).
Kalyuga 2003 (explanations pitched at the wrong level hurt).
