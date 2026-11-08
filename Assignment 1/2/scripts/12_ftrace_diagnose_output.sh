#!/usr/bin/env bash
set -euo pipefail

# Lab 2 - Read-only diagnosis of ftrace syscall output

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="notes/ftrace_syscall_diagnostic.txt"
TRACEFS="/sys/kernel/tracing"

{
    echo "=== Lab 2: ftrace Output Diagnosis ==="
    echo "Date: $(date -Is)"
    echo "Kernel: $(uname -r)"
    echo

    for file in \
        logs/ftrace/08_do_mmap_ftrace.trace \
        logs/ftrace/10_mmap_syscalls_only.trace \
        logs/ftrace/11_mmap_no_pid_filter.trace
    do
        echo "========================================"
        echo "File: $file"
        echo "========================================"

        if [[ ! -f "$file" ]]; then
            echo "FILE MISSING"
            continue
        fi

        echo "--- File size and line count ---"
        wc -lc "$file"

        echo
        echo "--- First 30 lines ---"
        sed -n '1,30p' "$file"

        echo
        echo "--- mmap-related matches ---"
        grep -niEm 15 \
            'mmap|syscall|overrun|lost events' "$file" \
            || echo "No matching lines found."

        echo
    done

    echo "========================================"
    echo "Kernel tracepoint format"
    echo "========================================"

    sed -n '1,35p' \
        "$TRACEFS/events/syscalls/sys_enter_mmap/format"

    echo
    echo "========================================"
    echo "Current main ftrace settings"
    echo "========================================"

    echo "current_tracer: $(cat "$TRACEFS/current_tracer")"
    echo "tracing_on: $(cat "$TRACEFS/tracing_on")"

    echo
    echo "Diagnosis completed."

} | tee "$OUT"
