#!/usr/bin/env bash
set -euo pipefail

# Lab 2 - Inspect perf events and do_mmap call stacks

cd "$(dirname "$0")/.."

TRACE="logs/perf/mmap_memory_script.txt"

if [[ ! -s "$TRACE" ]]; then
    echo "ERROR: Perf script output is missing or empty."
    exit 1
fi

echo "=== Perf Event Counts ==="

events=(
    "syscalls:sys_enter_mmap"
    "syscalls:sys_exit_mmap"
    "kmem:kmalloc"
    "kmem:kmem_cache_alloc"
    "kmem:mm_page_alloc"
    "kmem:rss_stat"
)

for event in "${events[@]}"; do
    count=$(grep -cF " $event:" "$TRACE" || true)
    printf "%-34s %s\n" "$event" "$count"
done | tee notes/perf_record_event_counts.txt

echo
echo "=== mmap Events by Process Name ==="

awk '
/syscalls:sys_enter_mmap:|syscalls:sys_exit_mmap:/ {
    kind = ($0 ~ /sys_enter_mmap:/) ? "enter" : "exit"
    print $1, kind
}' "$TRACE" | sort | uniq -c \
    | tee notes/perf_mmap_process_counts.txt

echo
echo "=== do_mmap Stack Matches ==="

grep -n -m 15 -E '[[:space:]]do_mmap\+' "$TRACE" \
    | tee notes/do_mmap_matches.txt || true

echo
echo "=== Extracting Program Call Stacks ==="

awk '
BEGIN { RS = ""; ORS = "\n\n" }
/^program[[:space:]]/ && /[[:space:]]do_mmap\+/ {
    print
    count++
    if (count >= 2) exit
}
' "$TRACE" > notes/do_mmap_stack_examples.txt

if [[ -s notes/do_mmap_stack_examples.txt ]]; then
    echo "Found do_mmap call stacks for program."
else
    echo "No program-specific do_mmap stack found."
    echo "A direct function probe may be needed."
fi

echo
echo "Analysis completed."
