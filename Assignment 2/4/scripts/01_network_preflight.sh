#!/usr/bin/env bash
set -euo pipefail

# Lab 4 - Network Tracing Environment Check
# Read-only inspection: no network scan is performed.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

mkdir -p logs/baseline logs/perf notes screenshots payloads

TRACEFS="/sys/kernel/tracing"

echo "=================================="
echo "Lab 4 - Network Tracing Preflight"
echo "=================================="

echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo

echo "[1] Checking required tools..."

for tool in hping3 perf ip; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "[OK] $tool: $(command -v "$tool")"
    else
        echo "[MISSING] $tool"
    fi
done

echo
echo "[2] Perf version..."
perf --version

echo
echo "[3] Checking network route to 8.8.8.8..."

# This command checks the route only.
# It does not send packets to the destination.
ip route get 8.8.8.8 || true

echo
echo "[4] Checking network tracepoint groups..."

EVENT_GROUPS=(net skb tcp udp sock)

for group in "${EVENT_GROUPS[@]}"; do
    if [[ -d "$TRACEFS/events/$group" ]]; then
        count=$(find "$TRACEFS/events/$group" \
            -mindepth 1 -maxdepth 1 -type d | wc -l)

        echo "[AVAILABLE] $group ($count event directories)"
    else
        echo "[MISSING] $group"
    fi
done

echo
echo "[5] Discovering relevant perf tracepoints..."

perf list tracepoint \
    > notes/01_perf_tracepoints.txt

grep -E \
    'net:|skb:|tcp:|udp:|sock:' \
    notes/01_perf_tracepoints.txt \
    | tee notes/01_network_tracepoints.txt \
    || true

echo
echo "[6] Checking selected candidate events..."

CANDIDATES=(
    "net/net_dev_queue"
    "net/net_dev_xmit"
    "net/netif_receive_skb"
    "skb/kfree_skb"
    "tcp/tcp_send_reset"
    "udp/udp_fail_queue_rcv_skb"
)

for event in "${CANDIDATES[@]}"; do
    if [[ -f "$TRACEFS/events/$event/id" ]]; then
        echo "[OK] $event"
    else
        echo "[NOT AVAILABLE] $event"
    fi
done

echo
echo "=================================="
echo "Preflight completed."
echo "No scan packets were sent."
echo "=================================="
