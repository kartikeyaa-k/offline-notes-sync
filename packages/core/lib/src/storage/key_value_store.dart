import 'package:shared_preferences/shared_preferences.dart';

/// Minimal persistent string storage that the sync layer writes JSON
/// (JavaScript Object Notation) documents into.
///
/// Kept tiny on purpose: swapping the backend (for example to SQLite via
/// drift, or to Hive) only means implementing these three methods, or
/// implementing `SyncLocalStore` directly for very large data sets.
abstract interface class KeyValueStore {
  /// Reads [key], or `null` if absent.
  Future<String?> read(String key);

  /// Writes [value] under [key]. A single write is atomic.
  Future<void> write(String key, String value);

  /// Removes [key].
  Future<void> delete(String key);
}

/// [KeyValueStore] backed by `shared_preferences` (NSUserDefaults on Apple
/// platforms, SharedPreferences on Android, localStorage on web).
class SharedPreferencesKeyValueStore implements KeyValueStore {
  SharedPreferencesKeyValueStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> delete(String key) => _preferences.remove(key);
}

/// In-memory [KeyValueStore] for tests (nothing survives a restart).
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = {};

  /// Read-only view of what is stored (handy in test assertions).
  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
