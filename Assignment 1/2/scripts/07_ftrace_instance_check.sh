#!/usr/bin/env bash
set -euo pipefail

# Lab 2 - Check function_graph support in a trace instance

cd "$(dirname "$0")/.."

TRACEFS="/sys/kernel/tracing"
INSTANCE="$TRACEFS/instances/lab2_check_${UID}_$$"
created=0

cleanup() {
    if [[ "$created" -eq 1 ]]; then
        echo
        echo "Removing temporary instance..."
        sudo rmdir "$INSTANCE"
    fi
}

trap cleanup EXIT

sudo -v

echo "=== ftrace Instance Capability Check ==="
echo "Kernel: $(uname -r)"
echo "Main tracer: $(sudo cat "$TRACEFS/current_tracer")"
echo

sudo mkdir "$INSTANCE"
created=1

features=(
    current_tracer
    available_tracers
    set_graph_function
    set_ftrace_pid
    set_event_pid
    tracing_on
    trace
    events/syscalls/sys_enter_mmap/enable
)

for feature in "${features[@]}"; do
    if sudo test -e "$INSTANCE/$feature"; then
        echo "[AVAILABLE] $feature"
    else
        echo "[MISSING]   $feature"
    fi
done

echo
echo "Capability check completed."
