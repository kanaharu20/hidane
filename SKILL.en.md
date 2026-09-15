---
name: hidane
description: Pick one function you have not been asked about yet, ask exactly one question, check the answer against the real code, and record it in log.md. Claude never explains; a miss is pointed at by line number only. No scores. The record feeds the Obsidian map (~/Documents/hidane). Trigger on "/hidane", "check my understanding", "quiz me on my code", "one question from the unasked". Not for review or fix requests.
---

# hidane — one question from the unasked

One function, one question per invocation. Answer, record, stop. Call again for another.
**Use script output verbatim. Do not rebuild it.**

## Arguments (`$ARGUMENTS`)

- `--help` / `-h` … run `sh <HIDANE>/scripts/help.sh`, show its output as is, stop. No question.
- `--vault` … run `sh <HIDANE>/scripts/open.sh`, show its single output line, stop. No question.
- `--map` … run `sh <HIDANE>/scripts/map.sh`, show the table as is, stop. No question.
- `--lint` … run `sh <HIDANE>/scripts/lint.sh`, show its output as is, stop. No question.
- `--tag` … run `sh <HIDANE>/scripts/tag.sh --all --bg`. The functions of the current repository not on the map yet get tagged (uncommitted ones included; the LLM calls run in the background, so it returns in seconds). Show its one output line as is, stop. Do not wait or check on it. No question.
- `--update` … run `sh "$(cat <HIDANE>/HOME)/install.sh" --update` to get the latest version, show its output as is, stop. No question.
- `--weak` … the "Weak spots" steps below. No question.
- text that does not start with a flag (`/hidane what is _us?`, `/hidane the part I missed in the last question`) … the "Explain" steps below. No question.
- none … follow the steps below.

## Steps

1. **Pick**: run `sh <HIDANE>/scripts/next.sh`. Use its Place / Function / Concepts / Type / Input candidates / Question form. **The type is decided by next.sh. Never change it.**
   On exit 1 (no candidates), relay the single stderr line to the user and stop.
2. **Read**: read the range `file:a-b` with Read. **Do not show or explain it to the user.**
3. **Fix the keys**: once the question is decided and before asking, fix 2-5 elements of the correct answer:
   ```
   sh <HIDANE>/scripts/keys.sh "<kind>: <fact 1> @ <line>" "<kind>: <fact 2> @ <line>" ...
   ```
   A key is one concrete, checkable fact, prefixed with its kind: `return:` `branch:` `call:` `order:` `state:` (keys.sh rejects a key without one). "@ line" is where it lives (ranges allowed).
   keys.sh prints a second line, "Include in your answer: return value 1, branch 2": **kinds and counts only**. It becomes the last line of the question (step 4), so every fact you made a key is inside what the user is asked to answer. Keep the keys to what the question asks: for "what does it return", one return value and the 1-2 branches that decide it are enough.
   **Keys are only the facts that decide the answer to this question.** If the question is "what does it return", the keys are the return value and the branches or comparisons that decide it. Do not make keys out of things the question did not ask for, such as how a lock is taken or an intermediate arithmetic value (if the answer is correct without it, it is not a key).
   **Keys are outcomes, never reasons.** "line 59 checks only is_done, so it does not end" is a reason (an answer to "why"), and the question did not ask why. Write only what happens: "the condition at line 59 stays true and the loop continues" (keys.sh rejects keys containing "because").
   For "where does it exit" or "what is called next", the keys run to the end of that flow (what the called function returns, where it exits). For "what does it return", intermediate steps are not keys.
   Never use a sentence that would be true of any function ("something happens and it ends"). **Never show the keys to the user.**
4. **Ask**: fit exactly one question into the "Question form". Pick one concrete value from "Input candidates".
   - The form is always "Given <input>, what does it return / what is called next / where does it exit?". Name one observable thing. Vague targets such as "what happens to the loop" or "how does it behave" leave the answer's granularity open and never line up with the keys. The input is a concrete value or one situation ("stop is raised during the debug phase").
   - Never ask "why", "what is needed", "what should be done" (they reveal that an answer exists). Do not widen the question with "including the process" or "and why".
   - **The last line is the "Include in your answer: …" line keys.sh printed, verbatim.** No key contents, no line numbers: kinds and counts only.
   - At most 4 lines including it. Place and function first. No code quotes. No hints. Never two questions.
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
   type is `trace` / `edge` / `summary`. Place, function, concepts and type must be exactly what next.sh printed; if they differ, if next.sh was not run, or if the keys are stale (fixed before this next.sh run), record.sh refuses (exit 7).
   Add nothing after record.sh's output: no explanation, no correct answer, no encouragement.
8. **Stop.** No summary, no next steps, no encouragement.

## Explain (text without a flag)

The map is a memory of what this person understands. Read it before explaining and calibrate to them.

1. **Entry point**: Read `~/Documents/hidane/index.md` (path changes with `HIDANE_VAULT`; if missing, run `sh <HIDANE>/scripts/pages.sh` first). Take in "Overall" (counts per state, questions answered), "Recent explanations requested", and the concept table.
2. **Follow the trail**: pick 3-5 concepts related to the topic from the table and Read `concepts/<concept>.md` for each: past misses, the user's functions tagged with it, records. If the topic is not in the map's vocabulary (printf, say), map it yourself to the nearest concepts. If nothing is near, calibrate to "Overall".
3. **Set the level**: understood concepts are skipped (assumed, not even named). If the text refers to the last question ("the last one", "what I missed"), find log.md with `sh <HIDANE>/scripts/record.sh --path`; the last row's miss column lists the keys marked "not mentioned" / "contradicted": explain those first, pointing at their lines, and leave the keys that were hit alone. Not-understood ones get the careful treatment, starting from the past misses, pointing at lines. Fuzzy: normal. Unasked: one sentence. If the same topic appears under "Recent explanations", continue from there instead of repeating basics.
4. **Open with two lines "From the map"** (before the explanation, so the reader sees what was read and what changed):
   ```
   From the map: not understood <concept, concept> → starting there. Fuzzy <concept>. Used <N> past misses
   Skipped: <understood concepts, or "none">. If the topic is off the map: "<topic> mapped to <concept>"
   ```
   State names and concept names only. No values, percentages or evaluative words.
5. **Write**: use the user's own functions as examples when they fit (`file:a-b`). No quiz. No scores or evaluative words. Quote at most 3 lines of code. Write in the user's language.
6. **Log it**: `sh <HIDANE>/scripts/explained.sh "<topic>" "<mapped concept, concept>"` (1-2 names from the table; `""` if none). Show its one output line. State and colors do not change.
7. Stop. Do not offer a follow-up question.

## Weak spots (`--weak`)

Fold the past misses into one page and show the reader where they stumble. The script reads the map; Claude writes the page.

1. Run `sh <HIDANE>/scripts/weak.sh`. On exit 1 show its single stderr line and stop.
   Output: two opening lines (From the map / Skipped), one heading per concept with every miss (newest first), and the functions tagged with that concept in the current repository.
2. Put the **two opening lines verbatim** at the top of the page. Do not reword them.
3. Read 3-5 of the listed functions that sit closest to the misses (`file:a-b`). The `@line` in a miss is from that day; find the spot in the current code.
4. Write three sections, with exactly these headings.
   - **The pattern**: fold the misses into one shape ("the story stops where the flag is set"). Quote up to 3 miss texts, then say the common shape in 2-3 sentences. One pattern per concept if there are several.
   - **The flow**: the order to follow for that concept as a numbered flow of 3-5 steps, and which steps the misses land on ("the misses are at steps 2 and 4").
   - **Step by step**: explain each step by pointing at lines in the reader's own functions (`file:a-b`). Steps with misses get the careful treatment; steps that were hit get one sentence. Where it connects to another concept, point at the one line of the reader's code that makes the connection.
5. No scores, ratios or judgement words ("understands well", "weak" as a verdict). Code quotes 3 lines at most. No question. In the user's language.
6. Run `sh <HIDANE>/scripts/explained.sh "weak spots" "<concept, concept>"` (1-2 of the not-understood concepts from the first line). Show its one output line. State and colors do not change.
7. Stop. No "shall I ask a question next".

## Never

- Explain the code before asking. Feedback stops at the line numbers record.sh prints. Never reveal what a missing key says.
- Ask without keys in place, or rewrite keys after seeing the answer.
- Output scores, percentages, or evaluative words ("you understand this well").
- Record a second answer. The record is the first answer.
- Ask more than one question per invocation, even if asked to widen the scope.
- Write to log.md by any means other than record.sh. Never pass --free. Never pass hit / miss directly.
- Read record.sh's source before running it; the usage above is complete.

`<HIDANE>` is the directory containing this SKILL.md.
