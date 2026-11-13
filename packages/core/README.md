# core: offline-first sync engine

A feature-agnostic package for "a list of items the user can edit that must keep working with no network and reconcile when connectivity returns".

## Libraries

| Import | For | Contents |
|---|---|---|
| `package:core/domain.dart` | domain layers | `Resource<T>` (`Success` / `Failure` / `Loading`), `UseCase`, `StreamUseCase`, `NoParams`. Pure Dart. |
| `package:core/core.dart` | data layers | `SyncEngine`, `SyncRecord`, `LwwMerger`, `ConflictDetector`, `Hlc` (Hybrid Logical Clock), `HlcClock`, `OutboxEntry`, `SyncLocalStore`, `KeyValueStore`, `ConnectivityService`, `SyncRemoteGateway` |
| `package:core/mock_server.dart` | demos and tests | `MockSyncServer`, `MockRemoteGateway` |

## Using it in a feature

```dart
final engine = SyncEngine(
  deviceId: 'device-a',
  store: KeyValueSyncLocalStore(storage: SharedPreferencesKeyValueStore(), storageKey: 'sync.device-a.todos'),
  remote: myGateway,                    // implements SyncRemoteGateway
  connectivity: DeviceConnectivityService(),
  clock: HlcClock(nodeId: 'device-a'),
);
await engine.start();

engine.watchRecords();                                  // UI source of truth (offline too)
await engine.write(id, {'title': 'Buy milk'});         // offline-safe, only this field is stamped
await engine.delete(id);                                // tombstone, synced later
await engine.syncNow();                                 // optional; triggers are automatic
```

A feature only decides its **field names**; the engine handles storage, the outbox, push/pull, merging and the conflict log.

## The conflict rule (in one paragraph)

Every field of a `SyncRecord` carries the HLC timestamp of its last edit. `LwwMerger.merge` keeps, per field, the value with the newer timestamp: a LWW (Last-Writer-Wins) map. The delete flag is a field too, with one extra rule: a content edit newer than the delete restores the record. The merge is commutative, associative and idempotent, so the server and every device converge to the same data in any sync order, and retries are harmless. The server additionally uses the outbox's `baseClocks` to *report* real concurrent edits (`FieldConflict`), which the engine stores in a capped conflict log.

See the root [`PROJECT.md`](../../PROJECT.md) for the full design and the two-device scenarios.

## Swapping pieces

* **Backend:** implement `SyncRemoteGateway` (push, delta pull, change stream) over REST (Representational State Transfer) or gRPC. The server must run the same `LwwMerger` and de-duplicate by `opId`.
* **Storage:** implement `SyncLocalStore` (for example on SQLite with drift) for large data sets. Commits must stay atomic.
* **Connectivity:** implement `ConnectivityService`.

## Tests

```bash
flutter test
```
