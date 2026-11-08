#!/usr/bin/env bash

set -euo pipefail

# Lab 2 - Recording memory-related events with perf

cd "$(dirname "$0")/.."

mkdir -p logs/perf

DATA_FILE="logs/perf/mmap_memory.data"
SCRIPT_FILE="logs/perf/mmap_memory_script.txt"

EVENTS="syscalls:sys_enter_mmap,syscalls:sys_exit_mmap,kmem:kmalloc,kmem:kmem_cache_alloc,kmem:mm_page_alloc,kmem:rss_stat"

echo "=================================="
echo "Lab 2 - Perf Memory Recording"
echo "=================================="

echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo "Events: $EVENTS"
echo

# Preserve previous results.
if [[ -e "$DATA_FILE" ]]; then
    echo "ERROR: $DATA_FILE already exists."
    echo "Move the old file before repeating the test."
    exit 1
fi

sudo -v

echo "[1/2] Recording events..."

if sudo perf record \
    --call-graph fp \
    -e "$EVENTS" \
    -o "$DATA_FILE" \
    -- setpriv \
       --reuid="$(id -u)" \
       --regid="$(id -g)" \
       --init-groups \
       -- ./src/program \
    > logs/perf/mmap_record.stdout \
    2> logs/perf/mmap_record.stderr
then
    echo "Perf recording: SUCCESS"
else
    status=$?
    echo "Perf recording: FAILED ($status)"
    cat logs/perf/mmap_record.stderr
    exit "$status"
fi

echo "[2/2] Exporting perf script..."

sudo perf script \
    -i "$DATA_FILE" \
    > "$SCRIPT_FILE" \
    2> logs/perf/mmap_script.stderr

echo
echo "Recording completed."
echo "Data: $DATA_FILE"
echo "Script: $SCRIPT_FILE"

sudo ls -lh "$DATA_FILE"
wc -l "$SCRIPT_FILE"
