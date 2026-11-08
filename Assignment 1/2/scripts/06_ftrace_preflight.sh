#!/usr/bin/env bash
set -euo pipefail

# Lab 2 - Read-only ftrace preflight check

cd "$(dirname "$0")/.."

TRACEFS="/sys/kernel/tracing"
mkdir -p notes

sudo -v

{
    echo "=== Lab 2: ftrace Preflight ==="
    echo "Date: $(date -Is)"
    echo "Kernel: $(uname -r)"
    echo

    echo "--- TraceFS ---"
    findmnt "$TRACEFS"
    echo

    echo "--- Available Tracers ---"
    sudo cat "$TRACEFS/available_tracers"
    echo

    echo "--- Current Configuration ---"
    for name in \
        current_tracer \
        tracing_on \
        set_event \
        set_ftrace_pid \
        set_event_pid \
        set_graph_function \
        set_ftrace_filter
    do
        echo "[$name]"
        if [[ -f "$TRACEFS/$name" ]]; then
            sudo cat "$TRACEFS/$name"
        else
            echo "Not available"
        fi
        echo
    done

    echo "--- do_mmap Availability ---"
    sudo grep -w 'do_mmap' \
        "$TRACEFS/available_filter_functions" || true
    echo

    echo "--- Required Event Tracepoints ---"

    events=(
        "syscalls/sys_enter_mmap"
        "syscalls/sys_exit_mmap"
        "kmem/kmalloc"
        "kmem/kmem_cache_alloc"
        "kmem/mm_page_alloc"
        "kmem/rss_stat"
    )

    for event in "${events[@]}"; do
        if [[ -d "$TRACEFS/events/$event" ]]; then
            echo "[OK] $event"
        else
            echo "[MISSING] $event"
        fi
    done

    echo
    echo "Preflight completed (no settings changed)."

} | tee notes/ftrace_preflight.txt
