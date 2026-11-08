#!/usr/bin/env bash
set -euo pipefail

# Lab 3 - Record a 30-second trace for visualization only.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="$PWD/logs/lttng"
SESSION="lab3_30s_$$"

TRACE="$OUT/07_futex_30s_trace"
GUI_TRACE="$OUT/07_futex_30s_trace_gui"

mkdir -p "$OUT"

if [[ -e "$TRACE" || -e "$GUI_TRACE" ]]; then
    echo "ERROR: A 30-second trace already exists."
    exit 1
fi

sudo -v

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

echo "=================================="
echo "Lab 3 - 30-Second LTTng Trace"
echo "=================================="

echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo "Duration: 30 seconds"
echo

echo "[1] Creating LTTng session..."

sudo lttng create "$SESSION" --output="$TRACE"
created=1

echo
echo "[2] Enabling futex syscalls..."

sudo lttng enable-event \
    --kernel --syscall futex \
    --session="$SESSION"

echo
echo "[3] Enabling scheduling events..."

sudo lttng enable-event \
    --kernel \
    sched_switch,sched_wakeup,sched_waking,sched_process_fork,sched_process_exit \
    --session="$SESSION"

echo
echo "[4] Starting trace..."

sudo lttng start "$SESSION"
started=1

echo
echo "[5] Running deadlock_m for 30 seconds..."

ulimit -c 0

if timeout --signal=TERM --kill-after=2s 30s \
    stdbuf -o0 -e0 ./src/deadlock_m \
    > "$OUT/07_program.stdout" \
    2> "$OUT/07_program.stderr"
then
    program_status=0
else
    program_status=$?
fi

echo
echo "Program exit status: $program_status"

echo
echo "[6] Stopping trace..."

sudo lttng stop "$SESSION"
started=0

sudo lttng destroy "$SESSION"
created=0

echo
echo "[7] Preparing Trace Compass copy..."

sudo cp -a "$TRACE" "$GUI_TRACE"
sudo chown -R "$(id -u):$(id -g)" "$GUI_TRACE"

echo
echo "========== LAST PROGRAM OUTPUT =========="

tail -n 12 "$OUT/07_program.stdout"

echo
echo "========== TRACE SIZE =========="

du -sh "$GUI_TRACE"

echo
echo "========== RESULT =========="

echo "Trace recording completed."
echo "Trace Compass path:"
echo "$GUI_TRACE/kernel"

printf '%s\n' "$program_status" \
    > "$OUT/07_program_exit_status.txt"
