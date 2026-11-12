#!/usr/bin/env bash
set -euo pipefail

# Lab 5 - Packet and System Call Tracing Preflight
# Read-only check of tools, namespaces and tracing capabilities.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

mkdir -p logs/pcap notes

REPORT="notes/06_packet_trace_preflight.txt"
SYSCALLS="notes/06_lttng_available_syscalls.txt"
KERNEL_EVENTS="notes/06_lttng_available_kernel_events.txt"

NS_TX="lab5_mtu_tx"
NS_RX="lab5_mtu_rx"

DEV_TX="l5veth_tx"
DEV_RX="l5veth_rx"

sudo -v

{
    echo "=================================="
    echo "Lab 5 - Packet Tracing Preflight"
    echo "=================================="

    echo "Date: $(date -Is)"
    echo "Kernel: $(uname -r)"
    echo

    echo "[1] Checking tracing and packet tools..."

    tools=(
        ping
        ip
        lttng
        babeltrace
        tcpdump
        wireshark
        tshark
    )

    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "[OK] $tool: $(command -v "$tool")"
        else
            echo "[MISSING] $tool"
        fi
    done

    echo
    echo "[2] Checking tcpdump version..."

    if command -v tcpdump >/dev/null 2>&1; then
        tcpdump --version | head -n 3
    else
        echo "tcpdump is not installed."
    fi

    echo
    echo "[3] Checking experimental namespaces..."

    sudo ip netns list

    echo
    echo "[4] Checking virtual interfaces and MTU..."

    echo "--- Transmitter ---"
    sudo ip -n "$NS_TX" link show "$DEV_TX"

    echo
    echo "--- Receiver ---"
    sudo ip -n "$NS_RX" link show "$DEV_RX"

    echo
    echo "[5] Checking IPv4 route..."

    sudo ip -n "$NS_TX" route get 10.205.0.2

    echo
    echo "[6] Listing LTTng-supported syscalls..."

    sudo lttng list --kernel --syscall > "$SYSCALLS"

    echo "Saved syscall list: $SYSCALLS"
    echo

    grep -Ei \
        'sendto|sendmsg|sendmmsg|recvfrom|recvmsg|recvmmsg|socket|setsockopt' \
        "$SYSCALLS" \
        | head -n 35 || true

    echo
    echo "[7] Checking useful LTTng network events..."

    sudo lttng list --kernel > "$KERNEL_EVENTS"

    for event in \
        net_dev_queue \
        net_dev_xmit \
        net_dev_start_xmit \
        netif_receive_skb \
        sched_switch \
        sched_wakeup \
        sched_process_fork
    do
        if grep -Eq \
            "^[[:space:]]*${event}[[:space:]]*\\(" \
            "$KERNEL_EVENTS"; then

            echo "[AVAILABLE] $event"
        else
            echo "[NOT LISTED] $event"
        fi
    done

    echo
    echo "=================================="
    echo "Preflight completed."
    echo "No packets were sent."
    echo "No network settings were modified."
    echo "=================================="

} | tee "$REPORT"
