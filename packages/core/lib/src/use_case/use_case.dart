/// Base contracts for domain use cases.
///
/// A use case is one business operation (for example "update a note"). It
/// owns orchestration and business rules, and depends only on repository
/// contracts, so it can be unit-tested without Flutter, storage or network.
library;

/// Marker base class for use case parameters.
abstract class UseCaseParams {
  const UseCaseParams();
}

/// Parameters for use cases that need none.
class NoParams extends UseCaseParams {
  const NoParams();
}

/// A one-shot use case returning a single value (usually a `Resource<T>`).
abstract class UseCase<Result, Params extends UseCaseParams> {
  const UseCase();

  /// Executes the use case.
  Future<Result> call(Params params);
}

/// A use case that exposes a reactive stream (for example "watch notes").
abstract class StreamUseCase<Result, Params extends UseCaseParams> {
  const StreamUseCase();

  /// Subscribes to the stream produced by the use case.
  Stream<Result> call(Params params);
}
