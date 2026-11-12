#!/usr/bin/env bash
set -euo pipefail

# Lab 4 - Controlled TCP SYN scan
# Target: 8.8.8.8, TCP port 53

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="logs/baseline"
TARGET="8.8.8.8"
PORT=53
COUNT=3

mkdir -p "$OUT"

STDOUT="$OUT/02_syn_scan.stdout"
STDERR="$OUT/02_syn_scan.stderr"
STATUS="$OUT/02_syn_exit_status.txt"

if [[ -e "$STDOUT" || -e "$STDERR" || -e "$STATUS" ]]; then
    echo "ERROR: Previous SYN scan results exist."
    exit 1
fi

echo "=================================="
echo "Lab 4 - TCP SYN Scan"
echo "=================================="

echo "Date: $(date -Is)"
echo "Target: $TARGET"
echo "Protocol: TCP SYN"
echo "Destination port: $PORT"
echo "Packet count: $COUNT"
echo "Interval: 500 milliseconds"
echo

sudo -v

echo "[1] Running hping3..."

if sudo timeout --signal=TERM --kill-after=2s 12s \
    hping3 \
       --syn \
       --destport "$PORT" \
       --count "$COUNT" \
       --interval u500000 \
       --numeric \
       "$TARGET" \
    > "$STDOUT" \
    2> "$STDERR"
then
    result=0
else
    result=$?
fi

echo
echo "[2] Exit status: $result"
printf '%s\n' "$result" > "$STATUS"

echo
echo "========== STDOUT =========="
cat "$STDOUT"

echo
echo "========== STDERR =========="
cat "$STDERR"

echo
echo "Scan completed."
