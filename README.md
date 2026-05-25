# 🛠 DevForge — macOS DevOps Suite

**Local DevOps. Zero Cloud. Full Control.**

[![macOS](https://img.shields.io/badge/macOS-14%2B-blue)](https://developer.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/Arch-arm64-green)]()
[![License](https://img.shields.io/badge/License-Apache%202.0-red)](LICENSE)

DevForge unifies tools developers run across 10+ terminal tabs into one native, offline, GPU-accelerated SwiftUI app.

## Features

### Pillar 1 — Process Manager
Start, stop, restart, and monitor local processes with live log tailing and ANSI color rendering.

### Pillar 2 — Environment & Secrets Vault
Manage `.env` files per project. Secret values stored in macOS Keychain.

### Pillar 3 — Docker Console
Talk to local Docker daemon via Unix socket. Manage containers, images, and compose projects.

### Pillar 4 — Git Workspace Manager
Multi-repo dashboard with stage, commit, push, pull, branch switching, and diff viewer.

### Pillar 5 — SSH & Host Manager
Parse `~/.ssh/config`, test connectivity, launch terminal sessions, manage port forwards.

### Pillar 6 — Task Runner
Discover and run tasks from Makefile, package.json, and Justfile. Schedule via launchd.

### Pillar 7 — Log Aggregator
Tail any file with regex filtering, severity auto-detection, and session export.

### Pillar 8 — System Health Dashboard
Real-time CPU, memory, disk I/O, network throughput, and thermal state monitoring.

## Requirements

- macOS 14.0+ (Sonoma or later)
- Apple Silicon (M1 or later)
- Docker (optional — for Docker Console)
- Git (optional — for Git Workspace Manager)

## Installation

### Download
Download the latest DMG from [GitHub Releases](https://github.com/yourname/DevForge/releases).

### Build from Source
```bash
git clone https://github.com/yourname/DevForge.git
cd DevForge
open DevForge.xcodeproj
# Build with Xcode (Product → Build)
```

## Quick Start

1. Open DevForge
2. Go to **Process Manager** → click **+** → enter name and command
3. Click **Start** to launch the process
4. Watch live logs in the detail panel
5. Use **Env Vault** to manage project environment variables

## Architecture

DevForge uses MV (Model-View) with Swift 5.10 `@Observable` classes, actor-isolated services, and GRDB.swift for persistence. All data is stored locally — no network calls, no telemetry, no analytics.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Apache 2.0. See [LICENSE](LICENSE) for details.
