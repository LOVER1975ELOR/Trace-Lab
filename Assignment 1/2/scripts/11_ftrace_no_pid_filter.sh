#!/usr/bin/env bash
set -euo pipefail

# Lab 2 - Diagnose mmap tracepoints without PID filtering.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

BASE="/sys/kernel/tracing"
INSTANCE="$BASE/instances/lab2_nopid_${UID}_$$"

OUT="logs/ftrace/11_mmap_no_pid_filter.trace"
STDOUT="logs/ftrace/11_program.stdout"
STDERR="logs/ftrace/11_program.stderr"

mkdir -p logs/ftrace

if [[ -e "$OUT" ]]; then
    echo "ERROR: Output already exists."
    exit 1
fi

sudo -v

created=0

write_value() {
    printf '%s\n' "$2" | sudo tee "$1" >/dev/null
}

cleanup() {
    rc=$?
    trap - EXIT INT TERM

    if (( created )); then
        write_value "$INSTANCE/tracing_on" 0 || true

        write_value \
            "$INSTANCE/events/syscalls/sys_enter_mmap/enable" 0 || true

        write_value \
            "$INSTANCE/events/syscalls/sys_exit_mmap/enable" 0 || true

        sudo rmdir "$INSTANCE" || true
        echo "Temporary instance removed."
    fi

    exit "$rc"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "=== Lab 2: mmap Without PID Filter ==="

sudo mkdir "$INSTANCE"
created=1

write_value "$INSTANCE/tracing_on" 0
write_value "$INSTANCE/current_tracer" nop

write_value \
    "$INSTANCE/events/syscalls/sys_enter_mmap/enable" 1

write_value \
    "$INSTANCE/events/syscalls/sys_exit_mmap/enable" 1

echo "Enabled events:"
sudo cat "$INSTANCE/set_event"

echo
echo "PID filter (should be empty):"
sudo cat "$INSTANCE/set_event_pid"

# Clear the new instance's buffer.
write_value "$INSTANCE/trace" ""

echo
echo "Starting tracing..."

write_value "$INSTANCE/tracing_on" 1

if timeout -k 2s 5s ./src/program \
    > "$STDOUT" 2> "$STDERR"; then
    program_rc=0
else
    program_rc=$?
fi

write_value "$INSTANCE/tracing_on" 0

sudo cat "$INSTANCE/trace" > "$OUT"

echo
echo "Program exit code: $program_rc"

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
cat "$STDOUT"

echo
echo "Trace saved: $OUT"

(( program_rc == 0 )) || exit "$program_rc"
