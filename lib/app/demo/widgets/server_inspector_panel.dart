import 'package:core/core.dart';
import 'package:core/mock_server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../features/notes/data/models/note_model.dart';
import '../../../features/notes/presentation/widgets/formatting.dart';
import '../bloc/demo_session_cubit.dart';
import '../bloc/server_inspector_cubit.dart';

/// Read-only view of the mock server's data: each note's server version and,
/// per field, the value plus *when* and *on which device* it was last edited.
/// This is the data the conflict rule decides on.
class ServerInspectorPanel extends StatelessWidget {
  const ServerInspectorPanel({super.key, required this.root});

  /// Root container (holds the [MockSyncServer]).
  final GetIt root;

  @override
  Widget build(BuildContext context) {
    final server = root<MockSyncServer>();
    return BlocProvider(
      create: (_) => ServerInspectorCubit(server, NoteFields.collection),
      child: Scaffold(
        appBar: AppBar(title: const Text('Mock server')),
        body: BlocBuilder<ServerInspectorCubit, List<SyncRecord>>(
          builder: (context, records) => ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                'Global version: ${server.currentVersion} · ${records.length} records '
                '(${records.where((r) => r.isDeleted).length} deleted)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              for (final record in records) _ServerRecordCard(record: record),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerRecordCard extends StatelessWidget {
  const _ServerRecordCard({required this.record});

  final SyncRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    String stamp(String field) {
      final clock = record.clocks[field];
      return clock == null
          ? '—'
          : '${formatTime(clock.dateTime)} · ${demoDeviceName(clock.nodeId)}';
    }

    return Card(
      color: record.isDeleted
          ? theme.colorScheme.surfaceContainerHighest
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.field<String>(NoteFields.title) ?? '(untitled)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      decoration: record.isDeleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                Chip(
                  label: Text('v${record.version}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text('title edited ${stamp(NoteFields.title)}', style: small),
            Text('body edited  ${stamp(NoteFields.body)}', style: small),
            Text(
              '${record.isDeleted ? 'DELETED' : 'alive'} since ${stamp(SyncRecord.deletedField)}',
              style: small,
            ),
          ],
        ),
      ),
    );
  }
}
