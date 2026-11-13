import 'package:flutter/material.dart';

import 'package:offline_items_app/features/notes/domain/entities/note_conflict.dart';
import 'package:offline_items_app/features/notes/presentation/widgets/formatting.dart';

/// Shows the list of automatically resolved conflicts, each explained in
/// plain words: what clashed, which edit was newer, which one was kept.
Future<void> showConflictHistory(
  BuildContext context, {
  required List<NoteConflict> conflicts,
  DeviceNameResolver deviceName = rawDeviceName,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.6,
    builder: (context, controller) => conflicts.isEmpty
        ? const Center(child: Text('No conflicts yet'))
        : ListView.separated(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: conflicts.length + 1,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) => index == 0
                ? Text(
                    'Rule: for each field, the most recent edit wins — '
                    'when it was made, not when it was synced.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : _ConflictTile(
                    conflict: conflicts[index - 1],
                    deviceName: deviceName,
                  ),
          ),
  ),
);

class _ConflictTile extends StatelessWidget {
  const _ConflictTile({required this.conflict, required this.deviceName});

  final NoteConflict conflict;
  final DeviceNameResolver deviceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final won = conflict.outcome == ConflictOutcome.thisDeviceWon;
    final other = deviceName(conflict.otherDeviceId);
    final mine = 'this device (${formatTime(conflict.thisDeviceEditedAt)})';
    final theirs = '$other (${formatTime(conflict.otherDeviceEditedAt)})';

    final String headline;
    final String detail;
    switch (conflict.type) {
      case NoteConflictType.bothEdited:
        final field = conflict.field == NoteField.title ? 'title' : 'text';
        headline = 'Both devices edited the $field';
        detail = won
            ? 'Kept your edit from $mine because it is newer than $theirs.\n'
                  'Replaced: "${conflict.otherDeviceValue ?? ''}"'
            : 'Kept the edit from $theirs because it is newer than yours from $mine.\n'
                  'Your replaced value: "${conflict.thisDeviceValue ?? ''}"';
      case NoteConflictType.editedButDeletedElsewhere:
        headline = 'You edited a note that $other deleted';
        detail = won
            ? 'Your edit at $mine is newer than the delete at $theirs, so the note was restored.'
            : 'The delete at $theirs is newer than your edit at $mine, so the note stays deleted.';
      case NoteConflictType.deletedButEditedElsewhere:
        headline = 'You deleted a note that $other edited';
        detail = won
            ? 'Your delete at $mine is newer than their edit at $theirs, so it stays deleted.'
            : 'Their edit at $theirs is newer than your delete at $mine, so the note was restored.';
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        won ? Icons.check_circle_outline : Icons.call_merge,
        color: won ? theme.colorScheme.primary : theme.colorScheme.tertiary,
      ),
      title: Text('$headline · "${conflict.noteTitle}"'),
      subtitle: Text(
        '$detail\nResolved ${formatDateTime(conflict.resolvedAt)}',
      ),
      isThreeLine: true,
    );
  }
}
