## 0.0.1

* Initial release: offline-first `SyncEngine` with a local source of truth, an atomic outbox, push-then-pull sync with delta pulls and idempotent pushes, per-field Last-Writer-Wins (LWW) merge ordered by Hybrid Logical Clock (HLC) timestamps, conflict detection and a persisted conflict log, connectivity services (real and simulated), `Resource<T>` / `UseCase` domain primitives, and an in-process mock sync server.
