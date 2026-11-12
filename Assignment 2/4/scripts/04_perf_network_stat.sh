#!/usr/bin/env bash
set -euo pipefail

# Lab 4 - Compare SYN and UDP scans using perf stat

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="logs/perf"
PAYLOAD="payloads/dns_query.bin"
TARGET="8.8.8.8"
PORT=53

mkdir -p "$OUT"

EVENTS=(
    net:net_dev_queue
    net:net_dev_start_xmit
    net:net_dev_xmit
    net:netif_receive_skb
    skb:kfree_skb
    tcp:tcp_send_reset
    udp:udp_fail_queue_rcv_skb
    sock:inet_sock_set_state
)

EVENT_LIST=$(IFS=,; echo "${EVENTS[*]}")

echo "=================================="
echo "Lab 4 - Network Perf Statistics"
echo "=================================="

echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo "Target: $TARGET"
echo "Port: $PORT"
echo

[[ -f "$PAYLOAD" ]] || {
    echo "ERROR: DNS payload not found."
    exit 1
}

for event in "${EVENTS[@]}"; do
    path="${event/:/\/}"

    if [[ ! -f "/sys/kernel/tracing/events/$path/id" ]]; then
        echo "ERROR: Missing event $event"
        exit 1
    fi
done

for name in idle syn udp; do
    if [[ -e "$OUT/04_${name}_stat.txt" ]]; then
        echo "ERROR: Previous output for $name exists."
        exit 1
    fi
done

sudo -v

echo "[1/3] Recording idle system activity..."

sudo perf stat -a \
    -e "$EVENT_LIST" \
    -o "$OUT/04_idle_stat.txt" \
    -- sleep 2

echo
echo "[2/3] Recording TCP SYN scan..."

sudo perf stat -a \
    -e "$EVENT_LIST" \
    -o "$OUT/04_syn_stat.txt" \
    -- timeout --signal=TERM --kill-after=2s 12s \
       hping3 \
       --syn \
       --destport "$PORT" \
       --count 3 \
       --interval u500000 \
       --numeric \
       "$TARGET" \
    > "$OUT/04_syn.stdout" \
    2> "$OUT/04_syn.stderr"

echo
echo "[3/3] Recording UDP scan..."

PAYLOAD_SIZE=$(stat -c '%s' "$PAYLOAD")

sudo perf stat -a \
    -e "$EVENT_LIST" \
    -o "$OUT/04_udp_stat.txt" \
    -- timeout --signal=TERM --kill-after=2s 12s \
       hping3 \
       --udp \
       --destport "$PORT" \
       --count 3 \
       --interval u500000 \
       --numeric \
       --data "$PAYLOAD_SIZE" \
       --file "$PWD/$PAYLOAD" \
       "$TARGET" \
    > "$OUT/04_udp.stdout" \
    2> "$OUT/04_udp.stderr"

echo
echo "=================================="
echo "IDLE SYSTEM STATISTICS"
echo "=================================="
cat "$OUT/04_idle_stat.txt"

echo
echo "=================================="
echo "TCP SYN STATISTICS"
echo "=================================="
cat "$OUT/04_syn_stat.txt"

echo
echo "=================================="
echo "UDP STATISTICS"
echo "=================================="
cat "$OUT/04_udp_stat.txt"

echo
echo "=================================="
echo "SCAN RESULTS"
echo "=================================="

echo "--- TCP SYN ---"
cat "$OUT/04_syn.stdout"

echo
echo "--- UDP ---"
cat "$OUT/04_udp.stdout"

echo
echo "--- Scan warnings/errors ---"
cat "$OUT/04_syn.stderr"
cat "$OUT/04_udp.stderr"

echo
echo "Perf statistics completed."
