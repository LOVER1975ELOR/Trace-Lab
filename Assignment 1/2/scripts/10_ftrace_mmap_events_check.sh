#!/usr/bin/env bash
set -euo pipefail

# Lab 2 - Independent mmap syscall event verification

cd "$(dirname "${BASH_SOURCE[0]}")/.."

BASE="/sys/kernel/tracing"
INSTANCE="$BASE/instances/lab2_mmap_${UID}_$$"
OUT="logs/ftrace/10_mmap_syscalls_only.trace"

mkdir -p logs/ftrace

[[ -x src/program ]] || {
    echo "ERROR: Program not found."
    exit 1
}

[[ ! -e "$OUT" ]] || {
    echo "ERROR: Output already exists."
    exit 1
}

sudo -v

created=0
child_pid=""

write_value() {
    printf '%s\n' "$2" | sudo tee "$1" >/dev/null
}

cleanup() {
    rc=$?
    trap - EXIT INT TERM

    if [[ -n "$child_pid" ]]; then
        kill -CONT "$child_pid" 2>/dev/null || true
        kill "$child_pid" 2>/dev/null || true
        wait "$child_pid" 2>/dev/null || true
    fi

    if (( created )); then
        write_value "$INSTANCE/tracing_on" 0 || true
        write_value "$INSTANCE/events/syscalls/sys_enter_mmap/enable" 0 || true
        write_value "$INSTANCE/events/syscalls/sys_exit_mmap/enable" 0 || true
        sudo rmdir "$INSTANCE" || \
            echo "WARNING: Could not remove tracing instance."
    fi

    exit "$rc"
}

sudo mkdir "$INSTANCE"
created=1

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "=== mmap Syscall Event Verification ==="

write_value "$INSTANCE/tracing_on" 0
write_value "$INSTANCE/current_tracer" nop

write_value "$INSTANCE/events/syscalls/sys_enter_mmap/enable" 1
write_value "$INSTANCE/events/syscalls/sys_exit_mmap/enable" 1

echo "Event enable states:"
sudo cat "$INSTANCE/events/syscalls/sys_enter_mmap/enable"
sudo cat "$INSTANCE/events/syscalls/sys_exit_mmap/enable"

# Pause the process before executing the supplied program.
bash -c 'kill -STOP "$BASHPID"; exec "$1"' \
    _ "$PWD/src/program" \
    > logs/ftrace/10_program.stdout \
    2> logs/ftrace/10_program.stderr &

child_pid=$!

ready=0

for ((i=0; i<100; i++)); do
    state=$(ps -o stat= -p "$child_pid" 2>/dev/null || true)

    if [[ "$state" == *T* ]]; then
        ready=1
        break
    fi

    sleep 0.02
done

if (( ! ready )); then
    echo "ERROR: Process did not pause."
    exit 1
fi

write_value "$INSTANCE/set_event_pid" "$child_pid"
write_value "$INSTANCE/trace" ""

echo "Tracing PID: $child_pid"

write_value "$INSTANCE/tracing_on" 1
kill -CONT "$child_pid"

if wait "$child_pid"; then
    program_rc=0
else
    program_rc=$?
fi

child_pid=""

write_value "$INSTANCE/tracing_on" 0
sudo cat "$INSTANCE/trace" > "$OUT"

echo "Program exit code: $program_rc"
echo "Trace saved: $OUT"

echo
echo "sys_enter_mmap count:"
grep -c 'sys_enter_mmap:' "$OUT" || true

echo "sys_exit_mmap count:"
grep -c 'sys_exit_mmap:' "$OUT" || true

echo
echo "First mmap events:"
grep -E 'sys_enter_mmap:|sys_exit_mmap:' "$OUT" \
    | head -n 12 || true

echo
echo "Program output:"
cat logs/ftrace/10_program.stdout

(( program_rc == 0 )) || exit "$program_rc"
