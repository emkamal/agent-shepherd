# agent-shepherd

Keep your AI coding agents moving.

`agent-shepherd` supervises long-running terminal AI agents (like Codex CLI) running inside tmux and automatically nudges them when they get stuck or disconnected.

This lets you run multiple coding agents overnight without babysitting them.

When a session stalls, `agent-shepherd` detects the prompt and sends `continue` so the agent resumes work.

---

## Why this exists

When running AI coding agents like Codex CLI, they occasionally stop because of issues like:

- `stream disconnected before completion`
- network hiccups
- API interruptions
- incomplete streaming responses

When this happens, the agent often sits at a prompt waiting for:

```
continue
```

Normally you would have to manually type it and press Enter.

If you run multiple agents, this becomes annoying quickly.

`agent-shepherd` automates that job.

It watches all your agent tmux sessions and nudges them when needed.

So you can go to sleep while your agents keep coding.

---

## Features

- supervises multiple AI agent sessions
- detects disconnected or stalled prompts
- auto-sends `continue` to resume work
- once-per-prompt safety (no infinite nudging)
- verbose logging
- very lightweight (pure bash + tmux)

---

## How it works

1. AI agents run inside tmux sessions.

Example:

```
tmux new -s codex1
codex
```

```
tmux new -s codex2
codex
```

2. `agent-shepherd` periodically scans the sessions.

3. If it detects:

```
■ stream disconnected before completion: response.failed event received
```

and a prompt like:

```
› continue
```

it automatically sends:

```
continue + ENTER
```

so the agent resumes.

---

## Requirements

- Linux / WSL / macOS
- `tmux`
- `bash`

---

## Installation

Clone the repo:

```
git clone https://github.com/YOURNAME/agent-shepherd.git
cd agent-shepherd
```

Make the script executable:

```
chmod +x agent-shepherd.sh
```

---

## Usage

Start your agents in tmux sessions.

Example:

```
tmux new -s codex1
codex
```

```
tmux new -s codex2
codex
```

Then run the supervisor:

```
./agent-shepherd.sh
```

You will see logs like:

```
Starting Agent Shepherd

Checking session codex1
Prompt detected
Nudging agent with "continue"

Checking session codex2
Agent still running
```

The script will keep running and checking sessions every few seconds.

---

## Example Workflow

Start multiple agents:

```
tmux new -s codex1
tmux new -s codex2
tmux new -s codex3
```

Launch Codex inside each:

```
codex
```

Then run:

```
./agent-shepherd.sh
```

Leave your machine running overnight.

If any agent disconnects or stalls, `agent-shepherd` nudges it automatically.

---

## Supported Agents

Currently tested with:

- OpenAI Codex CLI

Planned support:

- Claude Code
- Aider
- other terminal coding agents

---

## Roadmap

Possible future improvements:

- configurable agent session prefixes
- smarter stuck detection
- Slack / Discord notifications
- agent restart if fully crashed
- web dashboard
- agent performance metrics

---

## Philosophy

AI coding agents are powerful, but they still need occasional supervision.

Instead of babysitting them manually, `agent-shepherd` keeps them moving while you focus on other things.

Or sleep.

---

## License

MIT
