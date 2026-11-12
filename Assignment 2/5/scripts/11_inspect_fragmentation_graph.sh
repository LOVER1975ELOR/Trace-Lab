#!/usr/bin/env bash
set -euo pipefail

# Lab 5 - Read-only inspection of the saved fragmentation graph.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

TRACE="logs/ftrace/10_ip_fragment.graph"
REPORT="notes/11_fragmentation_graph_summary.txt"

mkdir -p notes

[[ -s "$TRACE" ]] || {
    echo "ERROR: Saved function graph not found."
    exit 1
}

{
    echo "=== Lab 5 - Fragmentation Function Graph Analysis ==="
    echo "Kernel: $(uname -r)"
    echo

    echo "[1] Function occurrence counts"

    functions=(
        "ip_fragment.constprop.0() {"
        "ip_do_fragment() {"
        "ip_fraglist_init() {"
        "ip_fraglist_prepare() {"
        "ip_frag_next() {"
        "ip_finish_output2() {"
        "__dev_queue_xmit() {"
        "dev_hard_start_xmit() {"
        "veth_xmit [veth]() {"
    )

    for function in "${functions[@]}"; do
        count=$(grep -Fc "$function" "$TRACE" || true)
        printf "%-36s %s\n" "$function" "$count"
    done

    echo
    echo "[2] Relevant functions and line numbers"

    grep -nE \
        'ip_fragment\.constprop\.0\(\)|ip_do_fragment\(\)|ip_fraglist_(init|prepare|next)\(\)|ip_frag_(init|next)\(\)|ip_finish_output2\(\)|__dev_queue_xmit\(\)|dev_hard_start_xmit\(\)|veth_xmit' \
        "$TRACE" || true

    echo
    echo "[3] First fragmentation call - opening section"

    sed -n '5,47p' "$TRACE"

    echo
    echo "[4] Second fragmentation call - opening section"

    sed -n '949,992p' "$TRACE"

    echo
    echo "[5] Saved graph size"

    wc -lc "$TRACE"

    echo
    echo "Analysis completed."

} | tee "$REPORT"
