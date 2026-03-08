# Subtask 1: Improve Codex Interactive Exit Detection

## 1) Codebase Understanding

### What the system currently does
- The project is a single Bash supervisor script: `codex-tmux-nudger.sh`.
- It scans tmux sessions whose names start with `codex` every `CHECK_INTERVAL` seconds.
- For each observed session it captures the bottom `LINES_TO_CHECK` pane lines and derives a mode:
  - `BUSY` when `esc to interrupt` is visible.
  - `IDLE` when no stuck marker exists and no busy marker is present.
  - `STUCK`/`COOLDOWN`/`NUDGED` when a stuck condition is tracked and prompt/cooldown logic applies.
  - `ERROR` when pane capture fails or nudge send fails.
  - `MISSING` when a previously seen session is not found in a scan.
- It renders a live table with columns: `session`, `state`, `stuck_seen`, `nudges`, `cooldown`, `time_active`.

### How the relevant parts interact
- `scan_sessions()` computes per-session mode and events.
- `session_stuck` is persistent memory; once set, it only clears when `BUSY` marker appears.
- `render_dashboard()` displays current mode and counters.
- `update_active_clock()` accumulates `time_active` based on `is_active_mode()` decisions.
- `state_color()` controls visual coloring by state string.

### Why this task exists
- TODO requires distinguishing a normal Codex CLI termination from operational failures.
- Current behavior can surface `ERROR` for situations that are not true failures from an operator perspective.
- User expectation: when Codex interactive session exits, table state should show `EXITED` (explicit terminal state), not `ERROR`.

### Constraints discovered from the code
- State labels are constrained by 8-char table formatting (`%-8s`) so `EXITED` fits without layout changes.
- The script is intentionally lightweight Bash + tmux; no external parsers should be introduced.
- Existing stuck logic must remain stable (persistent stuck memory, cooldown gates, no interruption while busy).

## 2) Implementation Strategy

### Architecture decisions
- Add an explicit `EXITED` session state detected from Codex CLI termination output.
- Keep existing `ERROR` semantics for real failures (pane read failure, send-keys failure).
- Do not alter nudge cooldown/stuck control flow except where exit state should bypass nudge behavior.

### Components affected
- `codex-tmux-nudger.sh` only:
  - `state_color()` to colorize `EXITED`.
  - `scan_sessions()` to detect exit markers and set `EXITED`.
  - `is_active_mode()` if exited sessions should stop active time accumulation.

### Data flow changes
- Pane text -> new exit pattern detection -> session mode set to `EXITED` early in `scan_sessions()`.
- On exit detection, stuck memory for that session should be cleared to prevent stale nudging logic.

### Step-by-step execution plan
1. Add `EXITED_PATTERNS` with Codex exit markers (token usage + resume hint).
2. In scan loop, after busy check and before stuck detection, match exit patterns.
3. If exited detected: set `session_mode=EXITED`, clear `session_stuck`, set informative event, skip nudge path.
4. Update color map for `EXITED`.
5. Keep `is_active_mode()` unchanged for exited (non-active).
6. Validate script syntax with `bash -n`.
7. Review resulting diff for minimality and behavior alignment.

## 3) Logic Flow

- Current loop order (per session): pane capture -> busy detection -> stuck detection -> prompt detection -> cooldown -> nudge.
- New logic insertion:
  - pane capture
  - busy detection
  - **exited detection (new)**
  - stuck detection (existing)
- State transitions:
  - `BUSY -> EXITED` once exit marker appears.
  - `STUCK/COOLDOWN/NUDGED -> EXITED` once exit marker appears.
  - `EXITED` remains until session output changes in subsequent scans (e.g., new busy/stuck/idle markers).

## 4) Edge Cases

- Exit output appears alongside historical stuck text in the last lines:
  - Exit detection must take precedence to avoid false stuck nudges.
- Partial output window (only one exit marker visible):
  - Detection should work if either marker is visible.
- Non-Codex shell output containing similar text:
  - Scope limited to `codex*` tmux sessions already assumed to run Codex CLI.
- Empty pane:
  - Still treated as `ERROR` because that is an operational read failure.

## 5) Failure Handling

- If exit detection misfires, the next scan can still recover mode from fresh pane contents.
- Real tmux failures remain on `ERROR` path; this is untouched.
- No retries or destructive actions are introduced.

## 6) Assumptions

- Codex CLI exit output includes at least one stable marker:
  - `Token usage:` line and/or
  - `To continue this session, run codex resume`.
- `EXITED` should be considered a non-active state for `time_active` accounting.
- First subtask only changes state detection, not cost calculation (handled in subsequent TODO item).
