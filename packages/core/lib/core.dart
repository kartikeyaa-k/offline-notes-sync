/// Offline-first sync core: everything a feature's **data** layer needs to
/// keep working with no network and reconcile when connectivity returns.
///
/// Start with `SyncEngine` (orchestration), `SyncRecord` (the synced unit),
/// `LwwMerger` (the conflict rule) and `Hlc` (Hybrid Logical Clock, the
/// ordering of edits). See `packages/core/README.md` and the root
/// `PROJECT.md` for the design.
library;

export 'domain.dart';
export 'src/clock/hlc.dart';
export 'src/clock/hlc_clock.dart';
export 'src/connectivity/connectivity_service.dart';
export 'src/storage/key_value_store.dart';
export 'src/sync/conflict_log_entry.dart';
export 'src/sync/field_conflict.dart';
export 'src/sync/local/sync_local_store.dart';
export 'src/sync/lww_merger.dart';
export 'src/sync/outbox_entry.dart';
export 'src/sync/remote/sync_remote_gateway.dart';
export 'src/sync/sync_engine.dart';
export 'src/sync/sync_record.dart';
export 'src/sync/sync_status.dart';
export 'src/utils/async_lock.dart';
