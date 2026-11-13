import 'package:flutter/material.dart';

import 'package:offline_items_app/features/notes/domain/entities/note.dart';

/// Callback that saves the editor's content. Returns `true` when saved, so
/// the dialog can stay open (keeping the user's text) on a failure.
typedef SaveNote = Future<bool> Function(String title, String body);

/// Shows the note editor. [note] is `null` when creating.
Future<void> showNoteEditor(
  BuildContext context, {
  required SaveNote onSave,
  Note? note,
}) => showDialog<void>(
  context: context,
  builder: (_) => _NoteEditorDialog(note: note, onSave: onSave),
);

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({required this.note, required this.onSave});

  final Note? note;
  final SaveNote onSave;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _body = TextEditingController(text: widget.note?.body ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await widget.onSave(_title.text, _body.text);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? 'New note' : 'Edit note'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: widget.note == null,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Text',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
