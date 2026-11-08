#!/usr/bin/env bash
set -euo pipefail

# Lab 3 - Read-only inspection of the recorded LTTng trace

cd "$(dirname "${BASH_SOURCE[0]}")/.."

EVENTS="logs/lttng/04_babeltrace_events.txt"
ORIGINAL="logs/lttng/04_futex_trace"
GUI="logs/lttng/04_futex_trace_gui"
REPORT="notes/05_lttng_trace_inspection.txt"

[[ -s "$EVENTS" ]] || {
    echo "ERROR: Babeltrace output is missing or empty."
    exit 1
}

[[ -d "$GUI/kernel" ]] || {
    echo "ERROR: Trace Compass copy is missing."
    exit 1
}

{
    echo "=== Lab 3 - LTTng Trace Inspection ==="
    echo

    echo "[1] Trace sizes"
    du -sh "$GUI"
    sudo du -sh "$ORIGINAL"

    echo
    echo "[2] Event counts"

    events=(
        syscall_entry_futex
        syscall_exit_futex
        sched_switch
        sched_wakeup
        sched_waking
        sched_process_fork
        sched_process_exit
    )

    for event in "${events[@]}"; do
        count=$(grep -cF " $event:" "$EVENTS" || true)
        printf "%-28s %s\n" "$event" "$count"
    done

    echo
    echo "[3] Scheduling events mentioning deadlock_m"

    grep -m 12 'deadlock_m' "$EVENTS" \
        || echo "No process-name matches."

    echo
    echo "[4] Last scheduling events mentioning deadlock_m"

    grep 'deadlock_m' "$EVENTS" \
        | tail -n 10 || true

    echo
    echo "[5] Sample futex events"

    grep -m 6 'syscall_entry_futex:' "$EVENTS" \
        || true

    echo
    echo "[6] Total exported event lines"
    wc -l "$EVENTS"

    echo
    echo "Inspection completed."

} | tee "$REPORT"
