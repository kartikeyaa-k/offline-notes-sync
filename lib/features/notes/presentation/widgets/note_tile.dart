import 'package:flutter/material.dart';

import '../../domain/entities/note.dart';
import 'formatting.dart';

/// One note in the list: title, a preview of the body, who edited it last,
/// and a cloud icon showing whether it is synced or still pending.
class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    this.deviceName = rawDeviceName,
  });

  /// The note to show.
  final Note note;

  /// Opens the editor.
  final VoidCallback onTap;

  /// Deletes the note.
  final VoidCallback onDelete;

  /// Resolves device ids to display names.
  final DeviceNameResolver deviceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncIcon = note.isPending
        ? Tooltip(
            message: 'Saved on this device, waiting to sync',
            child: Icon(
              Icons.cloud_upload_outlined,
              color: theme.colorScheme.tertiary,
              size: 20,
            ),
          )
        : Tooltip(
            message: 'Synced',
            child: Icon(
              Icons.cloud_done_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          );

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        title: Text(
          note.title.isEmpty ? '(untitled)' : note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.body.isNotEmpty)
              Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(
              'Edited ${formatDateTime(note.updatedAt)} · ${deviceName(note.lastEditedByDeviceId)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        trailing: syncIcon,
      ),
    );
  }
}
