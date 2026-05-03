#!/usr/bin/env bash
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root (e.g. sudo bash uninstall.sh)"
  exit 1
fi

REAL_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
INSTALL_DIR="$REAL_HOME/system-agent"
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

if [ -d "$INSTALL_DIR" ]; then
  echo "Removing $INSTALL_DIR..."
  rm -rf "$INSTALL_DIR"
fi

echo "Done. system-agent removed."
