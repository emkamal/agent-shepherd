# Subtask 2: Add Cost Column After `time_active`

## 1) Codebase Understanding

### What the system currently does
- `codex-tmux-nudger.sh` is the single runtime component.
- It tracks per-session state (`BUSY`, `IDLE`, `STUCK`, `COOLDOWN`, `NUDGED`, `EXITED`, `ERROR`, `MISSING`) and shows a live dashboard table.
- Session metrics currently include:
  - stuck detection count
  - nudge success count
  - cooldown time
  - cumulative active runtime (`time_active`)
- `EXITED` is currently detected from Codex output markers, but no token accounting/cost logic exists yet.

### How the relevant parts interact
- `scan_sessions()` captures pane output and determines mode transitions.
- `render_dashboard()` formats and prints the table each second.
- State and counters are stored in associative arrays keyed by session name.
- `price-list.csv` exists in repo root and defines model pricing columns:
  - `Input`, `Cached input`, `Output`

### Why this task exists
- TODO requires financial visibility for completed Codex sessions.
- On Codex exit, token usage output includes `input`, `cached`, and `output` counts.
- Dashboard needs a new `cost` column after `time_active`, computed from parsed token counts and `price-list.csv` rates.

### Constraints discovered from the code
- Script must remain Bash + tmux with minimal dependencies.
- Table formatting is fixed-width and should remain readable.
- `LINES_TO_CHECK=20` bounds available pane context, so parser must be robust to partial output.
- Pricing file may contain missing cached-input prices for some models.

## 2) Implementation Strategy

### Architecture decisions
- Add a pricing subsystem inside the Bash script:
  - load `price-list.csv` once at startup into associative arrays
  - parse Codex token usage line per exited session
  - compute USD cost and cache display string per session
- Introduce configurable model selection via `COST_MODEL` (default `gpt-5.1-codex`) because token usage line does not include model name in provided format.
- Keep cost computation read-only and non-blocking; parser failures should not break session scanning.

### Components affected
- `codex-tmux-nudger.sh`
  - new config vars: pricing file/model selection
  - new associative arrays for prices and per-session cost display
  - helper functions for numeric parsing and cost formatting
  - table rendering updates (new `cost` column)
  - exited-state path extended to parse and compute cost
- `README.md`
  - document cost column and new configuration knobs
- `price-list.csv`
  - add to version control as canonical pricing source

### Data flow changes
1. Startup: read `price-list.csv` -> fill model price maps.
2. Scan: when exit markers are found -> locate `Token usage:` line -> parse token counts.
3. Compute: apply model rates (`$/1M tokens`) to `input`, `cached`, `output`.
4. Persist: save per-session formatted cost string.
5. Render: append `cost` after `time_active`.

### Step-by-step execution plan
1. Add pricing config and arrays.
2. Implement helpers:
  - strip/normalize currency fields
  - load CSV prices
  - parse token usage line values
  - compute formatted USD string
3. Call pricing loader before main loop starts.
4. Extend exited branch in `scan_sessions()` to compute session cost.
5. Update dashboard header/row formatting with `cost` column.
6. Update README configuration and sample output description.
7. Validate syntax and helper behavior with command-level checks.

## 3) Logic Flow

- Existing scan flow remains unchanged until exit detection.
- On `EXITED` detection:
  - attempt token usage parse from captured pane lines
  - if parse + pricing lookup succeed, set session cost (e.g. `$1.234567`)
  - if not, keep fallback display (`n/a`) without affecting mode
- Render path:
  - `time_active` computed as before
  - `cost` printed immediately after `time_active`

## 4) Edge Cases

- Token usage line absent in captured lines:
  - show `n/a`; retain `EXITED`.
- Cached token segment missing:
  - treat cached tokens as `0`.
- Missing model in price list:
  - show `n/a` and emit session event reason.
- Missing/invalid price file:
  - continue running; all costs render as `n/a`.
- Very large token counts:
  - use integer micro-dollar arithmetic to avoid floating dependencies and precision drift.

## 5) Failure Handling

- Price load failures are recorded and handled gracefully; nudger core logic continues.
- Parse/compute failures only affect cost field, not state detection or nudging.
- No destructive operations or runtime restarts are introduced.

## 6) Assumptions

- Cost is calculated against a single configured model (`COST_MODEL`) for all monitored sessions.
- Pricing units in `price-list.csv` are USD per 1M tokens.
- `Token usage:` format remains consistent with TODO example.
