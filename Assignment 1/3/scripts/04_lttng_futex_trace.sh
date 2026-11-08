#!/usr/bin/env bash
set -euo pipefail

# Lab 3 - Record futex syscalls and scheduling events with LTTng

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="$PWD/logs/lttng"
SESSION="lab3_futex_$$"
TRACE="$OUT/04_futex_trace"
GUI_TRACE="$OUT/04_futex_trace_gui"

mkdir -p "$OUT" notes

echo "=================================="
echo "Lab 3 - LTTng Futex Recording"
echo "=================================="
echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo "Session: $SESSION"
echo

if [[ -e "$TRACE" || -e "$GUI_TRACE" ]]; then
    echo "ERROR: Trace output already exists."
    echo "Preserve the previous experiment before rerunning."
    exit 1
fi

sudo -v

echo "[1] Checking required kernel events..."

EVENTS=(
    sched_switch
    sched_wakeup
    sched_waking
    sched_process_fork
    sched_process_exit
)

for event in "${EVENTS[@]}"; do
    if sudo test -f \
        "/sys/kernel/tracing/events/sched/$event/id"; then
        echo "[OK] $event"
    else
        echo "[MISSING] $event"
        exit 1
    fi
done

if sudo test -f \
    /sys/kernel/tracing/events/syscalls/sys_enter_futex/id; then
    echo "[OK] futex syscall"
else
    echo "[MISSING] futex syscall"
    exit 1
fi

created=0
started=0

cleanup() {
    status=$?
    trap - EXIT INT TERM

    if (( created )); then
        if (( started )); then
            sudo lttng stop "$SESSION" || true
        fi
        sudo lttng destroy "$SESSION" || true
    fi

    exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo
echo "[2] Creating LTTng session..."

sudo lttng create "$SESSION" --output="$TRACE"
created=1

echo
echo "[3] Enabling futex syscalls..."

sudo lttng enable-event \
    --kernel --syscall futex \
    --session="$SESSION"

echo
echo "[4] Enabling scheduling events..."

sudo lttng enable-event \
    --kernel \
    sched_switch,sched_wakeup,sched_waking,sched_process_fork,sched_process_exit \
    --session="$SESSION"

sudo lttng list "$SESSION" \
    > notes/04_lttng_session_configuration.txt

echo
echo "[5] Starting tracing..."

sudo lttng start "$SESSION"
started=1

echo
echo "[6] Running deadlock_m (maximum 8 seconds)..."

ulimit -c 0

if timeout --signal=TERM --kill-after=2s 8s \
    stdbuf -o0 -e0 ./src/deadlock_m \
    > "$OUT/04_program.stdout" \
    2> "$OUT/04_program.stderr"
then
    program_status=0
else
    program_status=$?
fi

echo "Program command exit status: $program_status"

echo
echo "[7] Stopping tracing..."

sudo lttng stop "$SESSION"
started=0

sudo lttng destroy "$SESSION"
created=0

echo
echo "[8] Preparing a readable copy for Trace Compass..."

sudo cp -a "$TRACE" "$GUI_TRACE"
sudo chown -R "$(id -u):$(id -g)" "$GUI_TRACE"

echo
echo "[9] Exporting events with Babeltrace..."

babeltrace "$GUI_TRACE/kernel" \
    > "$OUT/04_babeltrace_events.txt"

echo
echo "========== FUTEX EVENT COUNTS =========="

for event in syscall_entry_futex syscall_exit_futex; do
    count=$(grep -c "$event" \
        "$OUT/04_babeltrace_events.txt" || true)

    printf "%-28s %s\n" "$event" "$count"
done

echo
echo "========== FUTEX EVENT PREVIEW =========="

grep -m 12 'futex' \
    "$OUT/04_babeltrace_events.txt" || true

echo
echo "========== FINAL PROGRAM OUTPUT =========="

tail -n 16 "$OUT/04_program.stdout"

echo
echo "========== TRACE FILES =========="

du -sh "$TRACE" "$GUI_TRACE"
wc -l "$OUT/04_babeltrace_events.txt"

printf '%s\n' "$program_status" \
    > "$OUT/04_program_exit_status.txt"

echo
echo "Recording completed."
echo "Trace Compass path: $GUI_TRACE/kernel"
