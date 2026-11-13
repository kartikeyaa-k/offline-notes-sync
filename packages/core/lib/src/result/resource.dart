/// The single result type returned by every repository and use case.
///
/// Repositories never throw to their callers. Exceptions are caught once, at
/// the data-layer boundary (see [guardResource]), and turned into a
/// [Failure]. Blocs and Cubits can then `switch` over a [Resource] without any
/// try/catch.
///
/// ```dart
/// switch (await createNote(params)) {
///   case Success(:final data): print('created ${data.id}');
///   case Failure(:final message): print('failed: $message');
///   case Loading(): break;
/// }
/// ```
library;

/// Base type. Sealed so `switch` statements are exhaustive.
sealed class Resource<T> {
  const Resource();

  /// `true` when this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// `true` when this is a [Failure].
  bool get isFailure => this is Failure<T>;

  /// The carried data, if any (a [Loading] or [Failure] may also carry
  /// stale/partial data).
  T? get dataOrNull => switch (this) {
    Success<T>(:final data) => data,
    Loading<T>(:final data) => data,
    Failure<T>(:final data) => data,
  };
}

/// Work is in progress. Mostly used by presentation code; repositories return
/// [Success] or [Failure].
final class Loading<T> extends Resource<T> {
  const Loading([this.data]);

  /// Optional previous data to keep showing while loading.
  final T? data;
}

/// The operation succeeded with [data].
final class Success<T> extends Resource<T> {
  const Success(this.data);

  /// The result value.
  final T data;
}

/// The operation failed.
final class Failure<T> extends Resource<T> {
  const Failure(this.message, {this.code, this.cause, this.data});

  /// Human-readable message, safe to show in the UI (User Interface).
  final String message;

  /// Optional machine-readable code (for example `validation`, `network`).
  final String? code;

  /// The original exception, kept for logging. Never shown to users.
  final Object? cause;

  /// Optional partial data.
  final T? data;

  @override
  String toString() => 'Failure($code: $message)';
}

/// Runs [action] and converts its outcome into a [Resource].
///
/// This is the one place where exceptions become [Failure]s, so every
/// repository method behaves the same way on error.
Future<Resource<T>> guardResource<T>(
  Future<T> Function() action, {
  String fallbackMessage = 'Something went wrong. Please try again.',
}) async {
  try {
    return Success<T>(await action());
  } on ResourceException catch (e) {
    return Failure<T>(e.message, code: e.code, cause: e);
  } catch (e) {
    return Failure<T>(fallbackMessage, code: 'unexpected', cause: e);
  }
}

/// An exception that already carries a user-facing [message], so
/// [guardResource] can pass it through unchanged.
class ResourceException implements Exception {
  const ResourceException(this.message, {this.code});

  /// User-facing message.
  final String message;

  /// Machine-readable code.
  final String? code;

  @override
  String toString() => 'ResourceException($code: $message)';
}
