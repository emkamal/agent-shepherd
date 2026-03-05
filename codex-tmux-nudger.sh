#!/bin/bash
# codex-tmux-nudger.sh
#
# Automatically nudges OpenAI Codex sessions running inside tmux
# when they disconnect mid-task ("stream disconnected before completion").
# Works on Linux and WSL.
#
# Background:
#   Codex sometimes loses its stream connection during long tasks and stops
#   with a prompt waiting for "continue". This script detects that state and
#   submits "continue" automatically, so you can leave Codex agents running
#   overnight without babysitting them.
#
# Requirements:
#   - Linux or WSL
#   - tmux
#   - Codex sessions named with the prefix "codex" (e.g. codex1, codex2)
#
# Usage:
#   chmod +x codex-tmux-nudger.sh
#   ./codex-tmux-nudger.sh
#
#   Run this in a plain terminal or a dedicated detached tmux session.
#   Do NOT run it inside one of the codex* sessions you want to monitor.
#
# How it works:
#   Every CHECK_INTERVAL seconds, the script scans all tmux sessions whose
#   names start with "codex". For each session it:
#     1. Skips it if Codex is actively working ("esc to interrupt" visible)
#     2. Marks it as stuck if a disconnect/error message is found
#     3. Once marked stuck, waits for an input prompt (› or >) to appear
#     4. Submits "continue" + Enter when the prompt is ready and cooldown passed
#     5. Clears the stuck state only when Codex resumes working
#
#   Stuck state is tracked in memory so it persists even after the disconnect
#   message scrolls out of the visible pane area.
#
# Logs are written to ~/codex-nudger.log

# ── Configuration ────────────────────────────────────────────────────────────

CHECK_INTERVAL=15       # seconds between scans
NUDGE_COOLDOWN=45       # minimum seconds between nudges on the same session
LINES_TO_CHECK=20       # lines captured from the bottom of each pane
LOG=~/codex-nudger.log

# ── Stuck indicators ─────────────────────────────────────────────────────────
# Any of these strings appearing in the pane marks the session as stuck.

STUCK_PATTERNS=(
    "stream disconnected before completion"
    "response.failed event received"
    "Conversation interrupted"
    "Something went wrong"
)

# ── State ────────────────────────────────────────────────────────────────────

declare -A last_nudged_time     # epoch timestamp of last nudge per session
declare -A session_stuck        # "true" / "false" per session

# ── Main loop ────────────────────────────────────────────────────────────────

echo "$(date) - Starting codex-tmux-nudger" | tee -a "$LOG"
echo "  CHECK_INTERVAL=${CHECK_INTERVAL}s  NUDGE_COOLDOWN=${NUDGE_COOLDOWN}s  LINES_TO_CHECK=${LINES_TO_CHECK}" | tee -a "$LOG"
echo "$(printf '─%.0s' {1..60})" | tee -a "$LOG"

while true; do
    sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep '^codex')

    if [ -z "$sessions" ]; then
        echo "$(date) - No codex* sessions found, waiting..." | tee -a "$LOG"
    else
        for session in $sessions; do
            echo "$(date) - [$session] stuck=${session_stuck[$session]:-false}" | tee -a "$LOG"

            lines=$(tmux capture-pane -pt "$session" 2>/dev/null | tail -n "$LINES_TO_CHECK")

            if [ -z "$lines" ]; then
                echo "  [$session] Pane empty or unreachable, skipping." | tee -a "$LOG"
                continue
            fi

            # Log the status bar (last line) for context
            echo "  Status: $(echo "$lines" | tail -n 1)" | tee -a "$LOG"

            # 1. If Codex is actively working, clear stuck state and leave it alone
            if echo "$lines" | grep -qF "esc to interrupt"; then
                echo "  BUSY — leaving alone." | tee -a "$LOG"
                session_stuck[$session]="false"
                continue
            fi

            # 2. Check for stuck indicators and update persistent state
            for pattern in "${STUCK_PATTERNS[@]}"; do
                if echo "$lines" | grep -qF "$pattern"; then
                    if [ "${session_stuck[$session]}" != "true" ]; then
                        echo "  STUCK detected: '$pattern'" | tee -a "$LOG"
                        session_stuck[$session]="true"
                    fi
                    break
                fi
            done

            if [ "${session_stuck[$session]}" != "true" ]; then
                echo "  Not stuck, nothing to do." | tee -a "$LOG"
                continue
            fi

            # 3. Wait for an input prompt to be visible
            prompt_line=$(echo "$lines" | grep -E "^[>›]" | tail -n 1)
            if [ -z "$prompt_line" ]; then
                echo "  Stuck but prompt not visible yet, waiting..." | tee -a "$LOG"
                continue
            fi

            echo "  Prompt ready: '$prompt_line'" | tee -a "$LOG"

            # 4. Respect cooldown between nudges
            now=$(date +%s)
            elapsed=$(( now - ${last_nudged_time[$session]:-0} ))

            if [ "$elapsed" -lt "$NUDGE_COOLDOWN" ]; then
                echo "  Cooldown: $(( NUDGE_COOLDOWN - elapsed ))s remaining, skipping." | tee -a "$LOG"
                continue
            fi

            # 5. Nudge: type "continue" then submit with a separate Enter call
            #    (passing "continue" Enter in one call types the word "Enter" literally)
            echo "  NUDGING [$session]..." | tee -a "$LOG"
            tmux send-keys -t "$session" "continue"
            sleep 0.1
            tmux send-keys -t "$session" "" Enter
            last_nudged_time[$session]=$now
            echo "  Nudge sent." | tee -a "$LOG"
        done
    fi

    echo "  Sleeping ${CHECK_INTERVAL}s..." | tee -a "$LOG"
    sleep "$CHECK_INTERVAL"
done
