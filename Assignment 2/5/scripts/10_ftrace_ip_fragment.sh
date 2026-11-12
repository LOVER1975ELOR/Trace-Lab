#!/usr/bin/env bash
set -euo pipefail

# Lab 5 - Trace IPv4 fragmentation with ftrace function_graph.
# Record one oversized Ping and restore the main tracer settings.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

TRACEFS="/sys/kernel/tracing"
OUT="logs/ftrace"

FUNCTION="ip_fragment.constprop.0"
NS="lab5_mtu_tx"
DEVICE="l5veth_tx"
TARGET="10.205.0.2"

GRAPH="$OUT/10_ip_fragment.graph"
BEFORE="$OUT/10_previous_main_trace.txt"
PING_OUT="$OUT/10_ping.stdout"
PING_ERR="$OUT/10_ping.stderr"

mkdir -p "$OUT" notes

sudo -v

echo "======================================"
echo "Lab 5 - IPv4 Fragmentation Function Graph"
echo "======================================"
echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo "Target function: $FUNCTION"
echo

# Never overwrite previous evidence.
for file in "$GRAPH" "$BEFORE" "$PING_OUT" "$PING_ERR"; do
    if [[ -e "$file" ]]; then
        echo "ERROR: Previous output exists: $file"
        exit 1
    fi
done

echo "[1] Checking the tracing environment..."

sudo grep -Fxq "$FUNCTION" \
    "$TRACEFS/available_filter_functions" || {
    echo "ERROR: Target function is unavailable."
    exit 1
}

grep -qw function_graph \
    <(sudo cat "$TRACEFS/available_tracers") || {
    echo "ERROR: function_graph tracer is unavailable."
    exit 1
}

echo
echo "[2] Checking the main ftrace configuration..."

ORIGINAL_TRACING_ON=$(sudo cat "$TRACEFS/tracing_on")
ORIGINAL_TRACER=$(sudo cat "$TRACEFS/current_tracer")
ORIGINAL_EVENTS=$(sudo cat "$TRACEFS/set_event")
ORIGINAL_GRAPH=$(sudo cat "$TRACEFS/set_graph_function")
ORIGINAL_FILTER=$(sudo cat "$TRACEFS/set_ftrace_filter")
ORIGINAL_PID=$(sudo cat "$TRACEFS/set_ftrace_pid")

if [[ "$ORIGINAL_TRACER" != "nop" ||
      -n "$ORIGINAL_EVENTS" ||
      "$ORIGINAL_GRAPH" != "#### all functions enabled ####" ||
      "$ORIGINAL_FILTER" != "#### all functions enabled ####" ||
      "$ORIGINAL_PID" != "no pid" ]]; then

    echo "ERROR: Main ftrace contains unexpected settings."
    echo "Refusing to overwrite another tracing configuration."
    exit 1
fi

echo "Main tracer configuration is safe to use."

echo
echo "[3] Checking experimental network..."

sudo ip -n "$NS" link show "$DEVICE" \
    | grep -q 'mtu 1500' || {
    echo "ERROR: Expected MTU 1500 was not found."
    exit 1
}

write_trace() {
    printf '%s\n' "$2" |
        sudo tee "$TRACEFS/$1" >/dev/null
}

clear_trace_file() {
    printf '\n' |
        sudo tee "$TRACEFS/$1" >/dev/null
}

armed=0

cleanup() {
    rc=$?
    trap - EXIT INT TERM

    if (( armed )); then
        echo
        echo "[Cleanup] Restoring main ftrace settings..."

        write_trace tracing_on 0 || true
        clear_trace_file set_graph_function || true
        write_trace current_tracer nop || true
        write_trace tracing_on "$ORIGINAL_TRACING_ON" || true

        echo "Restoration attempted."
    fi

    exit "$rc"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo
echo "[4] Preserving the existing trace buffer..."

sudo cat "$TRACEFS/trace" > "$BEFORE"

armed=1

echo
echo "[5] Configuring function_graph..."

write_trace tracing_on 0

clear_trace_file trace

write_trace set_graph_function "$FUNCTION"

write_trace current_tracer function_graph

echo "Current tracer:"
sudo cat "$TRACEFS/current_tracer"

echo "Graph root:"
sudo cat "$TRACEFS/set_graph_function"

echo
echo "[6] Starting tracing..."

write_trace tracing_on 1

echo
echo "[7] Running one oversized Ping..."

if sudo timeout --kill-after=2s 5s \
    ip netns exec "$NS" \
    ping -4 -n -c 1 -W 2 \
         -M dont -s 2000 "$TARGET" \
    > "$PING_OUT" \
    2> "$PING_ERR"
then
    program_status=0
else
    program_status=$?
fi

echo
echo "[8] Stopping and exporting the trace..."

write_trace tracing_on 0

sudo cat "$TRACEFS/trace" > "$GRAPH"

echo
echo "========== PING OUTPUT =========="
cat "$PING_OUT"

echo
echo "========== PING ERRORS =========="
cat "$PING_ERR"

echo
echo "========== TRACE DETAILS =========="
wc -lc "$GRAPH"

echo
echo "========== MATCHING FUNCTIONS =========="

grep -n -m 25 -E \
    'ip_fragment|ip_do_fragment|ip_frag_next|ip_frag_init|ip_fraglist|ip_finish_output|dev_queue_xmit' \
    "$GRAPH" || true

echo
echo "========== FUNCTION GRAPH PREVIEW =========="

sed -n '1,110p' "$GRAPH"

echo
echo "Ping exit status: $program_status"

if [[ "$program_status" -ne 0 ]]; then
    exit "$program_status"
fi

echo
echo "Function graph recording completed."
echo "Trace file: $GRAPH"
