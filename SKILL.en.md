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

## Never

- Explain the code before asking. Feedback stops at the line numbers record.sh prints. Never reveal what a missing key says.
- Ask without keys in place, or rewrite keys after seeing the answer.
- Output scores, percentages, or evaluative words ("you understand this well").
- Record a second answer. The record is the first answer.
- Ask more than one question per invocation, even if asked to widen the scope.
- Write to log.md by any means other than record.sh. Never pass --free. Never pass hit / miss directly.
- Read record.sh's source before running it; the usage above is complete.

`<HIDANE>` is the directory containing this SKILL.md.
