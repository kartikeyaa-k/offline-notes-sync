import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:offline_items_app/features/notes/domain/entities/sync_overview.dart';
import 'package:offline_items_app/features/notes/presentation/bloc/notes_cubit.dart';
import 'package:offline_items_app/features/notes/presentation/bloc/notes_state.dart';
import 'package:offline_items_app/features/notes/presentation/widgets/conflict_history_sheet.dart';
import 'package:offline_items_app/features/notes/presentation/widgets/formatting.dart';
import 'package:offline_items_app/features/notes/presentation/widgets/note_editor_dialog.dart';
import 'package:offline_items_app/features/notes/presentation/widgets/note_tile.dart';
import 'package:offline_items_app/features/notes/presentation/widgets/sync_status_banner.dart';

/// The list of editable notes for one device.
///
/// It provides its own [NotesCubit] (created by [createCubit], so the
/// composition root decides which device's dependencies it gets) and its own
/// `ScaffoldMessenger`, so two screens side by side show their messages
/// independently.
class NotesScreen extends StatelessWidget {
  const NotesScreen({
    required this.createCubit,
    super.key,
    this.title = 'Notes',
    this.appBarActions = const [],
    this.deviceName = rawDeviceName,
  });

  /// Factory for this screen's cubit.
  final NotesCubit Function() createCubit;

  /// App bar title.
  final String title;

  /// Extra app bar actions (the demo adds a network switch here).
  final List<Widget> appBarActions;

  /// Resolves device ids to display names.
  final DeviceNameResolver deviceName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => createCubit()..start(),
      child: ScaffoldMessenger(
        child: _NotesView(
          title: title,
          appBarActions: appBarActions,
          deviceName: deviceName,
        ),
      ),
    );
  }
}

class _NotesView extends StatelessWidget {
  const _NotesView({
    required this.title,
    required this.appBarActions,
    required this.deviceName,
  });

  final String title;
  final List<Widget> appBarActions;
  final DeviceNameResolver deviceName;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotesCubit>();
    return BlocListener<NotesCubit, NotesState>(
      listenWhen: (a, b) => a.feedback != b.feedback && b.feedback != null,
      listener: (context, state) {
        final feedback = state.feedback!;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(feedback.message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: feedback.isError
                  ? Theme.of(context).colorScheme.error
                  : null,
              action:
                  state.conflicts.isNotEmpty &&
                      !feedback.isError &&
                      feedback.message.contains('conflict')
                  ? SnackBarAction(
                      label: 'Details',
                      onPressed: () => showConflictHistory(
                        context,
                        conflicts: cubit.state.conflicts,
                        deviceName: deviceName,
                      ),
                    )
                  : null,
            ),
          );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            BlocSelector<NotesCubit, NotesState, int>(
              selector: (s) => s.conflicts.length,
              builder: (context, count) => IconButton(
                tooltip: 'Conflict history',
                onPressed: () => showConflictHistory(
                  context,
                  conflicts: cubit.state.conflicts,
                  deviceName: deviceName,
                ),
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.history),
                ),
              ),
            ),
            ...appBarActions,
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'New note',
          heroTag: null,
          onPressed: () => showNoteEditor(
            context,
            onSave: (title, body) => cubit.create(title: title, body: body),
          ),
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            BlocSelector<NotesCubit, NotesState, SyncOverview>(
              selector: (s) => s.overview,
              builder: (context, overview) => SyncStatusBanner(
                overview: overview,
                onSyncNow: cubit.syncNow,
              ),
            ),
            Expanded(
              child: BlocBuilder<NotesCubit, NotesState>(
                buildWhen: (a, b) => a.notes != b.notes || a.status != b.status,
                builder: (context, state) {
                  if (state.status == NotesStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.notes.isEmpty) {
                    return const Center(
                      child: Text('No notes yet. Tap + to add one.'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: cubit.syncNow,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: state.notes.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final note = state.notes[index];
                        return NoteTile(
                          note: note,
                          deviceName: deviceName,
                          onTap: () => showNoteEditor(
                            context,
                            note: note,
                            onSave: (title, body) =>
                                cubit.update(note, title: title, body: body),
                          ),
                          onDelete: () => cubit.delete(note),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
