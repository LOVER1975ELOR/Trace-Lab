#!/usr/bin/env bash
set -euo pipefail

# Lab 5 - Remove only the experimental network namespaces.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

NS_TX="lab5_mtu_tx"
NS_RX="lab5_mtu_rx"

echo "=================================="
echo "Lab 5 - Network Cleanup"
echo "=================================="

sudo -v

echo "[1] Checking experimental namespaces..."

for ns in "$NS_TX" "$NS_RX"; do
    if ! sudo ip netns list | awk '{print $1}' \
        | grep -Fxq "$ns"; then
        echo "ERROR: Namespace $ns was not found."
        exit 1
    fi

    echo "[OK] $ns"
done

echo
echo "[2] Checking interface configuration..."

sudo ip -n "$NS_TX" link show l5veth_tx
sudo ip -n "$NS_RX" link show l5veth_rx

sudo ip -n "$NS_TX" -4 addr show dev l5veth_tx \
    | grep -Fq '10.205.0.1/30'

sudo ip -n "$NS_RX" -4 addr show dev l5veth_rx \
    | grep -Fq '10.205.0.2/30'

echo "Expected lab interfaces and addresses verified."

echo
echo "[3] Checking for processes in the namespaces..."

for ns in "$NS_TX" "$NS_RX"; do
    pids=$(sudo ip netns pids "$ns")

    if [[ -n "$pids" ]]; then
        echo "ERROR: Processes are still using $ns:"
        echo "$pids"
        exit 1
    fi
done

echo "No processes are using the lab namespaces."

echo
echo "[4] Removing experimental namespaces..."

sudo ip netns delete "$NS_TX"
sudo ip netns delete "$NS_RX"

echo
echo "[5] Verifying cleanup..."

if sudo ip netns list | grep -E 'lab5_mtu_(tx|rx)'; then
    echo "ERROR: Lab namespaces still exist."
    exit 1
fi

echo "Cleanup completed successfully."
echo "Saved traces, logs and screenshots were not modified."
