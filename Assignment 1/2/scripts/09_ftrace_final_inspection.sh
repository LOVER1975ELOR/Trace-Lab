#!/usr/bin/env bash
set -euo pipefail

# Lab 2 - Final inspection of ftrace memory mapping

cd "$(dirname "$0")/.."

TRACE="logs/ftrace/08_do_mmap_ftrace.trace"
OUT="notes"

[[ -s "$TRACE" ]] || {
    echo "ERROR: ftrace output is missing."
    exit 1
}

echo "=== Lab 2: ftrace Final Inspection ==="
echo

echo "[1] Memory Event Counts"

events=(
    sys_enter_mmap
    sys_exit_mmap
    kmalloc
    kmem_cache_alloc
    mm_page_alloc
    rss_stat
)

for event in "${events[@]}"; do
    count=$(grep -Fc "/* ${event}:" "$TRACE" || true)
    printf "%-25s %s\n" "$event" "$count"
done | tee "$OUT/ftrace_event_counts.txt"

echo
echo "[2] Extracting last complete do_mmap graph"

awk '
/\|[[:space:]]*do_mmap\(\)[[:space:]]*\{/ {
    collecting = 1
    block = ""
    depth = 0
}

collecting {
    block = block $0 "\n"

    line = $0
    opens = gsub(/\{/, "{", line)

    line = $0
    closes = gsub(/\}/, "}", line)

    depth += opens - closes

    if (depth == 0) {
        last = block
        found++
        collecting = 0
    }
}

END {
    if (found == 0) exit 1
    printf "%s", last
}
' "$TRACE" > "$OUT/ftrace_last_do_mmap_graph.txt"

echo "Last complete graph extracted."

echo
echo "[3] Last mmap syscall events"

grep -E 'sys_enter_mmap:|sys_exit_mmap:' "$TRACE" \
    | tail -n 12 \
    | tee "$OUT/ftrace_last_mmap_events.txt" || true

echo
echo "Inspection completed."
