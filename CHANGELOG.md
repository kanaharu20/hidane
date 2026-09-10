# Changelog

## 0.2.0 — 2026-09-10

- `/hidane --explain [place]`: explanations calibrated to the map (skip / expand / normal / one sentence per concept,
  decided by `profile.sh`; Claude writes only the prose). Logged in `explained.md`; the function is asked first 1-3 days
  later and not on the same day.
- `next.sh` skips functions no longer present in the working tree.
- Keys fixed before the question; hit / partial / miss derived from per-key verdicts; `partial` result.
- 137 L0 tests; `run_all.sh` checks that the READMEs state the real count.

## 0.1.0 — 2026-09-09

First version shared with testers.

- One question per `/hidane`; keys fixed before the answer; hit / partial / miss derived from per-key verdicts
- Concept tagging at commit time (`tag.sh`, hook) and `--all` for the whole repository
- Map as an Obsidian vault with traffic-light colors; state computed from `log.md` only
- Cross-repository concept ranking; `lint` merges concept names via aliases without rewriting records
- English / Japanese chosen at setup; language-neutral record vocabulary
- One-command setup (`install.sh`), `install.sh --update`, `migrate.sh` for record-format changes
- 125 L0 tests, no LLM needed; run_all.sh checks that the READMEs state the real count
