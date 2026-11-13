import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'bloc/demo_session_cubit.dart';
import 'widgets/device_panel.dart';
import 'widgets/scenario_guide.dart';
import 'widgets/server_inspector_panel.dart';

/// The demo home: two simulated devices and the mock server, side by side on
/// wide screens or as tabs on phones.
///
/// Each device panel is a normal notes screen with its own local database
/// and its own network switch, so you can reproduce "one device offline, one
/// online, both edit" on a single screen.
class SyncPlaygroundScreen extends StatelessWidget {
  const SyncPlaygroundScreen({super.key, required this.root});

  /// Root dependency container.
  final GetIt root;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DemoSessionCubit(root)..start(),
      child: BlocBuilder<DemoSessionCubit, DemoSessionState>(
        builder: (context, state) => switch (state) {
          DemoSessionLoading() => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          DemoSessionReady(:final devices, :final generation) => _Playground(
            key: ValueKey(generation),
            panels: [
              for (final device in devices) DevicePanel(device: device),
              ServerInspectorPanel(root: root),
            ],
          ),
        },
      ),
    );
  }
}

class _Playground extends StatelessWidget {
  const _Playground({super.key, required this.panels});

  /// Device A, device B, server.
  final List<Widget> panels;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final actions = [
      IconButton(
        tooltip: 'Scenarios to try',
        icon: const Icon(Icons.help_outline),
        onPressed: () => showScenarioGuide(context),
      ),
      IconButton(
        tooltip: 'Reset demo (wipe devices and server, reload mock data)',
        icon: const Icon(Icons.restart_alt),
        onPressed: () => context.read<DemoSessionCubit>().reset(),
      ),
    ];
    const title = Text('Offline notes — sync playground');

    if (width >= 1000) {
      return Scaffold(
        appBar: AppBar(title: title, actions: actions),
        body: Row(
          children: [
            Expanded(flex: 3, child: panels[0]),
            const VerticalDivider(width: 1),
            Expanded(flex: 3, child: panels[1]),
            const VerticalDivider(width: 1),
            Expanded(flex: 2, child: panels[2]),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: panels.length,
      child: Scaffold(
        appBar: AppBar(
          title: title,
          actions: actions,
          bottom: TabBar(
            tabs: [
              for (final d in demoDevices)
                Tab(icon: Icon(d.icon), text: d.name),
              const Tab(icon: Icon(Icons.dns_outlined), text: 'Server'),
            ],
          ),
        ),
        // Keep both devices alive while switching tabs.
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final p in panels) _KeepAlive(child: p)],
        ),
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
