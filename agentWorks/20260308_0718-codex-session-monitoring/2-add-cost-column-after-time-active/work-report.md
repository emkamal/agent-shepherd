# Work Report - Subtask 2

## Summary of task
- Added per-session cost estimation and a new `cost` dashboard column after `time_active`.

## What was implemented
- Added pricing configuration:
  - `PRICE_LIST_FILE` (default `price-list.csv`)
  - `COST_MODEL` (default `gpt-5.1-codex`)
- Added pricing/token helper functions in `codex-tmux-nudger.sh`:
  - `price_to_micros`
  - `load_price_table`
  - `parse_token_usage_triplet`
  - `calculate_cost_display`
- Loaded pricing table once at startup.
- Extended `EXITED` handling in `scan_sessions()`:
  - parse `input`, `cached`, `output` token counts from `Token usage: ...`
  - compute session USD cost using loaded model rates
  - store display value in `session_cost` map (fallback `n/a` when unavailable)
- Updated dashboard render:
  - added config line showing `COST_MODEL` and `PRICE_LIST_FILE`
  - added `cost` column after `time_active`
- Updated README:
  - documented cost behavior and new config variables
  - updated sample output to include cost column
- Added `price-list.csv` to version control as pricing source.

## Files modified
- `codex-tmux-nudger.sh`
- `README.md`
- `price-list.csv`
- `agentWorks/20260308_0718-codex-session-monitoring/2-add-cost-column-after-time-active/plan.md`
- `agentWorks/20260308_0718-codex-session-monitoring/2-add-cost-column-after-time-active/work-report.md`

## Architectural decisions
- Use integer micro-dollar arithmetic for deterministic Bash-only cost computation.
- Keep cost logic non-blocking: parser/price failures affect only the `cost` display, not supervisor behavior.
- Use configurable single-model pricing (`COST_MODEL`) because the provided exit line does not include model identity.

## Tests added
- No native test suite exists; validated via command-level checks:
  - `bash -lc "tr -d '\r' < codex-tmux-nudger.sh | bash -n"`
  - sourced script functions (loop excluded) and verified:
    - token triplet parse from TODO sample
    - computed cost output (`$33.807433`) for default model pricing.

## Risks or follow-ups
- If Codex output format changes, token parser regex may need updates.
- Per-session model auto-detection is not implemented; current behavior uses configured `COST_MODEL`.

## Assumptions made
- Pricing values are USD per 1M tokens.
- Example token usage format in TODO is representative of real exit output.
