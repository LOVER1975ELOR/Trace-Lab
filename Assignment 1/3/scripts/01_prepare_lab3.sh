#!/usr/bin/env bash
set -euo pipefail

# Lab 3 - Prepare workspace and inspect supplied executable

cd "$(dirname "${BASH_SOURCE[0]}")/.."

mkdir -p src scripts logs/baseline logs/perf \
         logs/lttng notes screenshots

REPO="https://github.com/ShamsAli-fathi/OS-Tracing.git"
SOURCE_DIR="reference/Lab 3/src"

echo "=================================="
echo "Lab 3 - Initial Preparation"
echo "=================================="

echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo "Perf: $(perf --version)"
echo

echo "[1] Obtaining the assignment repository..."

if [[ ! -e reference ]]; then
    git clone --depth 1 "$REPO" reference
elif [[ -d reference/.git ]]; then
    echo "Repository already exists; reusing it."
else
    echo "ERROR: reference exists but is not a Git repository."
    exit 1
fi

echo
echo "[2] Listing Lab 3 source files..."

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "ERROR: Lab 3/src directory was not found."
    exit 1
fi

find "$SOURCE_DIR" -maxdepth 1 -type f \
    -printf '%f (%s bytes)\n'

echo
echo "[3] Inspecting file types..."

find "$SOURCE_DIR" -maxdepth 1 -type f \
    -exec file {} \;

echo
echo "[4] Calculating SHA256 hashes..."

find "$SOURCE_DIR" -maxdepth 1 -type f \
    -exec sha256sum {} \;

echo
echo "[5] Checking tracing tools..."

command -v lttng
command -v perf
command -v babeltrace

echo
echo "Preparation completed."
echo "No supplied executable has been run."
