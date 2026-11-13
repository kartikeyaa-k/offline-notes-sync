import 'package:flutter/material.dart';

/// Step-by-step scenarios to try in the demo, shown from the help button.
Future<void> showScenarioGuide(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Try these scenarios'),
    content: const SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Text(
          'Rule: per field, the most recent EDIT wins — when it was made, not when it synced.\n\n'
          '1. Later offline edit wins\n'
          '   • Turn Tablet B offline.\n'
          '   • On Phone A, edit "Groceries" title → syncs at once.\n'
          '   • On Tablet B, edit the same title (later).\n'
          '   • Turn B online → B\'s title wins on both devices.\n\n'
          '2. Earlier offline edit loses\n'
          '   • B offline, edit a title on B first, then on A.\n'
          '   • B online → A\'s newer title is kept; B shows the conflict.\n\n'
          '3. Different fields merge\n'
          '   • B offline; A edits the title, B edits the text.\n'
          '   • B online → both changes are kept, no conflict.\n\n'
          '4. Edit vs delete\n'
          '   • B offline; A deletes a note; B edits it afterwards.\n'
          '   • B online → the newer edit restores the note everywhere.\n'
          '   • Reverse the order and the newer delete wins.\n\n'
          '5. Both offline\n'
          '   • Turn both off, create/edit on both, turn both on in any order.\n'
          '   • Both converge to the same notes as the server.\n\n'
          'Cloud icons show pending vs synced; the history icon shows every resolved conflict.',
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Got it'),
      ),
    ],
  ),
);
