#!/usr/bin/env bash
set -euo pipefail

# Lab 3 - First controlled execution of deadlock_m

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SOURCE="reference/Lab 3/src/deadlock_m"
PROGRAM="src/deadlock_m"
OUT="logs/baseline"

mkdir -p "$OUT" notes

echo "=================================="
echo "Lab 3 - Baseline Execution"
echo "=================================="

echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo

# Copy the original binary without modifying its contents.
if [[ ! -e "$PROGRAM" ]]; then
    cp "$SOURCE" "$PROGRAM"
fi

if ! cmp -s "$SOURCE" "$PROGRAM"; then
    echo "ERROR: The local binary differs from the supplied file."
    exit 1
fi

chmod u+x "$PROGRAM"

echo "[1] Checking executable..."
file "$PROGRAM"

echo
echo "[2] Verifying SHA256..."
sha256sum "$PROGRAM"

echo
echo "[3] Running program (maximum 8 seconds)..."
echo

# Disable core dumps and preserve output immediately.
ulimit -c 0

if timeout --signal=TERM --kill-after=2s 8s \
    stdbuf -o0 -e0 "./$PROGRAM" \
    > "$OUT/02_program.stdout" \
    2> "$OUT/02_program.stderr"
then
    status=0
else
    status=$?
fi

echo "Program exit status: $status"

if [[ "$status" -eq 124 ]]; then
    echo "Observation: The 8-second timeout was reached."
elif [[ "$status" -eq 0 ]]; then
    echo "Observation: The program finished normally."
else
    echo "Observation: Program ended with status $status."
fi

echo
echo "========== STDOUT =========="
cat "$OUT/02_program.stdout"

echo
echo "========== STDERR =========="
cat "$OUT/02_program.stderr"

echo
echo "========== OUTPUT FILES =========="
wc -lc "$OUT/02_program.stdout" "$OUT/02_program.stderr"

printf '%s\n' "$status" > "$OUT/02_exit_status.txt"

echo
echo "Baseline experiment completed."
