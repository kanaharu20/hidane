# Changelog

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
