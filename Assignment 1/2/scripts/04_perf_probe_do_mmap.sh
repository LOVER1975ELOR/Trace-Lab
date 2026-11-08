#!/usr/bin/env bash
set -euo pipefail

# Lab 2 - Trace do_mmap using a temporary perf probe.

cd "$(dirname "$0")/.."

DATA="logs/perf/do_mmap_probe.data"
TEXT="logs/perf/do_mmap_probe_script.txt"
STACKS="notes/do_mmap_syscall_stacks.txt"
PROBE="lab2_mmap:entry"

mkdir -p logs/perf notes

echo "=== Lab 2: do_mmap Probe ==="
echo "Kernel: $(uname -r)"
echo "Perf: $(perf --version)"

# Never overwrite an earlier experiment.
if [[ -e "$DATA" ]]; then
    echo "ERROR: $DATA already exists."
    exit 1
fi

sudo -v

# Do not modify a probe from an earlier experiment.
if sudo perf probe --list | grep -Fq "$PROBE"; then
    echo "ERROR: Probe $PROBE already exists."
    exit 1
fi

created=0

cleanup() {
    if [[ "$created" -eq 1 ]]; then
        echo "[Cleanup] Removing temporary probe..."
        sudo perf probe --del "$PROBE" || true
    fi
}

trap cleanup EXIT

echo
echo "[1/4] Creating do_mmap probe..."

sudo perf probe --add 'lab2_mmap:entry=do_mmap'
created=1

echo
echo "[2/4] Recording do_mmap calls..."

if sudo perf record \
    --call-graph fp \
    -e "$PROBE" \
    -o "$DATA" \
    -- setpriv \
       --reuid="$(id -u)" \
       --regid="$(id -g)" \
       --init-groups \
       -- ./src/program \
    > logs/perf/do_mmap_probe.stdout \
    2> logs/perf/do_mmap_probe.stderr
then
    echo "Recording: SUCCESS"
else
    status=$?
    cat logs/perf/do_mmap_probe.stderr
    exit "$status"
fi

echo
echo "[3/4] Exporting call stacks..."

sudo perf script -i "$DATA" > "$TEXT"

echo
echo "[4/4] Extracting mmap syscall stacks..."

awk '
BEGIN { RS = ""; ORS = "\n\n" }
/lab2_mmap:entry:/ &&
/__x64_sys_mmap|__se_sys_mmap|ksys_mmap_pgoff/ {
    print
    count++
    if (count >= 3) exit
}
' "$TEXT" > "$STACKS"

echo "Recorded do_mmap entries:"
grep -c 'lab2_mmap:entry:' "$TEXT" || true

echo
echo "Call stacks from the mmap syscall path:"
if [[ -s "$STACKS" ]]; then
    cat "$STACKS"
else
    echo "No matching syscall-path stack extracted."
    echo "Inspect the complete perf script."
fi

echo
echo "Data file: $DATA"
echo "Text file: $TEXT"
echo "Recording complete."
