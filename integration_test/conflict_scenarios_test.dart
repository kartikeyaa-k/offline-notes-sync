// Integration test that runs the REAL app on a device (macOS, iOS, Android)
// and plays out the two-device conflict scenarios slowly, with captions, so
// it doubles as a recorded demo.
//
//   flutter test integration_test/conflict_scenarios_test.dart -d macos
//
// Scenarios (Tablet B is offline while both devices edit):
//   1. Same field, B edits LATER  -> B's edit wins on every device.
//   2. Different fields           -> both edits are kept (merge, no conflict).
//   3. A deletes, B edits later   -> the newer edit restores the note.
//
// Uses in-memory storage and simulated connectivity only, so every run starts
// from the same five mock notes and does not touch the app's saved data.
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:offline_items_app/app/app.dart';
import 'package:offline_items_app/app/demo/widgets/device_panel.dart';
import 'package:offline_items_app/app/demo/widgets/server_inspector_panel.dart';
import 'package:offline_items_app/app/di/app_dependencies.dart';

/// Pace of the demo. Raise it to slow the video down.
const _beat = Duration(milliseconds: 1400);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('two devices, one offline: who wins', (tester) async {
    final caption = ValueNotifier<String>('');
    final root = await AppDependencies.init(
      container: GetIt.asNewInstance(),
      storage: InMemoryKeyValueStore(),
      useRealConnectivity: false,
    );

    await tester.pumpWidget(
      _Captioned(
        caption: caption,
        child: OfflineNotesApp(root: root),
      ),
    );
    final h = _DemoDriver(tester, caption);

    // The scenarios need the wide side-by-side layout (both devices visible).
    await h.wait(beats: 1);
    expect(
      find.byType(DevicePanel),
      findsNWidgets(2),
      reason:
          'Window too narrow: run on a screen at least 1000 logical px wide.',
    );

    // Gives the screen recorder time to start (it waits for this line).
    // ignore: avoid_print
    print('SCENARIO_START');
    await h.say(
      'Offline notes · two devices sharing one server. 5 mock notes are loaded.',
      beats: 3,
    );

    // ---------------------------------------------------------------- 1
    await h.say(
      'Scenario 1 · Same field edited on both devices. Tablet B goes OFFLINE.',
    );
    await h.setNetwork(_Device.b, online: false);
    expect(h.inDevice(_Device.b, find.textContaining('Offline')), findsWidgets);

    await h.say(
      '10:00 · Phone A (online) renames "Groceries". It syncs at once.',
    );
    await h.editNote(_Device.a, 'Groceries', title: 'Groceries for the week');
    expect(h.inServer(find.text('Groceries for the week')), findsOneWidget);

    await h.say(
      '10:05 · Tablet B (offline) renames the SAME note later. Saved locally, queued.',
    );
    await h.editNote(_Device.b, 'Groceries', title: 'Groceries + party snacks');
    expect(
      h.inDevice(_Device.b, find.textContaining('queued')),
      findsOneWidget,
    );

    await h.say(
      'Tablet B reconnects. Rule: the most recent EDIT wins, not the last sync.',
    );
    await h.setNetwork(_Device.b, online: true);
    await h.wait(beats: 2);
    for (final device in _Device.values) {
      expect(
        h.inDevice(device, find.text('Groceries + party snacks')),
        findsOneWidget,
      );
    }
    expect(h.inServer(find.text('Groceries + party snacks')), findsOneWidget);

    await h.say(
      'Both devices and the server show B\'s newer title. B\'s history explains why.',
    );
    await h.openHistory(_Device.b);

    // ---------------------------------------------------------------- 2
    await h.say('Scenario 2 · Different fields. Tablet B goes OFFLINE again.');
    await h.setNetwork(_Device.b, online: false);

    await h.say('Phone A edits the TITLE of "Weekend trip".');
    await h.editNote(
      _Device.a,
      'Weekend trip',
      title: 'Weekend trip to the mountains',
    );

    await h.say('Tablet B (offline) edits the TEXT of the same note.');
    await h.editNote(
      _Device.b,
      'Weekend trip',
      body: 'Book hotel, pack charger, sunscreen!',
    );

    await h.say(
      'Tablet B reconnects. Per-field merge: both edits survive, no conflict.',
    );
    await h.setNetwork(_Device.b, online: true);
    await h.wait(beats: 2);
    for (final device in _Device.values) {
      expect(
        h.inDevice(device, find.text('Weekend trip to the mountains')),
        findsOneWidget,
      );
      expect(
        h.inDevice(device, find.text('Book hotel, pack charger, sunscreen!')),
        findsOneWidget,
      );
    }

    // ---------------------------------------------------------------- 3
    await h.say('Scenario 3 · Edit vs delete. Tablet B goes OFFLINE.');
    await h.setNetwork(_Device.b, online: false);

    await h.say('Phone A DELETES "Books to read" (swipe left).');
    await h.swipeDelete(_Device.a, 'Books to read');
    expect(h.inDevice(_Device.a, find.text('Books to read')), findsNothing);

    await h.say('Later, Tablet B (offline) still has it and adds a book.');
    await h.editNote(
      _Device.b,
      'Books to read',
      body: 'Designing Data-Intensive Applications, Clean Architecture',
    );

    await h.say(
      'Tablet B reconnects. The newer edit beats the older delete: the note comes back.',
    );
    await h.setNetwork(_Device.b, online: true);
    await h.wait(beats: 2);
    expect(h.inDevice(_Device.a, find.text('Books to read')), findsOneWidget);
    await h.openHistory(_Device.b);

    await h.say(
      'Result: every device converges to the same data, and no edit is lost silently.',
      beats: 3,
    );
    // ignore: avoid_print
    print('SCENARIO_END');
  });
}

enum _Device { a, b }

/// Drives the demo screen at a watchable pace.
class _DemoDriver {
  _DemoDriver(this.tester, this.caption);

  final WidgetTester tester;
  final ValueNotifier<String> caption;

  Finder _panel(_Device d) => find.byType(DevicePanel).at(d.index);

  /// [matching] inside one device panel.
  Finder inDevice(_Device d, Finder matching) =>
      find.descendant(of: _panel(d), matching: matching);

  /// [matching] inside the server panel.
  Finder inServer(Finder matching) => find.descendant(
    of: find.byType(ServerInspectorPanel),
    matching: matching,
  );

  /// Pumps frames in real time (also lets the mock network and timers run).
  Future<void> wait({double beats = 1}) async {
    final end = DateTime.now().add(_beat * beats);
    while (DateTime.now().isBefore(end)) {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> say(String text, {double beats = 1.5}) async {
    caption.value = text;
    await wait(beats: beats);
  }

  Future<void> setNetwork(_Device d, {required bool online}) async {
    final toggle = inDevice(d, find.byType(Switch));
    final current = tester.widget<Switch>(toggle).value;
    if (current != online) await tester.tap(toggle);
    await wait();
  }

  Future<void> editNote(
    _Device d,
    String noteTitle, {
    String? title,
    String? body,
  }) async {
    await tester.tap(inDevice(d, find.text(noteTitle)));
    await wait(beats: 0.6);
    if (title != null) {
      await _type(find.widgetWithText(TextField, 'Title'), title);
    }
    if (body != null) {
      await _type(find.widgetWithText(TextField, 'Text'), body);
    }
    await wait(beats: 0.4);
    await tester.tap(find.text('Save'));
    await wait();
  }

  Future<void> swipeDelete(_Device d, String noteTitle) async {
    await tester.timedDrag(
      inDevice(d, find.text(noteTitle)),
      const Offset(-500, 0),
      const Duration(milliseconds: 500),
    );
    await wait();
  }

  Future<void> openHistory(_Device d) async {
    await tester.tap(inDevice(d, find.byTooltip('Conflict history')));
    await wait(beats: 2.5);
    await tester.tapAt(const Offset(20, 120)); // tap the scrim to close
    await wait(beats: 0.6);
  }

  /// Types like a person, one character at a time.
  Future<void> _type(Finder field, String text) async {
    await tester.tap(field);
    for (var i = 0; i <= text.length; i++) {
      await tester.enterText(field, text.substring(0, i));
      await tester.pump(const Duration(milliseconds: 30));
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }
}

/// Puts a caption bar under the app so the recording explains itself.
class _Captioned extends StatelessWidget {
  const _Captioned({required this.caption, required this.child});

  final ValueNotifier<String> caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Expanded(child: child),
          ValueListenableBuilder<String>(
            valueListenable: caption,
            builder: (context, text, _) => Container(
              width: double.infinity,
              color: const Color(0xFF111827),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFFFDE68A),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
