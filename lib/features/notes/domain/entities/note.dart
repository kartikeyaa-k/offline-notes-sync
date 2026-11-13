import 'package:equatable/equatable.dart';

/// Whether a note's latest local changes have reached the server.
enum NoteSyncState {
  /// The server has every local change.
  synced,

  /// Edited locally; waiting in the outbox for connectivity.
  pending,
}

/// A note, as the app sees it.
///
/// Plain domain entity: no JSON (JavaScript Object Notation), no clocks, no
/// storage details. The data layer maps the synced record to this.
class Note extends Equatable {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
    required this.lastEditedByDeviceId,
    required this.syncState,
  });

  /// Stable id, generated on the device so notes can be created offline.
  final String id;

  /// Note title.
  final String title;

  /// Note body text.
  final String body;

  /// When the note content was last edited (on any device).
  final DateTime updatedAt;

  /// Which device made the latest content edit.
  final String lastEditedByDeviceId;

  /// Whether local changes are still waiting to sync.
  final NoteSyncState syncState;

  /// Convenience flag for the UI (User Interface).
  bool get isPending => syncState == NoteSyncState.pending;

  @override
  List<Object?> get props => [
    id,
    title,
    body,
    updatedAt,
    lastEditedByDeviceId,
    syncState,
  ];
}
