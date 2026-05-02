#!/bin/sh
set -e

INSTALL_DIR="/opt/system-agent"
BIN_URL="https://domain.com/releases/system-agent-linux-amd64"
BIN_PATH="$INSTALL_DIR/system-agent"
SVC_FILE="/etc/systemd/system/system-agent.service"

echo "Installing system-agent..."

mkdir -p "$INSTALL_DIR"

echo "Downloading binary..."
curl -fsSL "$BIN_URL" -o "$BIN_PATH"
chmod +x "$BIN_PATH"

echo "Creating systemd service..."
cat > "$SVC_FILE" <<EOF
[Unit]
Description=System Agent
After=network.target

[Service]
Type=simple
ExecStart=$BIN_PATH
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

echo "Done. system-agent running on http://127.0.0.1:8732"
