#!/usr/bin/env bash
set -euo pipefail

# Lab 2 - Correct mmap event counts in saved ftrace outputs

cd "$(dirname "${BASH_SOURCE[0]}")/.."

PID_TRACE="logs/ftrace/10_mmap_syscalls_only.trace"
ALL_TRACE="logs/ftrace/11_mmap_no_pid_filter.trace"
GRAPH_TRACE="logs/ftrace/08_do_mmap_ftrace.trace"
REPORT="notes/ftrace_mmap_corrected_analysis.txt"

mkdir -p notes

for file in "$PID_TRACE" "$ALL_TRACE" "$GRAPH_TRACE"; do
    if [[ ! -s "$file" ]]; then
        echo "ERROR: Missing or empty trace: $file"
        exit 1
    fi
done

sudo -v

{
    echo "=== Corrected ftrace mmap Analysis ==="
    echo "Kernel: $(uname -r)"
    echo

    for file in "$PID_TRACE" "$ALL_TRACE"; do
        echo "----------------------------------------"
        echo "File: $file"

        enters=$(grep -Ec ': sys_mmap\(' "$file" || true)
        exits=$(grep -Ec ': sys_mmap ->' "$file" || true)

        echo "sys_mmap entries: $enters"
        echo "sys_mmap exits:   $exits"
        echo
    done

    echo "=== Program's Last mmap Pair ==="

    grep -E 'sys_mmap\(|sys_mmap ->' "$PID_TRACE" \
        | tail -n 2

    echo
    echo "=== mmap Events in Combined Function Graph ==="

    grep -n -m 12 -E \
        'sys_mmap|sys_enter_mmap|sys_exit_mmap' \
        "$GRAPH_TRACE" \
        || echo "No syscall event lines found in this trace."

    echo
    echo "=== Kernel Tracepoint Format ==="

    sudo sed -n '1,12p' \
        /sys/kernel/tracing/events/syscalls/sys_enter_mmap/format

    echo
    echo "Analysis completed."

} | tee "$REPORT"
