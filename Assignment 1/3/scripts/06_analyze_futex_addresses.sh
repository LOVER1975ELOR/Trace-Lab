#!/usr/bin/env bash
set -euo pipefail

# Lab 3 - Inspect futex operations on the two relevant addresses.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

TRACE="logs/lttng/04_babeltrace_events.txt"
REPORT="notes/06_futex_address_analysis.txt"

ADDR_A="94419365879872"
ADDR_B="94419365879936"

[[ -s "$TRACE" ]] || {
    echo "ERROR: Babeltrace output is missing."
    exit 1
}

{
    echo "=== Lab 3: Futex Address Analysis ==="
    echo

    for addr in "$ADDR_A" "$ADDR_B"; do
        echo "======================================"
        echo "Futex uaddr: $addr"
        echo "======================================"

        matches=$(grep -F 'syscall_entry_futex:' "$TRACE" \
            | grep -F "uaddr = $addr," || true)

        echo "Recorded futex entry events:"
        if [[ -n "$matches" ]]; then
            printf '%s\n' "$matches" | wc -l
        else
            echo "0"
        fi

        echo
        echo "Operations by numeric op value:"

        if [[ -n "$matches" ]]; then
            printf '%s\n' "$matches" \
                | grep -oE 'op = [0-9]+' \
                | sort -n \
                | uniq -c
        else
            echo "No matching entries."
        fi

        echo
        echo "Last 5 matching entries:"

        if [[ -n "$matches" ]]; then
            printf '%s\n' "$matches" | tail -n 5
        fi

        echo
    done

    echo "Operation meanings:"
    echo "128 = FUTEX_WAIT_PRIVATE"
    echo "129 = FUTEX_WAKE_PRIVATE"

    echo
    echo "Analysis completed."

} | tee "$REPORT"
