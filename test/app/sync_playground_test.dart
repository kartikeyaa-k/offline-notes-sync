// End-to-end widget test of the demo: the real app, two simulated devices,
// the mock server and in-memory storage. Takes Tablet B offline, edits the
// same note on both devices (B later), reconnects B, and checks that B's
// newer edit wins on both devices.
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:offline_items_app/app/app.dart';
import 'package:offline_items_app/app/di/app_dependencies.dart';

void main() {
  testWidgets('later offline edit wins after reconnecting', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final root = await AppDependencies.init(
      container: GetIt.asNewInstance(),
      storage: InMemoryKeyValueStore(),
      useRealConnectivity: false,
    );

    Future<void> settle() async {
      // Mock network latency is 350 ms per hop; give every sync time to finish.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await tester.pumpWidget(OfflineNotesApp(root: root));
    await settle();

    // Seeded mock data is visible on Phone A, Tablet B and the server panel.
    expect(find.text('Groceries'), findsNWidgets(3));
    expect(find.text('Weekend trip'), findsNWidgets(3));

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(2));

    Future<void> editTitle(int deviceIndex, String from, String to) async {
      await tester.tap(find.text(from).at(deviceIndex));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), to);
      await tester.tap(find.text('Save'));
      await settle();
    }

    // Tablet B goes offline.
    await tester.tap(switches.at(1));
    await settle();
    expect(find.textContaining('Offline'), findsWidgets);

    // Phone A edits first (online, syncs at once).
    await editTitle(0, 'Groceries', 'Groceries from A');
    // Tablet B edits the same title later, offline.
    await tester.pump(const Duration(milliseconds: 10));
    // Only B still shows the old title (B is offline), so it is the single match.
    await editTitle(0, 'Groceries', 'Groceries from B');
    expect(find.textContaining('1 change(s) queued'), findsOneWidget);

    // B reconnects: its edit is newer, so it wins everywhere.
    await tester.tap(switches.at(1));
    await settle();
    expect(find.text('Groceries from B'), findsNWidgets(3));
    expect(find.text('Groceries from A'), findsNothing);

    // Dispose devices before the test ends.
    await tester.pumpWidget(const SizedBox());
    await settle();
  });
}
