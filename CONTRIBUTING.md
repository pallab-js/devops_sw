# Contributing to DevForge

## Code of Conduct

Be respectful, constructive, and professional.

## Development Setup

1. Clone the repo
2. Open `DevForge.xcodeproj` in Xcode 15.4+
3. Build and run (Product → Run)

## Branching and PR Process

- All work must be on feature branches (`feat/*`, `fix/*`, `chore/*`)
- No direct commits to `main` or `develop`
- All changes via pull requests

## Spec-First Rule

Every feature MUST have a GitHub Issue (spec) before any code is written.  
No spec = no code.

## Code Style

- SwiftLint enforced (run `swiftlint lint --strict` before committing)
- Line length: 120 characters max
- Force unwrapping: error-level offense
- All services should be `actor` types
- Use `@Observable` (Swift 5.9+) not `ObservableObject`

## Testing

- All tests must pass before merging
- Services should be testable with mock dependencies
- Write tests for all parsers, models, and service methods

## Commit Convention

Use Conventional Commits:
```
feat(docker): add container log streaming
fix(process): handle SIGTERM on managed processes
docs(readme): update installation steps
```
