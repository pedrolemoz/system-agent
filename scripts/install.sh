#!/usr/bin/env bash
set -e

export PATH="$PATH:/usr/local/go/bin:/usr/local/bin:/usr/bin"
[ -f /etc/profile ] && source /etc/profile
[ -f "$HOME/.profile" ] && source "$HOME/.profile"
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root (e.g. sudo -E bash install.sh)"
  exit 1
fi

echo "Checking dependencies..."
MISSING=""
command -v git >/dev/null 2>&1 || MISSING="$MISSING git"
command -v go  >/dev/null 2>&1 || MISSING="$MISSING golang"

if [ -n "$MISSING" ]; then
  echo ""
  echo "ERROR: Missing required dependencies:$MISSING"
  echo "Please install them and try again. This script will not download them automatically."
  exit 1
fi

REAL_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
INSTALL_DIR="$REAL_HOME/system-agent"
SVC_FILE="/etc/systemd/system/system-agent.service"

if [ -d "$INSTALL_DIR" ]; then
  echo "Removing existing installation at $INSTALL_DIR..."
  systemctl stop system-agent 2>/dev/null || true
  rm -rf "$INSTALL_DIR"
fi

echo "Cloning project to $INSTALL_DIR..."
git clone https://github.com/pedrolemoz/system-agent.git "$INSTALL_DIR"

echo "Building..."
cd "$INSTALL_DIR"
go mod tidy
go build -trimpath -ldflags="-s -w" -o system-agent ./cmd/agent

echo "Fixing ownership..."
chown -R "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$INSTALL_DIR"

echo "Creating systemd service..."
cat > "$SVC_FILE" <<EOF
[Unit]
Description=System Agent
After=network.target

[Service]
Type=simple
User=${SUDO_USER:-$USER}
ExecStart=$INSTALL_DIR/system-agent
WorkingDirectory=$INSTALL_DIR
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Enabling and starting service..."
systemctl daemon-reload
systemctl enable system-agent
systemctl start system-agent

echo ""
echo "Installation complete! system-agent will run automatically on startup."
echo "Available at: http://localhost:8732"
echo ""
echo "To check logs, run:"
echo "  sudo journalctl -u system-agent -f"
