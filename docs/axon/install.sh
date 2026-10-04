#!/bin/bash
# AeroTHON MAVLink Preflight Agent Installation Script
# Run as root on Vicharak Axon RK3588

set -euo pipefail

INSTALL_DIR="/opt/aerothon"
SERVICE_FILE="aerothon-preflight.service"
AGENT_FILE="mavlink_preflight_agent.py"
REQUIREMENTS_FILE="requirements.txt"

echo "=== AeroTHON MAVLink Preflight Agent Installer ==="

# Check root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Create install directory
mkdir -p "$INSTALL_DIR"

# Copy agent and requirements
cp "$AGENT_FILE" "$INSTALL_DIR/"
cp "$REQUIREMENTS_FILE" "$INSTALL_DIR/"

# Create virtual environment
python3 -m venv "$INSTALL_DIR/venv"
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/$REQUIREMENTS_FILE"

# Install systemd service
cp "$SERVICE_FILE" /etc/systemd/system/
systemctl daemon-reload
systemctl enable aerothon-preflight.service

echo "=== Installation complete ==="
echo "Agent installed to: $INSTALL_DIR"
echo "Service installed: aerothon-preflight.service"
echo ""
echo "To start:  systemctl start aerothon-preflight"
echo "To check:  systemctl status aerothon-preflight"
echo "To logs:   journalctl -u aerothon-preflight -f"