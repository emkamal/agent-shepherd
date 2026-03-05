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

2. `agent-shepherd` scans all `codex*` sessions every 15 seconds.

3. For each session it follows this logic:

   - If `esc to interrupt` is visible → agent is **actively working**, leave it alone
   - If a disconnect/error message is detected → mark session as **stuck** in memory
   - If stuck AND an input prompt (`›` or `>`) is visible AND cooldown has passed → **nudge**
   - Stuck state persists in memory even after the error message scrolls out of view
   - Stuck state clears only when `esc to interrupt` reappears, confirming the agent resumed

4. The nudge is sent as two separate tmux `send-keys` calls — first `continue`, then `Enter` — because passing them together causes tmux to type the word `Enter` literally instead of pressing it.

---

## Features

- Supervises multiple agent sessions simultaneously
- Detects disconnected or stalled prompts
- **Never interrupts an actively working agent** — busy detection via `esc to interrupt`
- Persistent stuck state — not fooled when the error message scrolls out of view
- Cooldown between nudges (default 45s) to avoid spamming
- Verbose terminal output + log file (`~/codex-nudger.log`)
- Pure bash + tmux — no dependencies

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
chmod +x agent-shepherd.sh
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

Then run agent-shepherd in a separate terminal (outside of any tmux session):

```bash
./agent-shepherd.sh
```

You'll see live output like:

```
Fri Mar  6 01:10:00 - Checking [codex1] (stuck_state=false)...
  Status: 'gpt-5.3-codex high · 77% left · /path/to/repo'
  BUSY — leaving alone.
Fri Mar  6 01:10:00 - Checking [codex2] (stuck_state=false)...
  Status: 'gpt-5.3-codex high · 54% left · /path/to/repo'
  STUCK detected: 'stream disconnected before completion'
  Prompt ready: '› continue'
  NUDGING [codex2]...
  Nudge sent.
```

Logs are also written to `~/codex-nudger.log`.

---

## Configuration

Edit the variables at the top of `agent-shepherd.sh`:

| Variable | Default | Description |
|---|---|---|
| `CHECK_INTERVAL` | `15` | Seconds between scans |
| `NUDGE_COOLDOWN` | `45` | Minimum seconds between nudges per session |
| `LINES_TO_CHECK` | `20` | Lines captured from the bottom of each pane |
| `LOG` | `~/codex-nudger.log` | Log file path |

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
