# DevForge Architecture

## Overview

DevForge is a macOS-native SwiftUI application using MV (Model-View) pattern with actor-isolated services and GRDB.swift for SQLite persistence.

## Module Structure

```
┌─────────────────────────────────────────────────────┐
│                    App Layer                         │
│  DevForgeApp.swift ← ContentView.swift ← Navigation │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                   Features                           │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐      │
│  │Proc  │ │ Env  │ │Docker│ │ Git  │ │ SSH  │      │
│  │Manager│ │Vault │ │Console│ │Worksp.│ │Manager│      │
│  └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘      │
│  ┌──────┐ ┌──────┐ ┌──────────┐ ┌──────────┐        │
│  │Task  │ │ Log  │ │ System   │ │ Shared   │        │
│  │Runner│ │Aggreg.│ │ Health   │ │Components│        │
│  └──┬───┘ └──┬───┘ └──┬───┘   └──────────┘        │
└──────┼────────┼────────┼────────────────────────────┘
       │        │        │
┌──────▼────────▼────────▼────────────────────────────┐
│                   Services                           │
│  ProcessService │ DockerSocketService │ GitService   │
│  EnvVaultService │ SSHConfigParser │ TaskRunnerSvc   │
│  FileWatcherService │ SystemMetricsService          │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                    Core Layer                        │
│  AppDatabase (GRDB) │ KeychainService │ AppError    │
│  Preferences │ Extensions │ AppTheme                │
└─────────────────────────────────────────────────────┘
```

## Data Flow

```
User Action → View (SwiftUI)
    ↓
ViewModel (@Observable class)
    ↓ async/await
Service (actor)
    ↓
Database (GRDB) / OS APIs (libproc, IOKit, FSEvents)
    ↓
ViewModel state update
    ↓
View re-renders
```

## Technology Choices

| Component | Choice | Rationale |
|-----------|--------|-----------|
| UI Framework | SwiftUI | Native macOS, modern, declarative |
| Persistence | GRDB.swift v6 | Type-safe SQLite, async-native |
| Secrets | Keychain (Security.framework) | OS-level encryption |
| Git | git binary (Process) | Reliable, avoids libgit2 complexity |
| Docker | HTTP over Unix socket | Direct API, no Docker Desktop dependency |
| SSH config | Custom parser | No good Swift library exists |
| Process mgmt | Foundation.Process | Simple, reliable |
| System metrics | Mach/IOKit APIs | Direct access, no third-party |
