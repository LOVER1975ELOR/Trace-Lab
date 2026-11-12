#!/usr/bin/env bash
set -euo pipefail

# Lab 5 - Test oversized IPv4 Ping with and without fragmentation.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

NS="lab5_mtu_tx"
DEVICE="l5veth_tx"
TARGET="10.205.0.2"

PAYLOAD=2000
MTU=1500

OUT="logs/baseline"
mkdir -p "$OUT"

echo "=================================="
echo "Lab 5 - Oversized Ping Test"
echo "=================================="

echo "Date: $(date -Is)"
echo "Target: $TARGET"
echo "Interface MTU: $MTU bytes"
echo "ICMP data payload: $PAYLOAD bytes"
echo "Expected IPv4 packet size: $((PAYLOAD + 8 + 20)) bytes"
echo

sudo -v

# Verify the experimental namespace.
if ! sudo ip netns list | awk '{print $1}' | grep -Fxq "$NS"; then
    echo "ERROR: Lab 5 transmitter namespace is missing."
    exit 1
fi

echo "[1] Verifying the MTU..."
sudo ip -n "$NS" link show "$DEVICE"

# Preserve previous results.
for mode in df_allowed df_disabled; do
    for extension in stdout stderr status; do
        file="$OUT/03_${mode}.${extension}"

        if [[ -e "$file" ]]; then
            echo "ERROR: Previous output exists: $file"
            exit 1
        fi
    done
done

echo
echo "[2] Ping with fragmentation prohibited (-M do)..."

if sudo timeout --kill-after=2s 8s \
    ip netns exec "$NS" \
    ping -4 -n -c 2 -W 2 \
         -M do -s "$PAYLOAD" "$TARGET" \
    > "$OUT/03_df_disabled.stdout" \
    2> "$OUT/03_df_disabled.stderr"
then
    status_do=0
else
    status_do=$?
fi

printf '%s\n' "$status_do" \
    > "$OUT/03_df_disabled.status"

echo "Exit status: $status_do"
echo "--- STDOUT ---"
cat "$OUT/03_df_disabled.stdout"
echo "--- STDERR ---"
cat "$OUT/03_df_disabled.stderr"

echo
echo "[3] Ping with fragmentation allowed (-M dont)..."

if sudo timeout --kill-after=2s 8s \
    ip netns exec "$NS" \
    ping -4 -n -c 2 -W 2 \
         -M dont -s "$PAYLOAD" "$TARGET" \
    > "$OUT/03_df_allowed.stdout" \
    2> "$OUT/03_df_allowed.stderr"
then
    status_dont=0
else
    status_dont=$?
fi

printf '%s\n' "$status_dont" \
    > "$OUT/03_df_allowed.status"

echo "Exit status: $status_dont"
echo "--- STDOUT ---"
cat "$OUT/03_df_allowed.stdout"
echo "--- STDERR ---"
cat "$OUT/03_df_allowed.stderr"

echo
echo "=================================="
echo "Test summary"
echo "=================================="
echo "Fragmentation prohibited: exit $status_do"
echo "Fragmentation allowed:    exit $status_dont"

if [[ "$status_dont" -ne 0 ]]; then
    echo "ERROR: Oversized Ping did not succeed."
    exit 1
fi

echo
echo "Oversized Ping succeeded with fragmentation allowed."
echo "Fragmentation itself will be verified using LTTng."
