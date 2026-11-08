#!/usr/bin/env bash
set -euo pipefail

# Lab 2 - Extract the final mmap syscall and its function graph
# from the same ftrace recording.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

TRACE="logs/ftrace/08_do_mmap_ftrace.trace"
SEGMENT="notes/ftrace_explicit_mmap_segment.txt"

[[ -s "$TRACE" ]] || {
    echo "ERROR: Combined ftrace file is missing."
    exit 1
}

echo "=== Lab 2: Explicit mmap Evidence ==="
echo

echo "[1] mmap syscall counts in combined trace"

printf "Entries: "
grep -Fc '/* sys_mmap(addr:' "$TRACE" || true

printf "Exits:   "
grep -Fc '/* sys_mmap ->' "$TRACE" || true

echo
echo "[2] Extracting final complete mmap syscall interval"

awk '
/\/\* sys_mmap\(addr:/ {
    collecting = 1
    block = $0 "\n"
    next
}

collecting {
    block = block $0 "\n"

    if (/\/\* sys_mmap ->/) {
        last = block
        collecting = 0
    }
}

END {
    if (length(last) == 0) exit 1
    printf "%s", last
}
' "$TRACE" > "$SEGMENT"

echo "Extracted file: $SEGMENT"
wc -l "$SEGMENT"

echo
echo "[3] Important lines from the extracted interval"

grep -E \
    'sys_mmap|do_mmap\(\)|__get_unmapped_area\(\)|mmap_region\(\)|__mmap_region\(\)|vma_merge_new_range\(\)|__mmap_new_vma\(\)' \
    "$SEGMENT" || true

echo
echo "[4] Does this interval contain do_mmap?"

if grep -Fq 'do_mmap() {' "$SEGMENT"; then
    echo "YES: do_mmap is present."
else
    echo "NO: do_mmap was not found in this interval."
fi

echo
echo "[5] Program output from the same recording"

cat logs/ftrace/08_program.stdout

echo
echo "Evidence extraction completed."
