# 🛠️ macOS DevOps Suite — Vibecoding Blueprint
> **Feed this entire file to your AI coding agent to begin implementation.**  
> Stack: Swift 5.10 + SwiftUI · macOS 14+ · OpenCode AI · Git · GitHub Spec-Kit  
> Model: Solo developer · MacBook Air M1 8GB · Offline-first · FOSS

---

## 0. HOW TO USE THIS BLUEPRINT

This document is the **single source of truth** for the entire project lifecycle. It is structured to be fed into OpenCode AI (or any agentic coding tool) phase by phase. Each phase contains:

- A **SPEC block** — the authoritative requirement
- An **IMPL block** — exact instructions for the AI agent
- An **ANTI-HALLUCINATION block** — guard rails and verification steps

**Workflow rule:** Complete one phase fully before starting the next. Never skip phases. After each AI session, run the verification checklist before committing.

---

## 1. PROJECT CHARTER

### 1.1 App Identity

| Field | Value |
|---|---|
| **Name** | DevForge |
| **Tagline** | Local DevOps. Zero Cloud. Full Control. |
| **Platform** | macOS 14.0+ (Sonoma and later) |
| **Architecture** | Apple Silicon native (arm64); no Intel slice required |
| **Language** | Swift 5.10, SwiftUI |
| **License** | Apache 2.0 |
| **Distribution** | GitHub Releases (notarized DMG), future Mac App Store |
| **Connectivity** | 100% offline — no network calls, no telemetry, no analytics |
| **Storage** | Local SQLite via GRDB.swift + UserDefaults + Keychain |
| **Target Users** | Solo devs, small teams, enterprise DevOps engineers |

### 1.2 App Scope — Feature Pillars

DevForge is a **local DevOps command center** for macOS. It unifies tools developers run across 10+ terminal tabs into one native, offline, GPU-accelerated SwiftUI app.

#### Pillar 1 — Process Manager
- Start, stop, restart, and monitor local processes (servers, daemons, watchers)
- Live stdout/stderr log tailing with ANSI color rendering
- Process templates (saved commands with env vars)
- CPU/memory sparklines per process (via libproc)

#### Pillar 2 — Environment & Secrets Vault
- Manage `.env` files per project without exposing secrets in plaintext
- Keychain-backed encryption for sensitive values
- Export to shell, Docker, dotenv formats
- Diff environments side by side

#### Pillar 3 — Docker / Container Console
- Talk to local Docker socket (`/var/run/docker.sock`)
- List, start, stop, remove containers and images
- Real-time container log streaming
- `docker compose` file parser and launcher UI
- No Docker Desktop dependency — direct API calls

#### Pillar 4 — Git Workspace Manager
- Multi-repo dashboard: branch, status, last commit
- Stage, commit, push, pull in-app (libgit2 via SwiftGit2)
- Stash manager, branch switcher, tag browser
- Diff viewer with syntax highlighting

#### Pillar 5 — SSH & Host Manager
- Manage SSH configs (`~/.ssh/config`)
- Launch terminal sessions (hand off to Terminal.app or iTerm2)
- Port-forward rules manager
- Host health ping (TCP reachability — no ICMP needed)

#### Pillar 6 — Task Runner
- Read `Makefile`, `package.json scripts`, `Justfile`
- Run tasks with live output, history, and exit-code tracking
- Schedule tasks (launchd plist generator)

#### Pillar 7 — Log Aggregator
- Tail any file or `/var/log` entry
- Filter, search, highlight with regex
- Session recording and export

#### Pillar 8 — System Health Dashboard
- CPU, memory, disk I/O, network throughput (via IOKit + sysctl)
- GPU utilization (Metal Performance HUD data)
- Thermal state and fan speed (via SMC)

---

## 2. REPOSITORY SETUP

### 2.1 GitHub Repository

```bash
# Run once on your machine
gh repo create DevForge \
  --public \
  --description "Local, offline, enterprise-grade DevOps suite for macOS" \
  --license apache-2.0 \
  --gitignore Swift \
  --clone

cd DevForge
```

### 2.2 Branch Strategy

```
main          ← production-ready, protected, tagged releases
develop       ← integration branch, all features merge here
feat/*        ← feature branches (one per pillar or sub-feature)
fix/*         ← bug fix branches
chore/*       ← tooling, CI, docs changes
release/*     ← release prep branches
```

**Rule:** No direct commits to `main` or `develop`. All work via PRs, even solo.

```bash
git checkout -b develop
git push -u origin develop

# Set develop as default branch in GitHub settings
gh repo edit --default-branch develop
```

### 2.3 Branch Protection Rules

```bash
# Via GitHub CLI
gh api repos/:owner/DevForge/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":[]}' \
  --field enforce_admins=false \
  --field required_pull_request_reviews='{"required_approving_review_count":0}' \
  --field restrictions=null
```

### 2.4 `.gitignore` additions (append to generated one)

```gitignore
# Xcode
*.xcuserstate
xcuserdata/
*.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
DerivedData/
.build/

# Secrets
.env
*.p12
*.mobileprovision

# OS
.DS_Store
```

### 2.5 Git Commit Convention (Conventional Commits)

```
feat(docker): add container log streaming
fix(process): handle SIGTERM on managed processes
docs(readme): update installation steps
chore(deps): bump GRDB to 6.29.0
test(vault): add Keychain round-trip tests
refactor(ui): extract ProcessRowView into component
```

**Rule:** Every commit must pass `git diff --check` (no trailing whitespace) and `swiftlint` before commit (enforced via pre-commit hook).

### 2.6 Pre-commit Hook

```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
set -e
echo "→ SwiftLint..."
swiftlint lint --strict --quiet
echo "→ Build check..."
xcodebuild -scheme DevForge -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO > /dev/null 2>&1
echo "✓ Pre-commit passed"
EOF
chmod +x .git/hooks/pre-commit
```

---

## 3. GITHUB SPEC-KIT SETUP

GitHub Spec-Kit is a specification-driven development workflow using GitHub Issues as living specs, Projects for tracking, and Discussions for architectural decisions.

### 3.1 Install GitHub CLI Extensions

```bash
# Ensure gh CLI is installed
brew install gh

# Authenticate
gh auth login

# Install spec helper (issue templates + labels)
gh extension install nicowillis/gh-spec 2>/dev/null || true
```

### 3.2 Issue Labels

```bash
# Create spec labels
gh label create "spec:pillar" --color "0075ca" --description "Feature pillar spec"
gh label create "spec:story" --color "cfd3d7" --description "User story"
gh label create "spec:task" --color "e4e669" --description "Implementation task"
gh label create "spec:bug" --color "d73a4a" --description "Bug report"
gh label create "spec:adr" --color "7057ff" --description "Architecture Decision Record"
gh label create "spec:done" --color "0e8a16" --description "Spec implemented and verified"
gh label create "ai:hallucination" --color "ff6b6b" --description "AI-generated incorrect code detected"
gh label create "ai:verified" --color "00b4d8" --description "AI output human-verified"
```

### 3.3 Issue Templates

Create `.github/ISSUE_TEMPLATE/spec.yml`:

```yaml
name: Feature Spec
description: Define a feature spec for DevForge
labels: ["spec:story"]
body:
  - type: textarea
    id: goal
    attributes:
      label: Goal
      description: What does this feature accomplish?
    validations:
      required: true
  - type: textarea
    id: acceptance
    attributes:
      label: Acceptance Criteria
      description: Bullet list of verifiable conditions
    validations:
      required: true
  - type: textarea
    id: edge_cases
    attributes:
      label: Edge Cases & Constraints
  - type: textarea
    id: ai_prompt_hint
    attributes:
      label: AI Prompt Hint
      description: Suggested prompt fragment for OpenCode AI
```

### 3.4 GitHub Project Board

```bash
# Create project
gh project create --owner "@me" --title "DevForge Roadmap" --format board

# Columns: Spec · In Progress · AI Review · Human Verified · Done
```

**Workflow rule:** Every feature MUST have a GitHub Issue (spec) before any code is written. No spec = no code.

### 3.5 Architecture Decision Records (ADRs)

Create `docs/adr/` directory. Template:

```markdown
# ADR-001: Use GRDB.swift for local persistence

**Status:** Accepted  
**Date:** YYYY-MM-DD

## Context
Need offline SQLite persistence with type-safe queries in Swift.

## Decision
Use GRDB.swift v6. Reasons: Swift concurrency native, no ORM overhead, battle-tested.

## Consequences
- Positive: Fast, type-safe, offline-first
- Negative: Manual migration scripts required
- Neutral: Team must learn GRDB API
```

Create an ADR for every significant technical decision.

---

## 4. XCODE PROJECT SETUP

### 4.1 Create Project

```bash
# Inside DevForge repo root
# Open Xcode → File → New → Project
# Choose: macOS → App
# Product Name: DevForge
# Bundle ID: com.yourname.devforge
# Interface: SwiftUI
# Language: Swift
# Storage: None (we manage manually)
# Uncheck: Include Tests (add manually)
# Save to: DevForge/ (repo root)
```

### 4.2 Xcode Project Settings

| Setting | Value |
|---|---|
| Deployment Target | macOS 14.0 |
| Architectures | Apple Silicon (arm64) |
| Swift Version | 5.10 |
| Enable Hardened Runtime | YES |
| App Sandbox | YES |
| Code Signing | Development (local); Distribution (release) |

### 4.3 Entitlements (`DevForge.entitlements`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <false/>
    <key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
    <array>
        <string>/var/run/docker.sock</string>
        <string>/usr/local/bin/</string>
        <string>/opt/homebrew/bin/</string>
    </array>
    <key>com.apple.security.process-info</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.yourname.devforge</string>
    </array>
</dict>
</plist>
```

### 4.4 Swift Package Dependencies (`Package.swift` or via Xcode SPM)

```swift
// In Xcode: File → Add Package Dependencies
// Add each URL below

let packages = [
    // Persistence
    "https://github.com/groue/GRDB.swift",           // v6.x — SQLite ORM
    
    // Git integration  
    "https://github.com/SwiftGit2/SwiftGit2",         // libgit2 wrapper
    
    // Syntax highlighting
    "https://github.com/raspu/Highlightr",             // log/diff highlighting
    
    // Keychain
    "https://github.com/evgenyneu/keychain-swift",     // Keychain wrapper
    
    // SSH config parsing
    // (write custom parser — no good Swift lib exists)
    
    // Docker socket (HTTP over Unix socket)
    // Use URLSession with custom URLProtocol — no external dep
    
    // Testing
    "https://github.com/Quick/Nimble",                 // expressive assertions
]
```

---

## 5. ARCHITECTURE

### 5.1 Folder Structure

```
DevForge/
├── App/
│   ├── DevForgeApp.swift          # @main entry point
│   ├── AppDelegate.swift          # NSApplicationDelegate
│   └── ContentView.swift          # Root navigation
│
├── Core/
│   ├── Database/
│   │   ├── AppDatabase.swift      # GRDB setup, migrations
│   │   └── Migrations/            # Numbered migration files
│   ├── Keychain/
│   │   └── KeychainService.swift
│   ├── Preferences/
│   │   └── AppPreferences.swift   # UserDefaults @AppStorage wrappers
│   └── Extensions/                # Swift stdlib extensions
│
├── Features/
│   ├── ProcessManager/
│   │   ├── ProcessManagerView.swift
│   │   ├── ProcessManagerViewModel.swift
│   │   ├── Models/ProcessRecord.swift
│   │   └── Services/ProcessService.swift
│   ├── EnvVault/
│   ├── DockerConsole/
│   ├── GitWorkspace/
│   ├── SSHManager/
│   ├── TaskRunner/
│   ├── LogAggregator/
│   └── SystemHealth/
│
├── Shared/
│   ├── Components/               # Reusable SwiftUI views
│   ├── Styles/                   # ButtonStyle, TextFieldStyle
│   └── Theme/                    # Colors, fonts, spacing tokens
│
├── Services/
│   ├── DockerSocketService.swift  # HTTP over Unix socket
│   ├── ShellService.swift         # Process spawning
│   └── FileWatcherService.swift   # FSEvents watcher
│
└── Tests/
    ├── UnitTests/
    └── IntegrationTests/
```

### 5.2 Architecture Pattern: MV (Model-View) with ObservableObject

**Use:** `@Observable` (Swift 5.9+) + `@Environment` + actor-isolated services  
**Avoid:** MVVM ceremony, Combine chains where async/await suffices  
**Rule:** ViewModels are `@Observable` classes. Services are `actor`s. Models are `struct`s conforming to `Identifiable`, `Codable`, `FetchableRecord`, `PersistableRecord`.

```swift
// Example pattern
@Observable
final class ProcessManagerViewModel {
    var processes: [ProcessRecord] = []
    var error: AppError?
    
    private let service: ProcessService
    
    init(service: ProcessService = .shared) {
        self.service = service
    }
    
    func loadProcesses() async {
        do {
            processes = try await service.fetchAll()
        } catch {
            self.error = AppError(underlying: error)
        }
    }
}
```

### 5.3 Data Flow

```
View → ViewModel (async func call)
     ← ViewModel (@Observable state update)

ViewModel → Service (actor, async/await)
          → Database (GRDB, async queue)
          → OS APIs (libproc, IOKit, FSEvents)
```

### 5.4 Error Handling Strategy

```swift
// Single app-wide error type
enum AppError: LocalizedError {
    case database(Error)
    case process(String)
    case docker(DockerError)
    case permission(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .database(let e): return "Database error: \(e.localizedDescription)"
        // ...
        }
    }
}
```

---

## 6. DEVELOPMENT PHASES

Each phase maps to a GitHub milestone. Complete all acceptance criteria before closing the milestone.

---

### PHASE 0 — Foundation (Week 1)

**Goal:** Skeleton compiles, runs, navigates. DB initialized. Theme applied.

**GitHub Milestone:** `v0.1.0-foundation`

**Specs to create as GitHub Issues:**
1. `[SPEC] App shell: sidebar navigation with 8 feature sections`
2. `[SPEC] Database initialization with GRDB and first migration`
3. `[SPEC] Theme system: colors, typography, spacing tokens`
4. `[SPEC] Error presentation: AppError + in-app alert/banner system`

#### IMPL — OpenCode AI Prompt (Phase 0)

```
CONTEXT: I am building DevForge, a macOS 14+ SwiftUI app. 
Xcode project already created. SPM packages added: GRDB.swift, keychain-swift, Highlightr.

TASK: Implement Phase 0 foundation.

FILE TARGETS:
1. App/DevForgeApp.swift — @main, WindowGroup, inject AppDatabase as @Environment
2. App/ContentView.swift — NavigationSplitView with sidebar (8 items: Process Manager, Env Vault, Docker Console, Git Workspace, SSH Manager, Task Runner, Log Aggregator, System Health). Use SF Symbols. Detail pane shows placeholder text for each.
3. Core/Database/AppDatabase.swift — GRDB DatabasePool setup at Application Support path. Run migrations synchronously on launch. Expose as singleton and as @Observable for injection.
4. Shared/Theme/AppTheme.swift — Define Color extensions, Font extensions, Spacing enum. Use macOS system colors where appropriate (NSColor bridged). Support light/dark automatically.
5. Core/Extensions/ — Add String, Date, Int convenience extensions as needed.

CONSTRAINTS:
- macOS 14+ only. No iOS compatibility shims.
- Swift strict concurrency: all actor-isolated where state is mutated.
- No third-party UI frameworks. Pure SwiftUI only.
- App must compile without warnings.
- Do not generate placeholder lorem ipsum content.

OUTPUT FORMAT: Provide each file as a complete Swift file with full implementation, not stubs. Include // MARK: sections.
```

#### ANTI-HALLUCINATION — Phase 0

After AI output, verify:
- [ ] `DatabasePool` path uses `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` — NOT a hardcoded path
- [ ] No `@UIApplicationDelegate` — must be `NSApplicationDelegate`
- [ ] No `UIColor` — must be `NSColor` or SwiftUI `Color`
- [ ] `NavigationSplitView` used, not `NavigationView` (deprecated macOS 14)
- [ ] GRDB import compiles (run `xcodebuild` before committing)
- [ ] No `DispatchQueue.main.async` wrapping `@Observable` updates — use `@MainActor`
- [ ] Check AI didn't invent non-existent GRDB APIs. Verify against: https://github.com/groue/GRDB.swift/blob/master/README.md

```bash
# Verification build command
xcodebuild -scheme DevForge \
  -destination 'platform=macOS,arch=arm64' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | grep -E "(error:|warning:)" | head -40
```

---

### PHASE 1 — Process Manager (Week 2)

**Goal:** User can create, start, stop, and view logs of managed processes.

**GitHub Milestone:** `v0.2.0-process-manager`

**Specs:**
1. `[SPEC] ProcessRecord model: id, name, command, workingDir, envVars, pid, status, createdAt`
2. `[SPEC] ProcessService: spawn process, capture stdout/stderr, track PID`
3. `[SPEC] ProcessManagerView: table of processes with status indicator and action buttons`
4. `[SPEC] LogTailView: live-updating text view with ANSI stripping/coloring`

#### IMPL — OpenCode AI Prompt (Phase 1)

```
CONTEXT: DevForge macOS app. Phase 0 complete (app shell, DB, theme exist).

TASK: Implement the Process Manager feature pillar.

MODELS (Features/ProcessManager/Models/ProcessRecord.swift):
- ProcessRecord: struct, Identifiable, Codable, GRDB FetchableRecord + PersistableRecord
- Fields: id (UUID), name (String), command (String), workingDirectory (String), 
  environmentVariables ([String:String]), pid (Int32?), status (ProcessStatus), 
  createdAt (Date), lastStartedAt (Date?)
- ProcessStatus: enum (idle, running, stopped, failed, crashed)
- ProcessTemplate: saved command configs (separate model)

SERVICE (Features/ProcessManager/Services/ProcessService.swift):
- Actor class ProcessService
- Uses Foundation.Process (not posix directly)
- spawn(record:) → starts Process, captures stdout+stderr via Pipe, stores PID
- terminate(pid:) → kills process gracefully (SIGTERM then SIGKILL after 5s)
- observe(pid:) → AsyncStream<LogLine> of live output
- Persist process state to GRDB on every status change
- Handle process termination callbacks via NotificationCenter (Process.didTerminateNotification)

VIEW (Features/ProcessManager/ProcessManagerView.swift):
- Split view: left = list of ProcessRecords (Table component with sortable columns)
- Right = detail: command info + action bar (Start/Stop/Restart/Delete) + live log tail
- Status shown as colored dot (green=running, grey=idle, red=failed)
- "New Process" sheet with form: name, command, working dir (file picker), env vars (key-value list)

LOG TAIL (Shared/Components/LogTailView.swift):
- ScrollView + LazyVStack of log lines
- Auto-scrolls to bottom when new lines arrive
- Regex-based ANSI escape stripping
- Syntax color: errors in red, warnings in yellow, timestamps in grey

CONSTRAINTS:
- Process must be launched with inherited environment + custom env vars merged
- stdout/stderr must stream in real time, not buffered until completion
- App must not crash if process exits unexpectedly
- No shell injection: command must be split into executable + arguments array, not passed to /bin/sh -c unless user explicitly opts in
- All database writes on background actor queue

OUTPUT: Complete implementation for all files above.
```

#### ANTI-HALLUCINATION — Phase 1

- [ ] Verify `Foundation.Process` API: `executableURL`, `arguments`, `environment`, `standardOutput`, `standardError` — not deprecated `launchPath`
- [ ] `Pipe` reading must be on background thread — check AI didn't put pipe reads on main thread
- [ ] `Process.didTerminateNotification` is real — verify this notification name compiles
- [ ] `AsyncStream<LogLine>` continuation must call `.finish()` on process termination
- [ ] No shell injection: command should NOT be `/bin/sh -c "userInput"` by default
- [ ] GRDB write confirmed on background: `try await db.write { ... }` not on `@MainActor`
- [ ] Test: launch `sleep 5`, verify status shows "running", kill it, verify "stopped"
- [ ] Test: launch invalid command, verify "failed" status and error shown in UI

---

### PHASE 2 — Environment & Secrets Vault (Week 3)

**GitHub Milestone:** `v0.3.0-env-vault`

#### IMPL — OpenCode AI Prompt (Phase 2)

```
CONTEXT: DevForge. Phases 0-1 complete.

TASK: Implement Env Vault feature.

REQUIREMENTS:
- EnvFile model: id, name, projectPath, variables ([EnvVariable]), createdAt
- EnvVariable model: key (String), value (String), isSecret (Bool), description (String)
- Secret values (isSecret=true) stored ONLY in Keychain via keychainswift, never in GRDB
- Non-secret values stored in GRDB
- EnvVaultService (actor): CRUD for env files, Keychain read/write for secrets
- EnvVaultView: sidebar list of env files, detail shows variable table
  - Variable rows: key | value (masked if secret, reveal on click) | secret toggle | delete
  - Add variable: inline row editing
  - Import: parse existing .env file from disk (file picker)
  - Export: write to .env format (file save panel), Docker --env-file format, shell export format
- EnvDiffView: compare two EnvFiles side by side (added/removed/changed keys highlighted)

SECURITY RULES for AI to follow:
- NEVER log secret values (no print/Logger calls with secret content)
- NEVER store secrets in UserDefaults, GRDB, or any file
- Keychain service name: "com.yourname.devforge.secrets"
- Keychain key format: "envfile.\(envFileID).\(variableKey)"
- On EnvFile delete: delete all associated Keychain entries first

PARSING RULE: .env parser must handle:
- Comments (# lines)
- Quoted values ("value with spaces", 'single quoted')
- Multiline values (VALUE="line1\nline2")
- Variable references ($OTHER_VAR) — expand if present in same file

OUTPUT: Complete implementation.
```

#### ANTI-HALLUCINATION — Phase 2

- [ ] Confirm `keychainswift` API: `keychain.set(value, forKey:)` / `keychain.get(key)` — do not invent methods
- [ ] Verify no secret value appears in any `print()`, `Logger`, or UI label without masking
- [ ] `.env` parser handles edge cases: test with `KEY="value with spaces"` and `KEY=` (empty value)
- [ ] Keychain deletion on EnvFile delete: manually verify in Keychain Access app after testing
- [ ] Export function: verify file is written to user-chosen location, not app sandbox temp

---

### PHASE 3 — Docker Console (Week 4)

**GitHub Milestone:** `v0.4.0-docker-console`

#### IMPL — OpenCode AI Prompt (Phase 3)

```
CONTEXT: DevForge. Phases 0-2 complete.

TASK: Implement Docker Console. Communicate with local Docker via Unix domain socket at /var/run/docker.sock using HTTP/1.1.

DOCKER SOCKET SERVICE (Services/DockerSocketService.swift):
- Actor DockerSocketService
- Implement HTTP over Unix socket using URLSession with a custom URLProtocol subclass
  OR use a raw POSIX socket (socket/connect/write/read) for simplicity
- Docker API version: v1.43
- Methods needed:
  - listContainers() async throws -> [DockerContainer]
  - listImages() async throws -> [DockerImage]  
  - startContainer(id:) async throws
  - stopContainer(id:) async throws
  - removeContainer(id:force:) async throws
  - containerLogs(id:) async throws -> AsyncStream<String>
  - inspectContainer(id:) async throws -> DockerContainerDetail

DOCKER MODELS:
- DockerContainer: id, names, image, status, state, ports, created
- DockerImage: id, repoTags, size, created
- All decoded from Docker API JSON responses

DOCKER COMPOSE (Services/DockerComposeService.swift):
- Parse docker-compose.yml using a YAML parser (write a minimal YAML parser for compose files,
  or use a simple line-by-line parser for services/image/ports/volumes/environment sections)
- DockerComposeService: run "docker compose up/down/ps" as shell Process, capture output
- Find docker compose binary at /usr/local/bin/docker or /opt/homebrew/bin/docker

DOCKER CONSOLE VIEW:
- Tab bar: Containers | Images | Compose
- Containers tab: Table with name, image, status, ports. Actions: start/stop/remove/logs
- Container detail sheet: inspect JSON prettified + resource usage if running
- Images tab: Table with repo:tag, size, created. Actions: remove
- Compose tab: file picker to open docker-compose.yml, show parsed services, Up/Down buttons

CONSTRAINTS:
- App Sandbox entitlement for /var/run/docker.sock required (already in entitlements from Phase 0)
- If Docker not running: show friendly "Docker not detected" empty state, not a crash
- JSON decoding: use CodingKeys to handle Docker API's capitalized JSON keys

OUTPUT: Complete implementation.
```

#### ANTI-HALLUCINATION — Phase 3

- [ ] Docker API v1.43 JSON response shapes — AI may hallucinate field names. Verify against official Docker API docs: https://docs.docker.com/engine/api/v1.43/
- [ ] Unix socket HTTP: verify the URLProtocol approach actually compiles and connects — build and test against running Docker
- [ ] `AsyncStream` for container logs: verify stream terminates properly when container stops
- [ ] YAML parser: test with multi-level indented compose files, not just simple ones
- [ ] "Docker not found" path: test by stopping Docker Desktop before launching the feature

```bash
# Quick socket test (run in Terminal to verify socket exists)
curl --unix-socket /var/run/docker.sock http://localhost/version
```

---

### PHASE 4 — Git Workspace Manager (Week 5)

**GitHub Milestone:** `v0.5.0-git-workspace`

#### IMPL — OpenCode AI Prompt (Phase 4)

```
CONTEXT: DevForge. Phases 0-3 complete.

TASK: Implement Git Workspace Manager using SwiftGit2 (libgit2 wrapper).

MODELS:
- GitRepository: localPath, name, currentBranch, isDirty, lastCommitMessage, lastCommitDate, remoteURL
- GitCommit: sha, message, author, date, parentSHAs
- GitFileStatus: path, statusCode (modified/added/deleted/untracked/renamed)

GIT SERVICE (Features/GitWorkspace/Services/GitService.swift):
- Actor GitService
- Use SwiftGit2: import SwiftGit2
- openRepository(at url: URL) -> Repository
- status(repo:) -> [StatusEntry]
- stage(files:in repo:) 
- unstage(files:in repo:)
- commit(repo:message:authorName:authorEmail:)
- branches(repo:) -> [Branch]  
- checkout(branch:in repo:)
- pull(repo:) — via process fallback (git pull) since libgit2 SSH auth is complex
- push(repo:) — via process fallback (git push)
- log(repo:limit:) -> [Commit]
- stashList(repo:) / stashSave(repo:message:) / stashPop(repo:)

GIT WORKSPACE VIEW:
- Left panel: list of watched repositories (user adds repos via folder picker)
- Repository row: name, branch badge, dirty indicator (● N changed files)
- Right panel tabs: Status | Log | Branches | Stashes
- Status tab: two-column (Staged / Unstaged), file list with checkboxes to stage/unstage
  - Commit message text area + Commit button at bottom
- Log tab: commit history table (sha short, message, author, date)
  - Click commit → diff sheet (show changed files + unified diff per file with Highlightr)
- Branches tab: local + remote branches list, checkout and delete actions
- Stashes tab: list of stashes, apply/drop actions

DIFF VIEWER (Shared/Components/DiffView.swift):
- Parse unified diff output (run "git diff" as Process, capture output)
- Render with line numbers: red background for deletions, green for additions
- Use monospace font (SF Mono or Menlo)

CONSTRAINTS:
- SwiftGit2 may not support all operations — fall back to running git binary (find at /usr/bin/git or /opt/homebrew/bin/git) for push/pull/fetch where needed
- Repo list persisted in GRDB (just paths + display names)
- If repo path no longer exists: show warning, offer to remove
- All git operations async, never block main thread
- Do not commit with empty message

OUTPUT: Complete implementation.
```

#### ANTI-HALLUCINATION — Phase 4

- [ ] SwiftGit2 API: verify method signatures against https://github.com/SwiftGit2/SwiftGit2 — AI often confuses SwiftGit2 with other git libraries
- [ ] `Repository` opening: must handle path not existing gracefully
- [ ] SSH push/pull via git binary: verify binary path detection works on both `/usr/bin/git` and Homebrew paths
- [ ] Diff view: test with binary files (should show "Binary file changed", not crash)
- [ ] Empty repo (no commits): verify log tab shows empty state, not crash

---

### PHASE 5 — SSH Manager (Week 6)

**GitHub Milestone:** `v0.6.0-ssh-manager`

#### IMPL — OpenCode AI Prompt (Phase 5)

```
CONTEXT: DevForge. Phases 0-4 complete.

TASK: Implement SSH & Host Manager.

SSH CONFIG PARSER (Services/SSHConfigParser.swift):
- Parse ~/.ssh/config file manually (no external library needed)
- Support: Host, HostName, User, Port, IdentityFile, ProxyJump, ForwardAgent blocks
- SSHHost model: alias, hostname, user, port, identityFile, proxyJump, forwardAgent
- Write back modified config (preserve comments and formatting where possible)
- Handle "Host *" wildcard block (parse but mark as global defaults)

SSH HOST SERVICE (Features/SSHManager/Services/SSHHostService.swift):
- Load hosts from ~/.ssh/config
- CRUD: add, edit, delete host entries (write back to config file)
- testConnectivity(host:) — TCP connection to host:port (no ICMP) with 3s timeout
  Use Network.framework: NWConnection to host:port
- openTerminal(host:) — launch ssh command in Terminal.app or iTerm2
  Use NSWorkspace to open Terminal.app, pass ssh command as argument

PORT FORWARD SERVICE:
- PortForwardRule model: localPort, remoteHost, remotePort, viaHost (SSHHost), isActive
- Start forward: run "ssh -N -L localPort:remoteHost:remotePort user@host" as Process
- Stop forward: terminate the Process
- Store active rules in memory (no DB needed — ephemeral)

SSH MANAGER VIEW:
- Host list with connectivity dot (green=reachable, grey=unknown, red=unreachable)
- Host detail: all SSH config fields editable
- "Connect" button: opens Terminal.app with ssh command
- "Test" button: runs TCP connectivity check
- Port Forwards tab: list of rules, add/remove, start/stop toggle
- "Add Host" sheet: form with all SSHHost fields

CONSTRAINTS:
- Never store SSH private keys or passwords in app
- ~/.ssh/config path must use NSHomeDirectory() not hardcoded /Users/username
- SSH config write: write to temp file first, then atomic rename to avoid corruption
- If ~/.ssh/config doesn't exist: offer to create it

OUTPUT: Complete implementation.
```

#### ANTI-HALLUCINATION — Phase 5

- [ ] SSH config parser: test with real `~/.ssh/config` file including multi-host sections
- [ ] `Network.framework` TCP check: `NWConnection` API — verify AI uses correct init and state handler
- [ ] `NSWorkspace.shared.open(_:withApplicationAt:configuration:completionHandler:)` — verify Terminal.app launch works
- [ ] Atomic write: verify temp file + rename pattern, not direct overwrite
- [ ] Port forward Process: verify it doesn't block UI thread

---

### PHASE 6 — Task Runner (Week 7)

**GitHub Milestone:** `v0.7.0-task-runner`

#### IMPL — OpenCode AI Prompt (Phase 6)

```
CONTEXT: DevForge. Phases 0-5 complete.

TASK: Implement Task Runner.

TASK DISCOVERY SERVICE (Features/TaskRunner/Services/TaskDiscoveryService.swift):
- Given a directory URL, detect and parse:
  - Makefile: extract targets (lines matching /^[a-zA-Z_-]+:/)
  - package.json: extract "scripts" object keys
  - Justfile: extract recipe names (lines matching /^[a-zA-Z_-]+:/)
- Return [DiscoveredTask] with: name, command, sourceFile, sourceType

TASK EXECUTION SERVICE (Features/TaskRunner/Services/TaskRunnerService.swift):
- Actor TaskRunnerService
- run(task:in workingDirectory:) → AsyncStream<TaskOutputLine>
- TaskOutputLine: content, isError, timestamp
- Track TaskRun: task name, startTime, endTime, exitCode, outputLines
- Persist TaskRun history to GRDB (keep last 50 runs per task)
- Cancel running task (terminate Process)

LAUNCHD SCHEDULER (Features/TaskRunner/Services/LaunchdService.swift):
- Generate launchd plist XML for a given task + schedule (interval in seconds or cron-like)
- Write plist to ~/Library/LaunchAgents/com.devforge.task.\(taskName).plist
- Load/unload via launchctl (run as Process)
- List managed agents: read plist files from ~/Library/LaunchAgents/ with com.devforge prefix

TASK RUNNER VIEW:
- Left: project directory picker, tree of discovered tasks grouped by source file
- Right: task detail — description, run button, last run status + exit code
- Output panel: scrolling log of current/last run with ANSI coloring
- History tab: table of past runs with duration and exit code
- Schedule tab: toggle scheduling, set interval, show launchd status

CONSTRAINTS:
- Task commands run in a shell: use /bin/zsh -c "command" (or user's $SHELL)
- Working directory must be set to the project directory
- Makefile parser: skip lines starting with # and handle multi-line targets
- Exit code 0 = success (green), non-zero = failure (red)

OUTPUT: Complete implementation.
```

#### ANTI-HALLUCINATION — Phase 6

- [ ] Makefile regex: test with tabs (Makefile requires tabs, not spaces) — parser should not break on spaces
- [ ] `package.json` parsing: use `JSONDecoder` or `JSONSerialization` — AI may try to regex parse JSON
- [ ] Launchd plist XML: validate generated plist with `plutil -lint` before loading
- [ ] `launchctl load/unload` deprecated in macOS 13+ — use `launchctl bootstrap/bootout` or `enable/disable` — verify AI uses correct API

---

### PHASE 7 — Log Aggregator (Week 8)

**GitHub Milestone:** `v0.8.0-log-aggregator`

#### IMPL — OpenCode AI Prompt (Phase 7)

```
CONTEXT: DevForge. Phases 0-6 complete.

TASK: Implement Log Aggregator.

FILE WATCHER (Services/FileWatcherService.swift):
- Actor FileWatcherService
- Watch files for changes using FSEventStreamCreate (Core Services / FSEvents C API)
- Provide AsyncStream<URL> of changed file URLs
- Support watching multiple files simultaneously
- Clean up FSEventStream on deinit/stop

LOG TAIL SERVICE (Features/LogAggregator/Services/LogTailService.swift):
- Actor LogTailService
- tail(fileURL:) -> AsyncStream<LogLine>: open file, seek to end, stream new lines as FSEvents fire
- Implements "follow" behavior (like tail -f)
- LogLine: content, timestamp, lineNumber, source (file name)
- Supports tailing multiple files concurrently (merge into single stream with source tag)

LOG AGGREGATOR VIEW:
- Left panel: watched files list (user adds via file picker or common log path shortcuts)
  - Quick add buttons: Console.app logs, /var/log/system.log, ~/Library/Logs/*
- Right panel: unified log stream from all watched files
  - Column: time | source file | content
  - Filter bar: text search (instant, no delay), regex toggle
  - Severity filter: ALL / ERROR / WARN / INFO (auto-detect from log line content)
- Toolbar: pause/resume, clear display, export session to file
- Line click: expand to show raw content + file path + offset

CONSTRAINTS:
- FSEvents API is C — wrap carefully in Swift. Use kFSEventStreamCreateFlagFileEvents flag.
- Do not read entire file on each change — track file offset and read only new bytes
- Large files (>100MB): only tail last 10,000 lines on initial open
- Search filter must not block UI — use async debounce (300ms)
- Export: write to plain text or JSON (user choice) via save panel

OUTPUT: Complete implementation.
```

#### ANTI-HALLUCINATION — Phase 7

- [ ] `FSEventStreamCreate` is a C API — AI frequently gets the callback signature wrong. Verify callback: `FSEventStreamCallback` with correct parameters
- [ ] File offset tracking: test by writing to a watched file from Terminal and verifying only new lines appear
- [ ] Large file test: open a log file >50MB, verify app does not spike memory
- [ ] Regex filter: test invalid regex gracefully (show error, don't crash)

---

### PHASE 8 — System Health Dashboard (Week 9)

**GitHub Milestone:** `v0.9.0-system-health`

#### IMPL — OpenCode AI Prompt (Phase 8)

```
CONTEXT: DevForge. Phases 0-7 complete.

TASK: Implement System Health Dashboard using low-level macOS APIs.

SYSTEM METRICS SERVICE (Features/SystemHealth/Services/SystemMetricsService.swift):
- Actor SystemMetricsService
- Poll every 2 seconds
- CPU usage: use host_processor_info (mach/mach.h) via withUnsafeMutablePointer
- Memory: use host_statistics64 with HOST_VM_INFO64 (vm_statistics64_data_t)
- Disk I/O: IOKit — IOServiceGetMatchingServices with "IOBlockStorageDriver", get "Statistics" dict
- Network: getifaddrs / sysctl with NET_RT_IFLIST2 — read bytes in/out per interface delta
- Thermal state: IOKit SMC key reading for thermal level (use smc_cmd / AppleSMCDriver)
- Provide AsyncStream<SystemSnapshot> where SystemSnapshot contains all metrics

SPARKLINE COMPONENT (Shared/Components/SparklineView.swift):
- SwiftUI Shape-based line chart
- Takes [Double] history (last 60 points)
- Animated update when new value arrives
- Color: green (low), yellow (medium), red (high) based on thresholds

SYSTEM HEALTH VIEW:
- Grid layout: 4 metric cards (CPU, Memory, Disk, Network)
- Each card: current value large, sparkline, peak/average
- CPU: overall % + per-core breakdown (expandable)
- Memory: used / wired / compressed / free in GB with pressure indicator
- Disk: read MB/s, write MB/s, I/O wait %, disk usage per volume
- Network: up/down KB/s, total sent/received since boot, active interface selector
- Thermal: traffic-light indicator (nominal / fair / serious / critical)
- Bottom section: top 10 processes by CPU, top 10 by memory (via libproc proc_pidinfo)

CONSTRAINTS:
- All sysctl/mach calls in a separate C or Swift wrapper — document what each call does
- Memory values: display in human-readable units (KB/MB/GB auto-selected)
- CPU: normalize to 0-100% per core, then average for overall
- If a metric fails to read (permission): show "--" not crash
- Process list: use libproc.h proc_listpids + proc_pidinfo — link libproc in build settings

OUTPUT: Complete implementation with correct C API bridging.
```

#### ANTI-HALLUCINATION — Phase 8

- [ ] `host_processor_info`: AI frequently gets the processor tick math wrong (user+system ticks vs total). Verify: `(user+system)/(user+system+idle)` per core
- [ ] `host_statistics64`: cast to `vm_statistics64_data_t` — verify struct field names (AI confuses 32/64 bit variants)
- [ ] IOKit disk stats: dictionary key names are exact strings — verify against `ioreg -l` output on your machine
- [ ] libproc: add `-lproc` linker flag in Xcode build settings → Other Linker Flags
- [ ] Sparkline performance: if updating every 2s, verify no memory leak in the history array (cap at 60 items)

```bash
# Verify libproc is available
ls /usr/lib/libproc.dylib
```

---

### PHASE 9 — Polish & Integration (Week 10)

**GitHub Milestone:** `v0.10.0-polish`

#### Tasks

1. **Onboarding flow**: First-launch wizard detecting installed tools (git, docker, ssh)
2. **Global search**: `Cmd+K` spotlight-style search across all feature data
3. **Preferences window**: General, Appearance (light/dark/auto), Keyboard shortcuts, Data
4. **Keyboard shortcuts**: All primary actions have `Cmd+` shortcuts
5. **Notifications**: `UserNotifications` framework for process crashes, task completions
6. **Data export/import**: Backup entire DevForge data (excluding Keychain secrets) to JSON
7. **Empty states**: Every list view has a designed empty state (not blank)
8. **Accessibility**: All interactive elements have `.accessibilityLabel`, VoiceOver tested
9. **Menu bar extra**: Optional system-tray menu showing process count, Docker status

#### IMPL — OpenCode AI Prompt (Phase 9)

```
CONTEXT: DevForge. All feature pillars (Phases 1-8) complete.

TASK: Implement polish layer.

1. GLOBAL SEARCH (Shared/Components/GlobalSearchView.swift):
   - Triggered by Cmd+K (add KeyboardShortcut to top-level view)
   - Sheet with search field
   - Search providers: ProcessRecord names, EnvFile names, GitRepository names, SSHHost aliases, DockerContainer names
   - Async search across GRDB tables (debounced 200ms)
   - Results grouped by category with SF Symbol icon
   - Select result: navigate to that feature section + highlight item

2. PREFERENCES WINDOW (App/PreferencesView.swift):
   - Use Settings scene (SwiftUI macOS Settings)
   - Tabs: General | Appearance | Shortcuts | Data
   - General: launch at login toggle, show menu bar extra toggle
   - Appearance: color scheme override (auto/light/dark), accent color picker
   - Shortcuts: list of all Cmd+ shortcuts (read-only display for now)
   - Data: show DB size, export all data button, clear history button (with confirmation)

3. MENU BAR EXTRA (App/MenuBarManager.swift):
   - MenuBarExtra scene
   - Show: running process count, Docker status, system health summary
   - Quick actions: start/stop specific processes

4. LAUNCH AT LOGIN:
   - Use ServiceManagement framework (SMAppService.mainApp)
   - Toggle in Preferences

5. EMPTY STATES:
   - Create EmptyStateView component: SF Symbol (large), title, body text, optional action button
   - Apply to all 8 feature list views

CONSTRAINTS:
- Preferences must use SwiftUI Settings scene, not a manual window
- SMAppService is macOS 13+ — already within our deployment target
- Menu bar icon: use SF Symbol "terminal.fill" or similar
- Global search must complete within 300ms for typical dataset

OUTPUT: Complete implementation.
```

#### ANTI-HALLUCINATION — Phase 9

- [ ] `SMAppService.mainApp.register()` — verify this API exists in macOS 14 (it does, but AI sometimes uses older `SMLoginItemSetEnabled`)
- [ ] `MenuBarExtra` — available since macOS 13. Verify SwiftUI API (AI sometimes uses AppKit `NSStatusItem` instead)
- [ ] `Settings` scene — correct SwiftUI macro for macOS preferences window, opens via `Cmd+,`
- [ ] Test global search with 0 results: verify empty state shown, not crash

---

### PHASE 10 — Testing (Week 11)

**GitHub Milestone:** `v0.11.0-testing`

#### Test Strategy

| Layer | Tool | Coverage Target |
|---|---|---|
| Unit tests | XCTest | All services, parsers, models |
| Integration tests | XCTest | DB migrations, Keychain round-trips |
| UI tests | XCUITest | Critical flows (add process, start, stop) |
| Manual testing | Test plan checklist | All 8 pillars |

#### IMPL — OpenCode AI Prompt (Phase 10)

```
CONTEXT: DevForge. All features complete.

TASK: Write test suite.

UNIT TESTS — create Tests/UnitTests/ with:
1. SSHConfigParserTests: test parsing various config blocks including edge cases
2. EnvFileParserTests: test .env parsing with quotes, comments, multiline, empty values
3. ProcessRecordTests: test model encoding/decoding, status transitions
4. SystemMetricsTests: test unit conversion helpers (bytes→GB, ticks→percent)
5. DockerResponseTests: test JSON decoding of mock Docker API responses

INTEGRATION TESTS — create Tests/IntegrationTests/ with:
1. DatabaseMigrationTests: verify all migrations run in sequence on fresh DB
2. ProcessServiceTests: launch/terminate a real process (use /bin/sleep 10 as safe test target)
3. FileWatcherTests: write to temp file, verify FSEvents callback fires

TEST HELPERS:
- MockDatabase: in-memory GRDB setup for unit tests
- MockProcessService: fake service returning test data
- Fixtures/: JSON files for Docker API mock responses, sample SSH configs, sample .env files

CONSTRAINTS:
- Tests must run without Docker, git repos, or SSH keys available (mock where external deps needed)
- ProcessServiceTests: use /bin/sleep not any app-specific binary
- No async tests that can time out on slow CI — use expectation with 5s timeout
- All tests must pass on clean clone of repo

OUTPUT: Complete test implementations.
```

#### ANTI-HALLUCINATION — Phase 10

- [ ] In-memory GRDB setup: `DatabaseQueue(configuration:)` with `inMemory` flag — verify AI uses correct GRDB v6 API
- [ ] Async test pattern: use `await` with `XCTestExpectation` or Swift's built-in `async` test support
- [ ] Run full test suite: `xcodebuild test -scheme DevForge -destination 'platform=macOS'`
- [ ] Zero test failures required before Phase 11

---

### PHASE 11 — Documentation (Week 12)

**GitHub Milestone:** `v0.12.0-docs`

#### Documentation Checklist

- [ ] `README.md` — features, screenshots, installation, quick start
- [ ] `CONTRIBUTING.md` — how to contribute, code style, PR process
- [ ] `CHANGELOG.md` — all changes per version (Keep a Changelog format)
- [ ] `docs/adr/` — all ADRs created during development
- [ ] `docs/architecture.md` — system architecture, data flow diagram (ASCII or Mermaid)
- [ ] `docs/build.md` — complete build from scratch instructions
- [ ] In-code DocC comments for all public types and methods
- [ ] `man` page or Help book for end users (optional, nice to have)

#### IMPL — OpenCode AI Prompt (Phase 11)

```
CONTEXT: DevForge. All features and tests complete.

TASK: Generate documentation.

1. README.md: 
   - Hero section: app name, tagline, license badge, platform badge
   - Feature overview with bullet list of all 8 pillars
   - Requirements: macOS 14+, Apple Silicon, Docker (optional), Git (optional)
   - Installation: download DMG from releases OR build from source
   - Quick start: 5 steps to first process launch
   - Architecture overview: 3-sentence summary
   - Contributing: link to CONTRIBUTING.md
   - License: Apache 2.0 statement

2. CONTRIBUTING.md:
   - Code of conduct reference
   - Dev setup: clone, open Xcode, run
   - Branching and PR process
   - Spec-first rule (Issue before code)
   - SwiftLint enforcement
   - Test requirements (all tests pass)

3. Architecture doc (docs/architecture.md):
   - ASCII diagram of feature modules
   - Data flow: User action → ViewModel → Service → DB/OS
   - Technology choices rationale

4. DocC comments: Add /// documentation to all public structs/classes/actors/enums/funcs in:
   - All service files
   - All model files
   - Core/Database/AppDatabase.swift

OUTPUT: All documentation files as complete markdown, plus DocC-commented Swift files.
```

---

### PHASE 12 — Release Prep (Week 13)

**GitHub Milestone:** `v1.0.0`

#### IMPL — OpenCode AI Prompt (Phase 12)

```
CONTEXT: DevForge. All features, tests, documentation complete.

TASK: Production release preparation.

1. NOTARIZATION SETUP (docs/notarization.md):
   Write step-by-step instructions for:
   - Archive build in Xcode (Product → Archive)
   - Export signed DMG
   - Submit to Apple notarization: xcrun notarytool submit ... --apple-id ... --team-id ... --password ...
   - Staple ticket: xcrun stapler staple DevForge.dmg
   - Verify: spctl --assess --type open --context context:primary-signature DevForge.dmg

2. GITHUB RELEASE WORKFLOW (.github/workflows/release.yml):
   GitHub Actions workflow triggered on git tag push (v*):
   - macOS-latest runner
   - xcodebuild archive
   - Create GitHub Release with DMG artifact attached
   - Generate release notes from CHANGELOG.md

3. SWIFTLINT CONFIG (.swiftlint.yml):
   - Enforce: line_length (120), force_cast (error), force_try (error), empty_count, 
     trailing_whitespace, unused_imports, file_length (400)
   - Disable: todo (allow TODOs during dev)
   - Include all .swift files in DevForge/

4. VERSION MANAGEMENT:
   - Version: 1.0.0 in Xcode project (marketing version)
   - Build number: auto-increment via agvtool or build number = git commit count
   - git tag v1.0.0 and push

5. GITHUB RELEASE CHECKLIST (docs/release-checklist.md):
   Complete checklist covering: tests pass, SwiftLint clean, notarized, 
   README updated, CHANGELOG updated, tag created.

CONSTRAINTS:
- GitHub Actions workflow: use macos-14 runner (Apple Silicon)
- Do not embed Apple credentials in workflow — use GitHub Secrets
- DMG must be code-signed before notarization attempt

OUTPUT: All configuration files and documentation.
```

#### ANTI-HALLUCINATION — Phase 12

- [ ] `notarytool` is correct tool (not deprecated `altool`)
- [ ] GitHub Actions `macos-14` runner supports arm64
- [ ] `xcodebuild -exportArchive` flags: verify correct `-exportOptionsPlist` format
- [ ] SwiftLint rule names: verify against https://realm.github.io/SwiftLint/rule-directory.html — AI invents non-existent rule names

---

## 7. MASTER ANTI-HALLUCINATION PROTOCOL

This section applies to **every AI interaction** throughout the project.

### 7.1 The Three Laws of AI Collaboration

**Law 1 — Never Trust, Always Verify**  
Every API, method name, enum case, and framework feature generated by AI must be verified to exist before committing. AI models confidently invent plausible-sounding but non-existent APIs.

**Law 2 — Compile Is the Ground Truth**  
If it doesn't compile, it doesn't exist. Never skip the build step after AI output.

**Law 3 — AI Forgets Context**  
In long sessions, AI loses track of earlier decisions. Re-inject context at the start of each session using the session header template below.

### 7.2 Session Header Template

Paste this at the start of every OpenCode AI session:

```
DEVFORGE SESSION HEADER — paste this at start of every AI session

Project: DevForge — macOS 14+ native app, SwiftUI, Swift 5.10
Completed phases: [LIST COMPLETED PHASES]
Current phase: [CURRENT PHASE]
Key constraints (always apply):
- macOS ONLY — never suggest iOS/UIKit APIs
- Offline ONLY — no URLSession to internet, no Firebase, no analytics
- GRDB.swift v6 for persistence — no CoreData, no Realm
- @Observable not ObservableObject (Swift 5.9+)
- Actor isolation for all services
- NavigationSplitView not NavigationView (deprecated)
- App Sandbox enabled
- NO third-party UI frameworks
- Build target: arm64 (Apple Silicon)

Before generating code, state which APIs you will use and confirm they exist in macOS 14 SDK.
```

### 7.3 Hallucination Hot Spots by Category

| Category | Common Hallucinations | How to Verify |
|---|---|---|
| **SwiftUI** | Invents view modifiers that don't exist; uses iOS-only APIs | Search Apple Developer Docs, filter by macOS |
| **GRDB** | Invents non-existent query methods | Check GRDB README on GitHub |
| **Process/libproc** | Wrong struct field names for sysctl/mach | `man proc_pidinfo`, test compile |
| **IOKit** | Invents IOKit service names and key strings | `ioreg -l` on your machine |
| **FSEvents** | Wrong callback signature | Apple FSEvents Programming Guide |
| **Docker API** | Wrong JSON field names/types | Docker Engine API docs v1.43 |
| **SwiftGit2** | Mixes up libgit2 C API with SwiftGit2 Swift API | SwiftGit2 source on GitHub |
| **Entitlements** | Invents entitlement keys | Apple Entitlements Reference |
| **SMAppService** | Uses deprecated SMLoginItemSetEnabled | WWDC 2022 session on login items |
| **Keychain** | Wrong SecItem attribute keys | Apple Keychain Services Reference |

### 7.4 Red Flag Phrases — Stop and Verify When You See These

If AI output contains any of these, **stop and verify before using the code**:

- `"This should work..."` → AI is uncertain
- `"You may need to adjust..."` → AI generated something it knows might be wrong  
- `"Note: I'm not 100% sure..."` → explicit uncertainty, always verify
- `import SomeFramework` where SomeFramework is unfamiliar → check it exists
- Any method with `get`, `fetch`, `read`, `write` that you haven't seen before → verify
- Any string constant (notification names, IOKit keys, plist keys) → verify exact spelling

### 7.5 Verification Workflow After Each AI Session

```bash
#!/bin/bash
# Run after every AI coding session before committing

echo "=== Step 1: Compile ==="
xcodebuild -scheme DevForge \
  -destination 'platform=macOS,arch=arm64' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tee /tmp/build.log
grep -c "error:" /tmp/build.log && echo "ERRORS FOUND — do not commit" || echo "✓ Build clean"

echo "=== Step 2: SwiftLint ==="
swiftlint lint --strict 2>&1 | grep "error:" && echo "LINT ERRORS — fix before commit" || echo "✓ Lint clean"

echo "=== Step 3: Tests ==="
xcodebuild test -scheme DevForge \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5

echo "=== Step 4: Check for debug artifacts ==="
grep -r "print(" DevForge/Features/ --include="*.swift" | grep -v "//.*print" | head -10

echo "=== Step 5: Check for TODO bombs ==="
grep -r "TODO\|FIXME\|HACK\|XXX" DevForge/ --include="*.swift" | wc -l
```

### 7.6 When AI Gets Stuck in a Loop

If AI keeps generating the same wrong code after 2 corrections:
1. Stop the session
2. Write the problematic section by hand (with reference to docs)  
3. Commit the hand-written version
4. Resume AI assistance on the next section

### 7.7 Context Window Discipline

- Split each phase into sub-tasks if output exceeds one screen
- Never ask AI to generate more than 3 files in one prompt
- If a file is >200 lines, ask AI to generate it in sections (top half / bottom half)
- After every 5 AI turns, paste the Session Header again

---

## 8. MEMORY MANAGEMENT FOR M1 8GB

Running Xcode + OpenCode AI + Docker Desktop on 8GB requires discipline.

### 8.1 Process Priority During Development

| Stage | Run | Don't Run |
|---|---|---|
| Coding | Xcode + Terminal + OpenCode | Docker Desktop, browsers |
| Testing | Xcode + Docker | OpenCode AI |
| Git ops | Terminal only | Everything else |

### 8.2 Xcode Settings for Low Memory

- Preferences → General → Re-open windows on launch: OFF
- Preferences → Text Editing → Live Issues: limit to current file
- DerivedData location: set to relative (avoids disk bloat)
- Close simulator (not needed for macOS target)

### 8.3 Build Performance

```bash
# Add to Xcode build settings for faster Debug builds
SWIFT_COMPILATION_MODE = singlefile
SWIFT_OPTIMIZATION_LEVEL = -Onone  # Debug only
GCC_OPTIMIZATION_LEVEL = 0
```

---

## 9. PRODUCTION READINESS CHECKLIST

Complete this checklist before tagging `v1.0.0`:

### Code Quality
- [ ] Zero compiler warnings
- [ ] Zero SwiftLint errors
- [ ] All TODO/FIXME resolved or tracked as GitHub Issues
- [ ] No `print()` statements in production code paths (use `Logger` from OSLog)
- [ ] No hardcoded paths (no `/Users/username/`, no `/usr/local/bin/` without detection)
- [ ] All error paths handled (no `try!` except migrations, no `!` force unwraps except safe cases)

### Testing
- [ ] All unit tests pass
- [ ] All integration tests pass  
- [ ] Manual test of all 8 feature pillars on clean macOS install
- [ ] Tested with Docker not installed
- [ ] Tested with no git repos
- [ ] Tested with no SSH config
- [ ] Memory: no leaks after 30 min of typical usage (Instruments → Leaks)
- [ ] Performance: app launch < 2 seconds, UI response < 100ms for all interactions

### Security
- [ ] No secrets in source code or git history
- [ ] Keychain entries have correct access control
- [ ] App Sandbox validated (run `codesign --display --entitlements - DevForge.app`)
- [ ] No network calls to internet (verify with Little Snitch or Charles Proxy)
- [ ] Input sanitization on all user-provided command strings

### Distribution
- [ ] Code signed with Developer ID
- [ ] Notarized and stapled
- [ ] DMG created and tested on clean macOS install
- [ ] GitHub Release created with correct tag
- [ ] CHANGELOG.md updated
- [ ] README.md reflects final feature set

### Accessibility
- [ ] All interactive elements have accessibility labels
- [ ] VoiceOver navigation works through all 8 pillars
- [ ] App respects system font size settings
- [ ] Keyboard-only navigation possible for critical flows

---

## 10. QUICK REFERENCE

### Common Commands

```bash
# Build
xcodebuild -scheme DevForge -destination 'platform=macOS,arch=arm64' build CODE_SIGNING_ALLOWED=NO

# Test
xcodebuild test -scheme DevForge -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO

# Lint
swiftlint lint --strict

# Create feature branch
git checkout develop && git pull && git checkout -b feat/phase-N-feature-name

# Spec issue
gh issue create --label "spec:story" --title "[SPEC] Feature name" --body "..."

# Close spec
gh issue close <number> --comment "Implemented in PR #<pr>" && gh issue edit <number> --add-label "spec:done"

# Tag release
git tag -a v1.0.0 -m "Release v1.0.0" && git push origin v1.0.0
```

### Phase → Milestone Map

| Phase | Name | Milestone | Week |
|---|---|---|---|
| 0 | Foundation | v0.1.0 | 1 |
| 1 | Process Manager | v0.2.0 | 2 |
| 2 | Env Vault | v0.3.0 | 3 |
| 3 | Docker Console | v0.4.0 | 4 |
| 4 | Git Workspace | v0.5.0 | 5 |
| 5 | SSH Manager | v0.6.0 | 6 |
| 6 | Task Runner | v0.7.0 | 7 |
| 7 | Log Aggregator | v0.8.0 | 8 |
| 8 | System Health | v0.9.0 | 9 |
| 9 | Polish | v0.10.0 | 10 |
| 10 | Testing | v0.11.0 | 11 |
| 11 | Documentation | v0.12.0 | 12 |
| 12 | Release | v1.0.0 | 13 |

---

## 11. LICENSE

```
Copyright 2025 [Your Name]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

---

*End of Blueprint. Feed Phase 0 IMPL prompt to OpenCode AI to begin.*
