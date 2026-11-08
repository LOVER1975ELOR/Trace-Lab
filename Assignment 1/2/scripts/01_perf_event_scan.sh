#!/usr/bin/env bash

set -uo pipefail

# Lab 2 - Perf Event Discovery
# Test the event families requested in the assignment.

cd "$(dirname "$0")/.."

mkdir -p logs/perf

echo "=================================="
echo "Lab 2 - Perf Event Discovery"
echo "=================================="

echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo "Perf: $(perf --version)"
echo

# Obtain permission before starting the tests.
sudo -v || exit 1

groups=("kmem" "netif" "tcp" "i2c")
events=("kmem:*" "net:netif*" "tcp:*" "i2c:*")

for i in "${!groups[@]}"; do

    group="${groups[$i]}"
    event="${events[$i]}"

    echo "----------------------------------"
    echo "Testing: $group"
    echo "Event pattern: $event"
    echo "----------------------------------"

    if sudo perf stat \
        -e "$event" \
        -o "logs/perf/${group}_stat.txt" \
        -- setpriv \
           --reuid="$(id -u)" \
           --regid="$(id -g)" \
           --init-groups \
           -- ./src/program \
        > "logs/perf/${group}_stdout.txt" \
        2> "logs/perf/${group}_errors.txt"
    then
        echo "Result: SUCCESS"
    else
        echo "Result: FAILED (exit code $?)"
        cat "logs/perf/${group}_errors.txt"
    fi

    echo
done

echo "=================================="
echo "All event groups tested."
echo "=================================="
