import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/notes/presentation/screens/notes_screen.dart';
import '../../di/device_scope.dart';
import '../bloc/demo_session_cubit.dart';
import '../bloc/device_network_cubit.dart';

/// One simulated device: a coloured frame around a regular [NotesScreen],
/// with a Wi-Fi switch in its app bar to take this device offline.
class DevicePanel extends StatelessWidget {
  const DevicePanel({super.key, required this.device});

  /// The device to show.
  final DeviceScope device;

  @override
  Widget build(BuildContext context) {
    final profile = device.profile;
    return BlocProvider(
      create: (_) => DeviceNetworkCubit(device.network),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: profile.color, width: 4)),
        ),
        child: NotesScreen(
          createCubit: device.createNotesCubit,
          title: profile.name,
          deviceName: demoDeviceName,
          appBarActions: const [_NetworkSwitch()],
        ),
      ),
    );
  }
}

class _NetworkSwitch extends StatelessWidget {
  const _NetworkSwitch();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceNetworkCubit, DeviceNetworkState>(
      builder: (context, state) {
        final label = state.switchOn
            ? (state.isOnline ? 'Online' : 'No real network')
            : 'Offline';
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(state.isOnline ? Icons.wifi : Icons.wifi_off, size: 18),
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Switch(
                value: state.switchOn,
                onChanged: context.read<DeviceNetworkCubit>().setNetwork,
              ),
            ],
          ),
        );
      },
    );
  }
}
