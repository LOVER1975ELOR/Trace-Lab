#!/usr/bin/env bash
set -euo pipefail

# Lab 5 - Create an isolated virtual network with MTU 1500.
# Keep the network for the following LTTng experiments.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

NS_TX="lab5_mtu_tx"
NS_RX="lab5_mtu_rx"

DEV_TX="l5veth_tx"
DEV_RX="l5veth_rx"

IP_TX="10.205.0.1"
IP_RX="10.205.0.2"

MTU=1500
OUT="logs/baseline"

mkdir -p "$OUT" notes

echo "=================================="
echo "Lab 5 - Virtual MTU Network Setup"
echo "=================================="

echo "Date: $(date -Is)"
echo "Kernel: $(uname -r)"
echo

sudo -v

# Do not modify an existing namespace or interface.
for ns in "$NS_TX" "$NS_RX"; do
    if sudo ip netns list | awk '{print $1}' \
        | grep -Fxq "$ns"; then
        echo "ERROR: Namespace $ns already exists."
        exit 1
    fi
done

for dev in "$DEV_TX" "$DEV_RX"; do
    if sudo ip link show "$dev" >/dev/null 2>&1; then
        echo "ERROR: Interface $dev already exists."
        exit 1
    fi
done

created_tx=0
created_rx=0
completed=0

cleanup() {
    status=$?
    trap - EXIT INT TERM

    if (( ! completed )); then
        echo "Setup incomplete: cleaning up lab resources."

        sudo ip link delete "$DEV_TX" \
            2>/dev/null || true

        sudo ip link delete "$DEV_RX" \
            2>/dev/null || true

        if (( created_rx )); then
            sudo ip netns delete "$NS_RX" || true
        fi

        if (( created_tx )); then
            sudo ip netns delete "$NS_TX" || true
        fi
    fi

    exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "[1] Creating network namespaces..."

sudo ip netns add "$NS_TX"
created_tx=1

sudo ip netns add "$NS_RX"
created_rx=1

echo
echo "[2] Creating the veth pair..."

sudo ip link add "$DEV_TX" \
    type veth peer name "$DEV_RX"

sudo ip link set "$DEV_TX" netns "$NS_TX"
sudo ip link set "$DEV_RX" netns "$NS_RX"

echo
echo "[3] Assigning IPv4 addresses..."

sudo ip -n "$NS_TX" addr add \
    "$IP_TX/30" dev "$DEV_TX"

sudo ip -n "$NS_RX" addr add \
    "$IP_RX/30" dev "$DEV_RX"

echo
echo "[4] Configuring MTU..."

sudo ip -n "$NS_TX" link set \
    dev "$DEV_TX" mtu "$MTU"

sudo ip -n "$NS_RX" link set \
    dev "$DEV_RX" mtu "$MTU"

echo
echo "[5] Enabling interfaces..."

sudo ip -n "$NS_TX" link set lo up
sudo ip -n "$NS_RX" link set lo up

sudo ip -n "$NS_TX" link set "$DEV_TX" up
sudo ip -n "$NS_RX" link set "$DEV_RX" up

echo
echo "[6] Verifying interface MTUs..."

echo "--- Transmitter ---"
sudo ip -n "$NS_TX" link show "$DEV_TX"

echo
echo "--- Receiver ---"
sudo ip -n "$NS_RX" link show "$DEV_RX"

echo
echo "[7] Testing connectivity with normal Ping..."

sudo ip netns exec "$NS_TX" \
    ping -n -c 2 -W 2 -s 56 "$IP_RX" \
    | tee "$OUT/02_normal_ping.txt"

echo
echo "[8] Active lab namespaces..."

sudo ip netns list | grep 'lab5_mtu'

completed=1

echo
echo "=================================="
echo "Virtual network is ready."
echo "MTU: $MTU bytes"
echo "Sender: $IP_TX"
echo "Receiver: $IP_RX"
echo "=================================="

echo "The namespaces remain active for later tests."
