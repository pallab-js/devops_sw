# ADR-001: Use GRDB.swift for Local Persistence

**Status:** Accepted
**Date:** 2025-01-01

## Context

DevForge needs offline SQLite persistence with type-safe queries in Swift. Requirements include:
- Full offline support (no network database)
- Swift concurrency native (async/await)
- Type-safe queries without ORM overhead
- Migration support for schema evolution

## Decision

Use GRDB.swift v6. Reasons:
- Swift concurrency native with async/await
- No ORM overhead — direct SQLite access with Swift type safety
- Battle-tested in production apps
- Migration system for schema evolution
- Active maintenance and community

## Consequences

- Positive: Fast, type-safe, offline-first persistence
- Negative: Manual migration scripts required for schema changes
- Neutral: Team must learn GRDB query API
- Neutral: Not a drop-in Core Data replacement
