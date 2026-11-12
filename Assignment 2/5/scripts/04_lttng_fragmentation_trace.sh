#!/usr/bin/env bash
set -euo pipefail

# Lab 5 - Trace normal and fragmented IPv4 Ping with LTTng.
# Existing network namespaces and MTU settings are not changed.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="$PWD/logs/lttng"
NS="lab5_mtu_tx"
TARGET="10.205.0.2"
DEVICE="l5veth_tx"

EVENTS=(
    net_dev_queue
    net_dev_start_xmit
    net_dev_xmit
    netif_receive_skb
)

mkdir -p "$OUT" notes

echo "=================================="
echo "Lab 5 - LTTng Fragmentation Trace"
echo "=================================="

echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo

sudo -v

echo "[1] Verifying the experimental network..."

sudo ip -n "$NS" link show "$DEVICE"

echo
echo "[2] Checking LTTng network events..."

sudo lttng list -k \
    > notes/04_lttng_available_events.txt

if ! grep -Eq \
    '^[[:space:]]*net_dev_queue[[:space:]]*\(' \
    notes/04_lttng_available_events.txt
then
    echo "ERROR: net_dev_queue is unavailable in LTTng."
    exit 1
fi

for event in "${EVENTS[@]}"; do
    if grep -Eq \
        "^[[:space:]]*${event}[[:space:]]*\\(" \
        notes/04_lttng_available_events.txt
    then
        echo "[AVAILABLE] $event"
    else
        echo "[MISSING] $event"
    fi
done

echo
echo "[3] Checking previous output files..."

for mode in small large; do
    for path in \
        "$OUT/04_${mode}_trace" \
        "$OUT/04_${mode}_trace_gui" \
        "$OUT/04_${mode}_events.txt" \
        "$OUT/04_${mode}_ping.stdout"
    do
        if [[ -e "$path" ]]; then
            echo "ERROR: Previous output exists: $path"
            exit 1
        fi
    done
done

SESSION=""
created=0
started=0

cleanup() {
    status=$?
    trap - EXIT INT TERM

    if (( created )); then
        if (( started )); then
            sudo lttng stop "$SESSION" || true
        fi
        sudo lttng destroy "$SESSION" || true
    fi

    exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

record_ping() {
    local mode="$1"
    local payload="$2"

    SESSION="lab5_mtu_${mode}_$$"

    local trace="$OUT/04_${mode}_trace"
    local gui="$OUT/04_${mode}_trace_gui"
    local text="$OUT/04_${mode}_events.txt"

    echo
    echo "=================================="
    echo "Recording: $mode"
    echo "Payload: $payload bytes"
    echo "IPv4 packet: $((payload + 28)) bytes"
    echo "=================================="

    sudo lttng create "$SESSION" --output="$trace"
    created=1

    for event in "${EVENTS[@]}"; do
        if grep -Eq \
            "^[[:space:]]*${event}[[:space:]]*\\(" \
            notes/04_lttng_available_events.txt
        then
            sudo lttng enable-event \
                --kernel "$event" \
                --session="$SESSION"
        fi
    done

    sudo lttng start "$SESSION"
    started=1

    echo "Running Ping..."

    if sudo timeout --kill-after=2s 8s \
        ip netns exec "$NS" \
        ping -4 -n -c 2 -W 2 \
             -M dont -s "$payload" "$TARGET" \
        > "$OUT/04_${mode}_ping.stdout" \
        2> "$OUT/04_${mode}_ping.stderr"
    then
        echo "Ping: SUCCESS"
    else
        status=$?
        echo "Ping: FAILED ($status)"
        cat "$OUT/04_${mode}_ping.stderr"
        return "$status"
    fi

    sudo lttng stop "$SESSION"
    started=0

    sudo lttng destroy "$SESSION"
    created=0

    echo "Preparing Trace Compass copy..."

    sudo cp -a "$trace" "$gui"
    sudo chown -R "$(id -u):$(id -g)" "$gui"

    echo "Exporting Babeltrace events..."

    babeltrace "$gui/kernel" > "$text"

    echo
    echo "--- Ping output ---"
    cat "$OUT/04_${mode}_ping.stdout"

    echo
    echo "--- Trace event counts ---"

    for event in "${EVENTS[@]}"; do
        count=$(grep -cF " $event:" "$text" || true)
        printf "%-25s %s\n" "$event" "$count"
    done

    echo
    echo "--- First network queue events ---"

    grep -m 8 'net_dev_queue:' "$text" || true

    echo
    echo "--- Trace files ---"
    du -sh "$gui"
    wc -l "$text"

    echo "Trace Compass path: $gui/kernel"
}

echo
echo "[4] Recording normal Ping..."

record_ping small 56

echo
echo "[5] Recording oversized Ping..."

record_ping large 2000

echo
echo "=================================="
echo "Both LTTng recordings completed."
echo "=================================="
