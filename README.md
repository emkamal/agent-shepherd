# agent-shepherd

Keep your AI coding agents moving.

`agent-shepherd` supervises long-running terminal AI agents (like Codex CLI) running inside tmux and automatically nudges them when they get stuck or disconnected.

This lets you run multiple coding agents overnight without babysitting them.
When a session stalls, `agent-shepherd` detects the prompt and sends `continue` so the agent resumes work.

---

## Why this exists

When running AI coding agents like Codex CLI, they occasionally stop mid-task because of:

- `stream disconnected before completion`
- network hiccups
- API interruptions
- incomplete streaming responses

When this happens, the agent sits at a prompt waiting for you to type:

```
continue
```

Normally you'd have to manually type it and press Enter.
If you're running multiple agents overnight, this gets old fast.

`agent-shepherd` automates that job.

---

## How it works

1. Your agents run inside named tmux sessions prefixed with `codex`:

```bash
tmux new -s codex1
codex

tmux new -s codex2
codex
```

2. `codex-tmux-nudger.sh` scans all `codex*` sessions every 15 seconds.

3. For each session it follows this logic:

  - If `esc to interrupt` is visible -> agent is **actively working**, leave it alone
  - If a disconnect/error message is detected -> mark session as **stuck** in memory
  - If stuck AND an input prompt (`›` or `>`) is visible AND cooldown has passed -> **nudge**
  - Stuck state persists in memory even after the error message scrolls out of view
  - Stuck state clears only when `esc to interrupt` reappears, confirming the agent resumed

4. It renders a live dashboard each second showing per-session state and counters:

  - `BUSY`, `IDLE`, `STUCK`, `COOLDOWN`, `NUDGED`, `ERROR`, `MISSING`
  - Stuck detections per session
  - Successful nudge count
  - Remaining cooldown
  - Cumulative active time

5. The nudge is sent as two separate tmux `send-keys` calls: first `continue`, then `Enter`.

---

## Features

- Supervises multiple agent sessions simultaneously
- Detects disconnected or stalled prompts
- **Never interrupts an actively working agent** via `esc to interrupt` detection
- Persistent stuck state, so it is not fooled when error text scrolls out of view
- Cooldown between nudges (default 45s) to avoid spamming
- Live terminal dashboard with per-session state, counters, and active runtime
- Pure bash + tmux, no extra dependencies

---

## Requirements

- Linux or WSL
- `tmux`
- `bash`

---

## Installation

```bash
git clone https://github.com/YOURNAME/agent-shepherd.git
cd agent-shepherd
chmod +x codex-tmux-nudger.sh
```

---

## Usage

Start your agents in tmux sessions named with the `codex` prefix:

```bash
tmux new -s codex1
# inside the session:
cd /path/to/your/repo
codex
# detach with Ctrl+b d
```

Repeat for as many agents as you want (`codex2`, `codex3`, etc.).

Then run the nudger in a separate terminal (outside of any tmux session):

```bash
./codex-tmux-nudger.sh
```

You'll see live output like:

```
Codex Nudger v12 (live dashboard)  2026-03-07 01:10:00
CHECK_INTERVAL=15s  NUDGE_COOLDOWN=45s  LINES_TO_CHECK=20
Active=2  Seen=2  CurrentlyStuck=1  TotalNudges=5  (Ctrl+C to stop)

session            | state    |  stuck_seen |      nudges | cooldown | time_active
-------------------+----------+-------------+-------------+----------+------------
codex1             | BUSY     |           1 |           2 | -        |   00:32:14
codex2             | COOLDOWN |           2 |           3 | 18s      |   00:29:41
```

---

## Configuration

Edit the variables at the top of `codex-tmux-nudger.sh`:

| Variable | Default | Description |
|---|---|---|
| `CHECK_INTERVAL` | `15` | Seconds between scans |
| `NUDGE_COOLDOWN` | `45` | Minimum seconds between nudges per session |
| `LINES_TO_CHECK` | `20` | Lines captured from the bottom of each pane |

Stuck/error detection patterns are also configurable in `STUCK_PATTERNS`:

- `stream disconnected before completion`
- `response.failed event received`
- `Conversation interrupted`
- `Something went wrong`

---

## Supported Agents

Currently tested with:

- OpenAI Codex CLI

The stuck detection patterns and busy indicator are specific to Codex CLI's output format. Other agents may use different messages — contributions welcome.

---

## Roadmap

- Configurable session name prefix (currently hardcoded to `codex`)
- Auto-restart fully crashed sessions
- Slack / Discord / webhook notifications on nudge or crash
- Support for other agents (Claude Code, Aider, etc.)

---

## Philosophy

AI coding agents are powerful but they still need occasional supervision.
Instead of babysitting them manually, `agent-shepherd` keeps them moving while you focus on other things.

Or sleep.

---

## License

MIT
