#!/usr/bin/env bash
set -euo pipefail

# Lab 5 - Check optional network tracepoints in LTTng.
# No packet transmission or trace recording.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SESSION="lab5_optional_${UID}_$$"
EVENTS=(
    net_dev_start_xmit
    netif_receive_skb
)

created=0

cleanup() {
    status=$?
    trap - EXIT INT TERM

    if (( created )); then
        echo
        echo "[Cleanup] Removing temporary LTTng session..."
        sudo lttng destroy "$SESSION" || true
    fi

    exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

sudo -v

echo "=================================="
echo "Lab 5 - Optional LTTng Event Check"
echo "=================================="

echo "Kernel: $(uname -r)"
echo "Session: $SESSION"
echo

echo "[1] Checking TraceFS availability..."

for event in "${EVENTS[@]}"; do
    if sudo test -f \
        "/sys/kernel/tracing/events/net/$event/id"; then
        echo "[TRACEFS OK] $event"
    else
        echo "[TRACEFS MISSING] $event"
    fi
done

echo
echo "[2] Creating temporary session..."

sudo lttng create "$SESSION" --no-output
created=1

echo
echo "[3] Testing event activation..."

for event in "${EVENTS[@]}"; do
    echo
    echo "Testing: $event"

    if sudo lttng enable-event \
        --kernel \
        --tracepoint \
        "$event" \
        --session="$SESSION"
    then
        echo "[ENABLE SUCCEEDED] $event"
    else
        echo "[ENABLE FAILED] $event"
    fi
done

echo
echo "[4] Inspecting session configuration..."

sudo lttng list "$SESSION"

echo
echo "Capability check completed."
echo "Actual event recording has not been tested."
