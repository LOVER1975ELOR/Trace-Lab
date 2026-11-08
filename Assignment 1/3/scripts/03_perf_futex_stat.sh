#!/usr/bin/env bash
set -euo pipefail

# Lab 3 - Test the futex and scheduling hypothesis.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="logs/perf"
TRACEFS="/sys/kernel/tracing"

mkdir -p "$OUT" notes

STAT="$OUT/03_futex_sched_stat.txt"
STDOUT="$OUT/03_program.stdout"
STDERR="$OUT/03_program.stderr"

echo "=================================="
echo "Lab 3 - Futex and Scheduling"
echo "=================================="

echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo "Perf: $(perf --version)"
echo

# Preserve previous results.
if [[ -e "$STAT" ]]; then
    echo "ERROR: $STAT already exists."
    exit 1
fi

echo "[1] Checking required tracepoints..."

EVENTS=(
    "syscalls:sys_enter_futex"
    "syscalls:sys_exit_futex"
    "sched:sched_switch"
    "sched:sched_wakeup"
    "sched:sched_waking"
)

for event in "${EVENTS[@]}"; do

    path="${event/:/\/}"

    if [[ -f "$TRACEFS/events/$path/id" ]]; then
        echo "[OK] $event"
    else
        echo "[MISSING] $event"
        exit 1
    fi
done

EVENT_STRING=$(IFS=,; echo "${EVENTS[*]}")

echo
echo "[2] Inspecting imported thread functions..."

nm -D src/deadlock_m \
    | grep -E 'pthread_|futex' \
    || echo "No matching dynamic symbols found."

echo
echo "[3] Recording Perf counters (6-second run)..."

sudo -v

# The supplied program runs as a normal user.
# perf stat measures the command and its descendants.

if sudo perf stat \
    -e "$EVENT_STRING" \
    -o "$STAT" \
    -- setpriv \
       --reuid="$(id -u)" \
       --regid="$(id -g)" \
       --init-groups \
       -- timeout --signal=TERM --kill-after=2s 6s \
          stdbuf -o0 -e0 ./src/deadlock_m \
    > "$STDOUT" \
    2> "$STDERR"
then
    status=0
else
    status=$?
fi

echo "Program command exit status: $status"

if [[ "$status" -eq 124 ]]; then
    echo "The program reached the 6-second timeout."
elif [[ "$status" -eq 0 ]]; then
    echo "The program finished normally."
else
    echo "The command ended with another status."
fi

echo
echo "[4] Perf statistics:"
cat "$STAT"

echo
echo "[5] Last 14 lines of program output:"
tail -n 14 "$STDOUT"

echo
echo "[6] Standard error:"
cat "$STDERR"

printf '%s\n' "$status" > "$OUT/03_exit_status.txt"

echo
echo "Experiment completed."
