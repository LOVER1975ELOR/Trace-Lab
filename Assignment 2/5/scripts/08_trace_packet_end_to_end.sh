#!/usr/bin/env bash
set -euo pipefail

# Lab 5 - Coordinated LTTng and tcpdump recording
# Trace a single fragmented ICMP Echo request and reply.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

NS="lab5_mtu_tx"
DEV="l5veth_tx"
TARGET="10.205.0.2"
PAYLOAD=2000

SESSION="lab5_packet_${UID}_$$"

LTTNG_OUT="$PWD/logs/lttng"
PCAP_OUT="$PWD/logs/pcap"
BASE_OUT="$PWD/logs/baseline"

TRACE="$LTTNG_OUT/08_packet_trace"
GUI="$LTTNG_OUT/08_packet_trace_gui"
EVENTS_FILE="$LTTNG_OUT/08_packet_events.txt"
PCAP="$PCAP_OUT/08_ping_2000.pcap"

mkdir -p "$LTTNG_OUT" "$PCAP_OUT" "$BASE_OUT" notes

NETWORK_EVENTS=(
    net_dev_queue
    net_dev_xmit
    net_dev_start_xmit
    netif_receive_skb
    sched_switch
    sched_wakeup
    sched_waking
)

SYSCALLS="socket,sendto,sendmsg,recvfrom,recvmsg,setsockopt"

sudo -v

echo "=================================="
echo "Lab 5 - End-to-End Packet Trace"
echo "=================================="
echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo "Target: $TARGET"
echo "Payload: $PAYLOAD bytes"
echo

# Check required programs.
for tool in lttng tcpdump tshark babeltrace ping; do
    command -v "$tool" >/dev/null || {
        echo "ERROR: Missing tool: $tool"
        exit 1
    }
done

# Check the lab network without modifying it.
sudo ip -n "$NS" link show "$DEV" |
    grep -q 'mtu 1500' || {
        echo "ERROR: Experimental MTU is not 1500."
        exit 1
    }

# Never overwrite existing experimental evidence.
for path in \
    "$TRACE" "$GUI" "$EVENTS_FILE" "$PCAP" \
    "$BASE_OUT/08_ping.stdout" \
    "$PCAP_OUT/08_tshark_fragments.txt"
do
    if [[ -e "$path" ]]; then
        echo "ERROR: Previous output exists: $path"
        exit 1
    fi
done

created=0
started=0
capture_pid=""

cleanup() {
    rc=$?
    trap - EXIT INT TERM

    if [[ -n "$capture_pid" ]]; then
        wait "$capture_pid" 2>/dev/null || true
    fi

    if (( created )); then
        if (( started )); then
            sudo lttng stop "$SESSION" || true
        fi
        sudo lttng destroy "$SESSION" || true
    fi

    exit "$rc"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "[1] Creating LTTng session..."

sudo lttng create "$SESSION" --output="$TRACE"
created=1

echo
echo "[2] Enabling network and scheduling events..."

for event in "${NETWORK_EVENTS[@]}"; do
    sudo lttng enable-event \
        --kernel --tracepoint "$event" \
        --session="$SESSION"
done

echo
echo "[3] Enabling system calls..."

sudo lttng enable-event \
    --kernel --syscall "$SYSCALLS" \
    --session="$SESSION"

echo
echo "[4] Adding process and thread context..."

sudo lttng add-context \
    --kernel \
    --session="$SESSION" \
    --type=vpid \
    --type=vtid \
    --type=procname

sudo lttng list "$SESSION" \
    > notes/08_lttng_configuration.txt

echo
echo "[5] Starting LTTng..."

sudo lttng start "$SESSION"
started=1

echo
echo "[6] Starting packet capture in the transmitter namespace..."

# Capture complete IPv4 frames.
# The 4-packet limit covers two request fragments and
# two reply fragments in the expected case.
# The timeout prevents a lingering capture process.
sudo timeout --signal=INT --kill-after=2s 7s \
    ip netns exec "$NS" \
    tcpdump -i "$DEV" -nn -s 0 -U -c 4 \
        -w "$PCAP" 'ip' \
    > "$PCAP_OUT/08_tcpdump.stdout" \
    2> "$PCAP_OUT/08_tcpdump.stderr" &

capture_pid=$!

# Allow tcpdump to initialize before Ping.
sleep 1

if ! kill -0 "$capture_pid" 2>/dev/null; then
    echo "ERROR: Packet capture stopped before Ping."
    cat "$PCAP_OUT/08_tcpdump.stderr"
    exit 1
fi

echo
echo "[7] Sending one oversized Ping..."

if sudo timeout --kill-after=2s 5s \
    ip netns exec "$NS" \
    ping -4 -n -c 1 -W 2 \
         -M dont -s "$PAYLOAD" "$TARGET" \
    > "$BASE_OUT/08_ping.stdout" \
    2> "$BASE_OUT/08_ping.stderr"
then
    echo "Ping: SUCCESS"
else
    status=$?
    echo "Ping: FAILED ($status)"
    cat "$BASE_OUT/08_ping.stderr"
    exit "$status"
fi

echo
echo "[8] Finishing packet capture..."

if wait "$capture_pid"; then
    capture_status=0
else
    capture_status=$?
fi

capture_pid=""

echo "tcpdump exit status: $capture_status"
cat "$PCAP_OUT/08_tcpdump.stderr"

echo
echo "[9] Stopping LTTng..."

sudo lttng stop "$SESSION"
started=0

sudo lttng destroy "$SESSION"
created=0

echo
echo "[10] Preparing readable files..."

sudo cp -a "$TRACE" "$GUI"
sudo chown -R "$(id -u):$(id -g)" "$GUI"
sudo chown "$(id -u):$(id -g)" "$PCAP"

babeltrace "$GUI/kernel" > "$EVENTS_FILE"

echo
echo "[11] Extracting packet headers with TShark..."

tshark -r "$PCAP" \
    -T fields \
    -E header=y \
    -E separator=, \
    -e frame.number \
    -e ip.src \
    -e ip.dst \
    -e ip.id \
    -e ip.len \
    -e ip.flags.mf \
    -e ip.frag_offset \
    -e icmp.type \
    > "$PCAP_OUT/08_tshark_fragments.txt"

echo
echo "========== PING OUTPUT =========="
cat "$BASE_OUT/08_ping.stdout"

echo
echo "========== PCAP PACKETS =========="
cat "$PCAP_OUT/08_tshark_fragments.txt"

echo
echo "========== LTTNG EVENT COUNTS =========="

for event in \
    net_dev_queue \
    net_dev_xmit \
    net_dev_start_xmit \
    netif_receive_skb \
    sched_switch \
    syscall_entry_sendto \
    syscall_entry_sendmsg
do
    count=$(grep -cF " $event:" "$EVENTS_FILE" || true)
    printf "%-30s %s\n" "$event" "$count"
done

echo
echo "========== FILES =========="

ls -lh "$PCAP"
du -sh "$GUI"
wc -l "$EVENTS_FILE"

echo
echo "Recording completed."
echo "Trace Compass: $GUI/kernel"
echo "Wireshark PCAP: $PCAP"
