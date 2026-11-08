#!/usr/bin/env bash
set -euo pipefail

# Lab 2 - Inspect do_mmap samples from the program.

cd "$(dirname "$0")/.."

TRACE="logs/perf/do_mmap_probe_script.txt"
ALL="notes/do_mmap_program_samples.txt"
CANDIDATE="notes/do_mmap_application_candidate.txt"

if [[ ! -s "$TRACE" ]]; then
    echo "ERROR: perf script output not found."
    exit 1
fi

echo "=== do_mmap Samples by Process ==="

grep 'lab2_mmap:entry:' "$TRACE" \
    | awk '{count[$1]++}
           END {
               for (name in count)
                   print name, count[name]
           }' \
    | sort

echo
echo "=== Extracting Program Samples ==="

awk '
BEGIN { RS = ""; ORS = "\n\n" }
$1 == "program" && /lab2_mmap:entry:/ {
    print
}
' "$TRACE" > "$ALL"

echo "Program sample count:"
grep -c '^program ' "$ALL" || true

echo
echo "=== Searching for a syscall-path candidate ==="

awk '
BEGIN { RS = ""; ORS = "\n\n" }
$1 == "program" &&
/lab2_mmap:entry:/ &&
/__x64_sys_mmap/ &&
!/ld-linux-x86-64.so.2/ {
    print
    exit
}
' "$TRACE" > "$CANDIDATE"

if [[ -s "$CANDIDATE" ]]; then
    echo "Candidate found:"
    cat "$CANDIDATE"
else
    echo "No matching candidate found."
fi

echo
echo "Analysis completed."
