import 'package:core/domain.dart';

/// Business rules shared by create and update.
abstract final class NoteValidation {
  /// Maximum title length.
  static const int maxTitleLength = 120;

  /// Maximum body length.
  static const int maxBodyLength = 5000;

  /// Returns a [Failure] when the input breaks a rule, or `null` when valid.
  static Failure<T>? validate<T>({
    required String title,
    required String body,
  }) {
    if (title.trim().isEmpty && body.trim().isEmpty) {
      return Failure<T>(
        'A note needs a title or some text.',
        code: 'validation',
      );
    }
    if (title.trim().length > maxTitleLength) {
      return Failure<T>(
        'Title must be at most $maxTitleLength characters.',
        code: 'validation',
      );
    }
    if (body.length > maxBodyLength) {
      return Failure<T>(
        'Text must be at most $maxBodyLength characters.',
        code: 'validation',
      );
    }
    return null;
  }
}
