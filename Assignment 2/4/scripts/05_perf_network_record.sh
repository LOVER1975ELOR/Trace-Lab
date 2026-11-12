#!/usr/bin/env bash
set -euo pipefail

# Lab 4 - Record SYN and UDP network events with perf.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="logs/perf"
TARGET="8.8.8.8"
PORT=53
COUNT=3
PAYLOAD="$PWD/payloads/dns_query.bin"

EVENTS=(
    net:net_dev_queue
    net:net_dev_xmit
    net:netif_receive_skb
    skb:kfree_skb
    tcp:tcp_send_reset
)

EVENT_LIST=$(IFS=,; echo "${EVENTS[*]}")

mkdir -p "$OUT"

echo "=================================="
echo "Lab 4 - Perf Network Recording"
echo "=================================="
echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo "Target: $TARGET:$PORT"
echo

[[ -s "$PAYLOAD" ]] || {
    echo "ERROR: DNS payload is missing."
    exit 1
}

for event in "${EVENTS[@]}"; do
    path="${event/:/\/}"

    [[ -f "/sys/kernel/tracing/events/$path/id" ]] || {
        echo "ERROR: Missing event: $event"
        exit 1
    }
done

# Preserve previous experimental results.
for mode in syn udp; do
    for suffix in perf.data perf_script.txt stdout stderr; do
        file="$OUT/05_${mode}_${suffix}"

        [[ ! -e "$file" ]] || {
            echo "ERROR: Previous output exists: $file"
            exit 1
        }
    done
done

sudo -v

record_scan() {
    local mode="$1"
    shift

    local data="$OUT/05_${mode}_perf.data"
    local text="$OUT/05_${mode}_perf_script.txt"

    echo
    echo "----------------------------------"
    echo "Recording: $mode"
    echo "----------------------------------"

    sudo perf record \
        -a \
        --call-graph fp \
        -e "$EVENT_LIST" \
        -o "$data" \
        -- timeout --signal=TERM --kill-after=2s 12s \
           hping3 "$@" \
    > "$OUT/05_${mode}_stdout" \
    2> "$OUT/05_${mode}_stderr"

    echo "Exporting perf events..."

    sudo perf script \
        -i "$data" \
        > "$text"

    echo "Data file: $data"
    echo "Text file: $text"

    echo
    echo "Recorded event counts:"

    for event in "${EVENTS[@]}"; do
        count=$(grep -cF "$event:" "$text" || true)
        printf "%-30s %s\n" "$event" "$count"
    done

    echo
    echo "TCP reset event preview:"
    grep -m 5 -F 'tcp:tcp_send_reset:' "$text" || true

    echo
    echo "hping3 output:"
    cat "$OUT/05_${mode}_stdout"

    echo
    echo "File sizes:"
    sudo ls -lh "$data"
    wc -l "$text"
}

echo "[1/2] TCP SYN recording..."

record_scan syn \
    --syn \
    --destport "$PORT" \
    --count "$COUNT" \
    --interval u500000 \
    --numeric \
    "$TARGET"

echo
echo "[2/2] UDP recording..."

PAYLOAD_SIZE=$(stat -c '%s' "$PAYLOAD")

record_scan udp \
    --udp \
    --destport "$PORT" \
    --count "$COUNT" \
    --interval u500000 \
    --numeric \
    --data "$PAYLOAD_SIZE" \
    --file "$PAYLOAD" \
    "$TARGET"

echo
echo "=================================="
echo "Both recordings completed."
echo "=================================="
