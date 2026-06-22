#!/usr/bin/env sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "SystemAgent must be installed as root (try: sudo sh)." >&2
  exit 1
fi

case "$(uname -s)" in
  Linux) download_url='https://systemagent.pedrolemoz.dev/linux' ;;
  Darwin) download_url='https://systemagent.pedrolemoz.dev/mac' ;;
  *) echo "Unsupported operating system: $(uname -s)" >&2; exit 1 ;;
esac

download() {
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --proto '=https' --tlsv1.2 "$download_url" --output "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget --https-only "$download_url" -O "$1"
  else
    echo 'curl or wget is required.' >&2
    exit 1
  fi
}

temporary="$(mktemp)"
trap 'rm -f "$temporary"' EXIT
download "$temporary"
mkdir -p /usr/local/bin
install -m 0755 "$temporary" /usr/local/bin/systemagent

if [ "$(uname -s)" = 'Linux' ]; then
  cat >/etc/systemd/system/systemagent.service <<'EOF'
[Unit]
Description=ClusterHub SystemAgent
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/systemagent
Restart=on-failure
RestartSec=5
User=root
NoNewPrivileges=true
ProtectHome=true
ProtectSystem=strict
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now systemagent.service
else
  cat >/Library/LaunchDaemons/dev.pedrolemoz.systemagent.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>dev.pedrolemoz.systemagent</string>
  <key>ProgramArguments</key>
  <array><string>/usr/local/bin/systemagent</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/var/log/systemagent.log</string>
  <key>StandardErrorPath</key><string>/var/log/systemagent.log</string>
</dict>
</plist>
EOF
  chown root:wheel /Library/LaunchDaemons/dev.pedrolemoz.systemagent.plist
  chmod 0644 /Library/LaunchDaemons/dev.pedrolemoz.systemagent.plist
  launchctl bootout system /Library/LaunchDaemons/dev.pedrolemoz.systemagent.plist 2>/dev/null || true
  launchctl bootstrap system /Library/LaunchDaemons/dev.pedrolemoz.systemagent.plist
fi

echo 'SystemAgent installed and running on TCP port 8732.'
