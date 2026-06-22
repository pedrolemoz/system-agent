#!/usr/bin/env sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "SystemAgent must be uninstalled as root (try: sudo sh)." >&2
  exit 1
fi

case "$(uname -s)" in
  Linux)
    if command -v systemctl >/dev/null 2>&1; then
      systemctl disable --now systemagent.service 2>/dev/null || true
    fi
    rm -f /etc/systemd/system/systemagent.service
    if command -v systemctl >/dev/null 2>&1; then
      systemctl daemon-reload
      systemctl reset-failed systemagent.service 2>/dev/null || true
    fi
    ;;
  Darwin)
    plist='/Library/LaunchDaemons/dev.pedrolemoz.systemagent.plist'
    if [ -f "$plist" ]; then
      launchctl bootout system "$plist" 2>/dev/null || true
    fi
    rm -f "$plist" /var/log/systemagent.log
    ;;
  *)
    echo "Unsupported operating system: $(uname -s)" >&2
    exit 1
    ;;
esac

pkill -x systemagent 2>/dev/null || true
rm -f /usr/local/bin/systemagent
echo 'SystemAgent has been completely removed.'
