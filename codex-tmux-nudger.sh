#!/bin/bash
# ~/codex-nudger-multi-v12.sh
# Codex Nudger v12 — WSL + tmux (live dashboard mode)

CHECK_INTERVAL=15       # seconds between scans
NUDGE_COOLDOWN=45       # minimum seconds between nudges per session
LINES_TO_CHECK=20       # how many lines from the bottom of the pane to inspect

STUCK_PATTERNS=(
    "stream disconnected before completion"
    "response.failed event received"
    "Conversation interrupted"
    "Something went wrong"
)

declare -A last_nudged_time
declare -A session_stuck
declare -A session_seen
declare -A stuck_detect_count
declare -A nudge_success_count
declare -A session_mode
declare -A session_event
declare -A session_cooldown
declare -A session_active_total
declare -A session_active_last_ts
declare -A session_active_running

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED_BRIGHT=$'\033[91m'
    C_GREEN_BRIGHT=$'\033[92m'
    C_YELLOW_BRIGHT=$'\033[93m'
    C_CYAN_BRIGHT=$'\033[96m'
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_RED_BRIGHT=""
    C_GREEN_BRIGHT=""
    C_YELLOW_BRIGHT=""
    C_CYAN_BRIGHT=""
fi

clean_text() {
    local text="$1"
    text=$(printf '%s' "$text" | tr '\r\n' '  ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')
    printf '%s' "$text"
}

truncate_text() {
    local text max
    text=$(clean_text "$1")
    max="$2"
    if (( ${#text} <= max )); then
        printf '%s' "$text"
    elif (( max > 3 )); then
        printf '%s...' "${text:0:max-3}"
    else
        printf '%s' "${text:0:max}"
    fi
}

state_color() {
    case "$1" in
        BUSY|IDLE) printf '%s' "${C_GREEN_BRIGHT}${C_BOLD}" ;;
        STUCK|ERROR) printf '%s' "${C_RED_BRIGHT}${C_BOLD}" ;;
        COOLDOWN) printf '%s' "${C_YELLOW_BRIGHT}${C_BOLD}" ;;
        NUDGED) printf '%s' "${C_CYAN_BRIGHT}${C_BOLD}" ;;
        MISSING) printf '%s' "${C_DIM}" ;;
        *) printf '' ;;
    esac
}

format_hhmmss() {
    local total h m s
    total="${1:-0}"
    (( total < 0 )) && total=0
    h=$(( total / 3600 ))
    m=$(( (total % 3600) / 60 ))
    s=$(( total % 60 ))
    printf '%02d:%02d:%02d' "$h" "$m" "$s"
}

is_active_mode() {
    case "$1" in
        BUSY|STUCK|COOLDOWN|NUDGED) return 0 ;;
        *) return 1 ;;
    esac
}

update_active_clock() {
    local session should_run now total last running
    session="$1"
    should_run="$2"
    now="$3"
    total=${session_active_total[$session]:-0}
    last=${session_active_last_ts[$session]:-0}
    running="${session_active_running[$session]:-false}"

    if [[ "$running" == "true" ]] && (( last > 0 )) && (( now > last )); then
        total=$(( total + now - last ))
    fi

    session_active_total[$session]=$total
    session_active_last_ts[$session]=$now
    session_active_running[$session]=$should_run
}

render_dashboard() {
    local ts total_nudges stuck_now active_now
    local session state state_col state_cell cooldown active_text

    ts=$(date '+%Y-%m-%d %H:%M:%S')
    total_nudges=0
    stuck_now=0
    active_now=0

    for session in "${!session_seen[@]}"; do
        (( total_nudges += ${nudge_success_count[$session]:-0} ))
        [[ "${session_stuck[$session]:-false}" == "true" ]] && (( stuck_now++ ))
        [[ "${session_mode[$session]:-MISSING}" != "MISSING" ]] && (( active_now++ ))
    done

    if [[ -t 1 ]]; then
        printf '\033[H\033[2J'
    fi

    printf '%bCodex Nudger v12 (live dashboard)%b  %s\n' "$C_BOLD" "$C_RESET" "$ts"
    printf '%bCHECK_INTERVAL=%ss  NUDGE_COOLDOWN=%ss  LINES_TO_CHECK=%s%b\n' \
        "$C_DIM" "$CHECK_INTERVAL" "$NUDGE_COOLDOWN" "$LINES_TO_CHECK" "$C_RESET"
    printf '%bActive=%d  Seen=%d  CurrentlyStuck=%d  TotalNudges=%d  (Ctrl+C to stop)%b\n\n' \
        "$C_DIM" "$active_now" "${#session_seen[@]}" "$stuck_now" "$total_nudges" "$C_RESET"

    printf '%b%-18s | %-8s | %11s | %11s | %8s | %10s%b\n' \
        "$C_DIM" "session" "state" "stuck_seen" "nudges" "cooldown" "time_active" "$C_RESET"
    printf '%b%s%b\n' "$C_DIM" \
        "-------------------+----------+-------------+-------------+----------+------------" \
        "$C_RESET"

    if [[ ${#session_seen[@]} -eq 0 ]]; then
        printf '%s\n' "no codex* sessions observed yet"
        return
    fi

    while IFS= read -r session; do
        [[ -z "$session" ]] && continue
        state="${session_mode[$session]:-MISSING}"
        state_col=$(state_color "$state")
        state_cell=$(printf '%-8s' "$state")
        cooldown="${session_cooldown[$session]:--}"
        active_text=$(format_hhmmss "${session_active_total[$session]:-0}")

        printf '%-18s | %b%s%b | %11d | %11d | %8s | %10s\n' \
            "$session" \
            "$state_col" "$state_cell" "$C_RESET" \
            "${stuck_detect_count[$session]:-0}" \
            "${nudge_success_count[$session]:-0}" \
            "$cooldown" \
            "$active_text"
    done < <(printf '%s\n' "${!session_seen[@]}" | sort)
}

scan_sessions() {
    local session lines found_pattern prompt_line last_time elapsed remaining scan_now

    for session in "${!session_seen[@]}"; do
        session_mode[$session]="MISSING"
        session_cooldown[$session]="-"
        session_event[$session]="session not found this scan"
    done

    mapfile -t sessions < <(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep '^codex' || true)

    for session in "${sessions[@]}"; do
        session_seen[$session]="true"
        session_mode[$session]="IDLE"
        session_cooldown[$session]="-"

        lines=$(tmux capture-pane -pt "$session" 2>/dev/null | tail -n "$LINES_TO_CHECK")
        if [[ -z "$lines" ]]; then
            session_mode[$session]="ERROR"
            session_event[$session]="pane empty or unreachable"
            continue
        fi

        if echo "$lines" | grep -qF "esc to interrupt"; then
            session_stuck[$session]="false"
            session_mode[$session]="BUSY"
            session_event[$session]="busy (esc to interrupt), stuck cleared"
            continue
        fi

        found_pattern=""
        for pattern in "${STUCK_PATTERNS[@]}"; do
            if echo "$lines" | grep -qF "$pattern"; then
                found_pattern="$pattern"
                if [[ "${session_stuck[$session]:-false}" != "true" ]]; then
                    stuck_detect_count[$session]=$(( ${stuck_detect_count[$session]:-0} + 1 ))
                fi
                session_stuck[$session]="true"
                break
            fi
        done

        if [[ "${session_stuck[$session]:-false}" != "true" ]]; then
            session_mode[$session]="IDLE"
            session_event[$session]="healthy; no stuck indicators"
            continue
        fi

        if [[ -n "$found_pattern" ]]; then
            session_event[$session]="stuck indicator: $found_pattern"
        fi

        prompt_line=$(echo "$lines" | grep -E "^[>›]" | tail -n 1)
        if [[ -z "$prompt_line" ]]; then
            session_mode[$session]="STUCK"
            session_event[$session]="stuck; waiting for prompt"
            continue
        fi

        scan_now=$(date +%s)
        last_time=${last_nudged_time[$session]:-0}
        elapsed=$(( scan_now - last_time ))

        if (( elapsed < NUDGE_COOLDOWN )); then
            remaining=$(( NUDGE_COOLDOWN - elapsed ))
            session_mode[$session]="COOLDOWN"
            session_cooldown[$session]="${remaining}s"
            session_event[$session]="prompt ready; cooldown active"
            continue
        fi

        if tmux send-keys -t "$session" "continue" && sleep 0.1 && tmux send-keys -t "$session" "" Enter; then
            last_nudged_time[$session]=$scan_now
            nudge_success_count[$session]=$(( ${nudge_success_count[$session]:-0} + 1 ))
            session_mode[$session]="NUDGED"
            session_cooldown[$session]="0s"
            session_event[$session]="nudge sent successfully"
        else
            session_mode[$session]="ERROR"
            session_event[$session]="nudge failed (tmux send-keys)"
        fi
    done
}

next_scan=0
while true; do
    now=$(date +%s)

    if (( now >= next_scan )); then
        scan_sessions
        next_scan=$(( now + CHECK_INTERVAL ))
    fi

    for session in "${!session_seen[@]}"; do
        if is_active_mode "${session_mode[$session]:-MISSING}"; then
            update_active_clock "$session" "true" "$now"
        else
            update_active_clock "$session" "false" "$now"
        fi
    done

    render_dashboard
    sleep 1
done