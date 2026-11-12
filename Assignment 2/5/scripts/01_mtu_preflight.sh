#!/usr/bin/env bash
set -euo pipefail

# Lab 5 - MTU and Network Fragmentation Preflight
# Read-only inspection. No network settings are changed.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

mkdir -p logs/baseline logs/lttng notes screenshots

TRACEFS="/sys/kernel/tracing"
REPORT="notes/01_mtu_environment.txt"

sudo -v

{
    echo "=================================="
    echo "Lab 5 - MTU Preflight"
    echo "=================================="

    echo "Date: $(date -Is)"
    echo "Kernel: $(uname -r)"
    echo

    echo "[1] Checking required tools..."

    for tool in ping ip lttng babeltrace; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "[OK] $tool: $(command -v "$tool")"
        else
            echo "[MISSING] $tool"
        fi
    done

    echo
    echo "[2] Checking network interfaces and MTU..."

    ip -br link show

    echo
    echo "[3] Checking current network route..."

    ip route get 8.8.8.8 || true

    echo
    echo "[4] Checking existing network namespaces..."

    sudo ip netns list

    echo
    echo "[5] Checking LTTng kernel tracing..."

    if sudo lttng list -k >/dev/null; then
        echo "[OK] LTTng kernel tracing is available."
    else
        echo "[ERROR] LTTng kernel tracing is unavailable."
        exit 1
    fi

    echo
    echo "[6] Checking network tracepoints..."

    EVENTS=(
        net/net_dev_queue
        net/net_dev_start_xmit
        net/net_dev_xmit
        net/netif_receive_skb
        skb/kfree_skb
    )

    for event in "${EVENTS[@]}"; do
        if sudo test -f "$TRACEFS/events/$event/format"; then
            echo "[OK] $event"
        else
            echo "[MISSING] $event"
        fi
    done

    echo
    echo "[7] Checking packet length fields..."

    for event in \
        net/net_dev_queue \
        net/net_dev_start_xmit \
        net/net_dev_xmit
    do
        echo "--- $event ---"

        if sudo test -f "$TRACEFS/events/$event/format"; then
            sudo cat "$TRACEFS/events/$event/format" \
                | grep -E 'field:.*(len|name|skbaddr|gso)' \
                || true
        fi

        echo
    done

    echo "=================================="
    echo "Preflight completed."
    echo "No network settings were changed."
    echo "=================================="

} | tee "$REPORT"
