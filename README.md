# SystemAgent

SystemAgent is the small background service used by ClusterHub to detect and shut down a computer. It is a dependency-free Go binary and listens on TCP port `8732` by default.

## HTTP contract

- `GET /health` responds `200` with `{"status":"ok"}`.
- `POST /shutdown` responds `200` with `{"status":"shutting_down"}`, flushes the response, and initiates an OS shutdown.

The shutdown endpoint intentionally matches ClusterHub's unauthenticated contract. Do not expose port `8732` to the internet. Restrict it to a trusted LAN or, preferably, to the ClusterHub host with the operating system firewall. The Windows installer creates a Private-profile LAN rule; Linux and macOS firewall policy remains administrator-managed.

## Install

Run as Administrator on Windows:

```powershell
irm https://systemagent.pedrolemoz.dev/install | iex
```

Run as root on Linux or macOS:

```sh
curl -fsSL https://systemagent.pedrolemoz.dev/install | sudo sh
```

The infrastructure should serve [`scripts/install.ps1`](scripts/install.ps1) to Windows and [`scripts/install.sh`](scripts/install.sh) to Linux/macOS. The installers may be run again to update an existing installation.

Startup is independent of user login:

- Windows: boot-triggered scheduled task running as `SYSTEM`.
- Linux: enabled `systemd` system service running as root.
- macOS: system `LaunchDaemon` running as root.

Elevated service privileges are necessary because powering off the machine is a privileged operation.

## Uninstall

Run as Administrator on Windows:

```powershell
.\scripts\uninstall.ps1
```

Run as root on Linux or macOS:

```sh
sudo sh scripts/uninstall.sh
```

The uninstallers stop SystemAgent and remove its startup registration, installed binary, service definition, and associated firewall rule or log where applicable.

## Build on Ubuntu

Install Go 1.22 or newer, then run:

```sh
chmod +x scripts/build.sh
VERSION=v1.0.0 ./scripts/build.sh
```

The build uses `CGO_ENABLED=0`, so no cross compiler is required. Publish these primary artifacts as raw binary responses:

| Artifact | Public URL | Target |
| --- | --- | --- |
| `dist/systemagent.exe` | `/systemagent.exe` | Windows amd64 |
| `dist/systemagent-linux` | `/systemagent-linux` | Linux amd64 |
| `dist/systemagent-mac` | `/systemagent-mac` | macOS arm64 |

The script also emits Windows arm64, Linux arm64, and macOS amd64 artifacts plus `SHA256SUMS`. If an installed fleet needs both architectures per OS, route the OS URL using request metadata or publish architecture-specific URLs and adjust the installer. Code signing/notarization is an infrastructure/release concern, especially on Windows and macOS.

Remove all local build artifacts with:

```sh
sh scripts/clean.sh
```

## Development

```sh
go test ./...
go run ./cmd/systemagent
```

Override the listener when developing with `-listen`, for example `-listen 127.0.0.1:8732`.
