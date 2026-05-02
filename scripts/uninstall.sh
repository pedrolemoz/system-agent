#!/bin/sh
set -e

INSTALL_DIR="/opt/system-agent"
SVC_FILE="/etc/systemd/system/system-agent.service"

echo "Uninstalling system-agent..."

if systemctl is-active --quiet system-agent 2>/dev/null; then
    systemctl stop system-agent
fi

if systemctl is-enabled --quiet system-agent 2>/dev/null; then
    systemctl disable system-agent
fi

rm -f "$SVC_FILE"
systemctl daemon-reload

rm -rf "$INSTALL_DIR"

echo "Done. system-agent removed."
