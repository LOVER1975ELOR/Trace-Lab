#!/usr/bin/env bash
set -euo pipefail

# Lab 4 - Controlled UDP scan with DNS payload
# Target: 8.8.8.8, UDP port 53

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="logs/baseline"
TARGET="8.8.8.8"
PORT=53
COUNT=3

PAYLOAD="$PWD/payloads/dns_query.bin"

STDOUT="$OUT/03_udp_scan.stdout"
STDERR="$OUT/03_udp_scan.stderr"
STATUS="$OUT/03_udp_exit_status.txt"

mkdir -p "$OUT" payloads

if [[ -e "$STDOUT" || -e "$STDERR" || -e "$STATUS" ]]; then
    echo "ERROR: Previous UDP scan results exist."
    exit 1
fi

echo "=================================="
echo "Lab 4 - UDP Scan with DNS Payload"
echo "=================================="

echo "Date: $(date -Is)"
echo "Target: $TARGET"
echo "Protocol: UDP"
echo "Destination port: $PORT"
echo "Packet count: $COUNT"
echo "Interval: 500 milliseconds"
echo

echo "[1] Creating a DNS query payload..."

python3 - "$PAYLOAD" <<'PY'
from pathlib import Path
import struct
import sys

path = Path(sys.argv[1])

# DNS header:
# Transaction ID = 0x1234
# Flags = 0x0100 (standard query, recursion desired)
# One question
header = struct.pack(
    "!HHHHHH",
    0x1234, 0x0100, 1, 0, 0, 0
)

# DNS question for example.com
labels = [b"example", b"com"]

qname = b"".join(
    bytes([len(label)]) + label for label in labels
) + b"\x00"

# QTYPE = A, QCLASS = IN
question = qname + struct.pack("!HH", 1, 1)

data = header + question

if path.exists():
    if path.read_bytes() != data:
        raise SystemExit("ERROR: Existing payload differs.")
else:
    path.write_bytes(data)

print(f"Payload file: {path}")
print(f"Payload size: {len(data)} bytes")
print(f"Payload hex: {data.hex(' ')}")
PY

PAYLOAD_SIZE=$(stat -c '%s' "$PAYLOAD")

echo
echo "[2] Sending UDP packets..."

sudo -v

if sudo timeout --signal=TERM --kill-after=2s 12s \
    hping3 \
       --udp \
       --destport "$PORT" \
       --count "$COUNT" \
       --interval u500000 \
       --numeric \
       --data "$PAYLOAD_SIZE" \
       --file "$PAYLOAD" \
       "$TARGET" \
    > "$STDOUT" \
    2> "$STDERR"
then
    result=0
else
    result=$?
fi

echo
echo "[3] Exit status: $result"
printf '%s\n' "$result" > "$STATUS"

echo
echo "========== STDOUT =========="
cat "$STDOUT"

echo
echo "========== STDERR =========="
cat "$STDERR"

echo
echo "Scan completed."
