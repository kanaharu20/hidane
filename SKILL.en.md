---
name: hidane
description: Pick one function you have not been asked about yet, ask exactly one question, check the answer against the real code, and record it in log.md. Claude never explains; a miss is pointed at by line number only. No scores. The record feeds the Obsidian map (~/Documents/hidane). Trigger on "/hidane", "check my understanding", "quiz me on my code", "one question from the unasked". Not for review or fix requests.
---

# hidane — one question from the unasked

One function, one question per invocation. Answer, record, stop. Call again for another.
**Use script output verbatim. Do not rebuild it.**

## Arguments (`$ARGUMENTS`)

- `--vault` … run `sh <HIDANE>/scripts/open.sh`, show its single output line, stop. No question.
- `--map` … run `sh <HIDANE>/scripts/map.sh`, show the table as is, stop. No question.
- `--lint` … run `sh <HIDANE>/scripts/lint.sh`, show its output as is, stop. No question.
- `--explain <topic>` … the "Explain" steps below. No question. The topic is free text (a function, a concept, printf, "is this design ok").
- `--update` … run `sh "$(cat <HIDANE>/HOME)/install.sh" --update` to get the latest version, show its output as is, stop. No question.
- none … follow the steps below.

## Steps

1. **Pick**: run `sh <HIDANE>/scripts/next.sh`. Use its Place / Function / Concepts / Type / Input candidates / Question form. **The type is decided by next.sh. Never change it.**
   On exit 1 (no candidates), relay the single stderr line to the user and stop.
2. **Read**: read the range `file:a-b` with Read. **Do not show or explain it to the user.**
3. **Fix the keys**: once the question is decided and before asking, fix 2-5 elements of the correct answer:
   ```
   sh <HIDANE>/scripts/keys.sh "<fact 1> @ <line>" "<fact 2> @ <line>" ...
   ```
   A key is one concrete, checkable fact (a return value, a function called, an order, a branch taken). "@ line" is where it lives (ranges allowed).
   Never use a sentence that would be true of any function ("something happens and it ends"). **Never show the keys to the user.**
4. **Ask**: fit exactly one question into the "Question form". Pick one concrete value from "Input candidates".
   - The form is always "Given <input>, what does it return / what happens?". Never ask "why", "what is needed", "what should be done" (they reveal that an answer exists).
   - At most 3 lines. Place and function first. No code quotes. No hints. Never two questions.
   - Ask in the language the user writes in.
5. **Wait** for the answer. "I don't know" is a valid answer. Do not prompt, do not ask to rephrase.
6. **Judge per key**: compare the answer against each key and mark it `yes` (states that fact specifically) / `no` (does not mention it) / `contra` (says the opposite).
   - Paraphrases count as yes. A generic statement that would fit any function does not.
   - Do not decide hit / partial / miss yourself; record.sh derives it from the verdicts.
7. **Record**: run the following and show its output verbatim (first line: result and line numbers of missing keys; second line: the record).
   ```
   sh <HIDANE>/scripts/record.sh "<place>" "<function>" "<concepts>" "<type>" "<question summary, ~20 chars>" --verdict "yes,no,contra,..." ""
   ```
   For "don't know" / no answer, pass `dunno` / `skip` instead of `--verdict`.
   type is `trace` / `edge` / `summary`. Place, function, concepts and type must be exactly what next.sh printed, or record.sh refuses (exit 7).
   Add nothing after record.sh's output: no explanation, no correct answer, no encouragement.
8. **Stop.** No summary, no next steps, no encouragement.

## Explain (`--explain <topic>`)

The map is a memory of what this person understands. Read it before explaining and calibrate to them.

1. **Entry point**: Read `~/Documents/hidane/index.md` (path changes with `HIDANE_VAULT`; if missing, run `sh <HIDANE>/scripts/pages.sh` first). Take in "Overall" (counts per state, questions answered), "Recent explanations requested", and the concept table.
2. **Follow the trail**: pick 3-5 concepts related to the topic from the table and Read `concepts/<concept>.md` for each: past misses, the user's functions tagged with it, records. If the topic is not in the map's vocabulary (printf, say), map it yourself to the nearest concepts. If nothing is near, calibrate to "Overall".
3. **Set the level**: understood concepts are skipped (assumed, not even named). Not-understood ones get the careful treatment, starting from the past misses, pointing at lines. Fuzzy: normal. Unasked: one sentence. If the same topic appears under "Recent explanations", continue from there instead of repeating basics.
4. **Open with two lines "From the map"** (before the explanation, so the reader sees what was read and what changed):
   ```
   From the map: not understood <concept, concept> → starting there. Fuzzy <concept>. Used <N> past misses
   Skipped: <understood concepts, or "none">. If the topic is off the map: "<topic> mapped to <concept>"
   ```
   State names and concept names only. No values, percentages or evaluative words.
5. **Write**: use the user's own functions as examples when they fit (`file:a-b`). No quiz. No scores or evaluative words. Quote at most 3 lines of code. Write in the user's language.
6. **Log it**: `sh <HIDANE>/scripts/explained.sh "<topic>" "<mapped concept, concept>"` (1-2 names from the table; `""` if none). Show its one output line. State and colors do not change.
7. Stop. Do not offer a follow-up question.

## Never

- Explain the code before asking. Feedback stops at the line numbers record.sh prints. Never reveal what a missing key says.
- Ask without keys in place, or rewrite keys after seeing the answer.
- Output scores, percentages, or evaluative words ("you understand this well").
- Record a second answer. The record is the first answer.
- Ask more than one question per invocation, even if asked to widen the scope.
- Write to log.md by any means other than record.sh. Never pass --free. Never pass hit / miss directly.
- Read record.sh's source before running it; the usage above is complete.

`<HIDANE>` is the directory containing this SKILL.md.
