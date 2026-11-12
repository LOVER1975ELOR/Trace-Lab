#!/usr/bin/env bash
set -euo pipefail

# Lab 4 - Compare TCP reset events in saved perf recordings.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SYN="logs/perf/05_syn_perf_script.txt"
UDP="logs/perf/05_udp_perf_script.txt"
REPORT="notes/06_syn_udp_comparison.txt"

mkdir -p notes

for file in "$SYN" "$UDP"; do
    [[ -s "$file" ]] || {
        echo "ERROR: Missing or empty file: $file"
        exit 1
    }
done

[[ ! -e "$REPORT" ]] || {
    echo "ERROR: Previous report already exists."
    exit 1
}

{
    echo "=== Lab 4 - SYN vs UDP Comparison ==="
    echo "Kernel: $(uname -r)"
    echo "Target: 8.8.8.8"
    echo "Port: 53"
    echo

    echo "[1] Selected event: tcp:tcp_send_reset"
    echo

    for mode in syn udp; do
        if [[ "$mode" == syn ]]; then
            trace="$SYN"
        else
            trace="$UDP"
        fi

        total=$(grep -cF 'tcp:tcp_send_reset:' \
            "$trace" || true)

        target=$(awk '
          /tcp:tcp_send_reset:/ &&
          /dest=8\.8\.8\.8:53/ { count++ }
          END { print count+0 }
        ' "$trace")

        echo "$mode:"
        echo "  Total TCP reset events: $total"
        echo "  Resets targeting 8.8.8.8:53: $target"
        echo
    done

    echo "[2] TCP reset event details from SYN scan"
    echo

    grep -F 'tcp:tcp_send_reset:' "$SYN" || true

    echo
    echo "[3] First observed TCP reset call stack"
    echo

    awk '
      /tcp:tcp_send_reset:/ {
          found = 1
      }
      found {
          print
          count++
          if (count >= 22) exit
      }
    ' "$SYN"

    echo
    echo "[4] Comparing other network event counts"
    echo

    EVENTS=(
        net:net_dev_queue
        net:net_dev_xmit
        net:netif_receive_skb
        skb:kfree_skb
        tcp:tcp_send_reset
    )

    printf "%-29s %8s %8s\n" "Event" "SYN" "UDP"

    for event in "${EVENTS[@]}"; do
        syn_count=$(grep -cF "$event:" "$SYN" || true)
        udp_count=$(grep -cF "$event:" "$UDP" || true)

        printf "%-29s %8s %8s\n" \
            "$event" "$syn_count" "$udp_count"
    done

    echo
    echo "Comparison completed."

} | tee "$REPORT"
