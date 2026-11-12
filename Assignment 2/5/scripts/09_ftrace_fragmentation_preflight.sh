#!/usr/bin/env bash
set -euo pipefail

# Lab 5 - IPv4 Fragmentation Function Graph Preflight
# Read-only checks. No tracer settings are modified.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

TRACEFS="/sys/kernel/tracing"
REPORT="notes/09_ftrace_fragmentation_preflight.txt"

mkdir -p notes logs/ftrace

sudo -v

{
    echo "======================================"
    echo "Lab 5 - ftrace Fragmentation Preflight"
    echo "======================================"

    echo "Date: $(date -Is)"
    echo "Kernel: $(uname -r)"
    echo

    echo "[1] Checking TraceFS..."

    findmnt "$TRACEFS"
    echo

    echo "[2] Checking available tracers..."

    sudo cat "$TRACEFS/available_tracers"
    echo

    echo "[3] Checking fragmentation functions..."

    sudo awk '
    $1 ~ /^(ip_do_fragment|ip_fragment|ip_frag_next|ip_frag_init|ip_frag_ipcb|ip_fraglist_init|ip_fraglist_prepare|ip_finish_output|__ip_finish_output|ip_finish_output2|ip_local_out|__ip_local_out|ip_output|ip_append_data|__ip_append_data|ip_push_pending_frames|raw_sendmsg)(\.|$)/ {
        print
        found++
    }
    END {
        print "Matching function entries:", found+0
    }
    ' "$TRACEFS/available_filter_functions"

    echo
    echo "[4] Checking current ftrace configuration..."

    settings=(
        current_tracer
        tracing_on
        set_graph_function
        set_ftrace_filter
        set_ftrace_pid
        set_event_pid
        set_event
        buffer_size_kb
    )

    for setting in "${settings[@]}"; do
        echo "--------------------------------------"
        echo "[$setting]"

        if sudo test -f "$TRACEFS/$setting"; then
            sudo cat "$TRACEFS/$setting"
        else
            echo "NOT AVAILABLE"
        fi
        echo
    done

    echo "[5] Checking experimental network..."

    echo "--- Transmitter ---"
    sudo ip -n lab5_mtu_tx link show l5veth_tx

    echo
    echo "--- Receiver ---"
    sudo ip -n lab5_mtu_rx link show l5veth_rx

    echo
    echo "======================================"
    echo "Preflight completed."
    echo "No tracing configuration was changed."
    echo "No network packets were sent."
    echo "======================================"

} | tee "$REPORT"
