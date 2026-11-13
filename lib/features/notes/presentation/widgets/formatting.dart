/// Small, dependency-free display helpers for the notes UI (User Interface).
library;

/// Formats a time as `HH:mm:ss` (local time).
String formatTime(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  final t = time.toLocal();
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Formats a date-time as `d Mon, HH:mm:ss`.
String formatDateTime(DateTime time) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final t = time.toLocal();
  return '${t.day} ${months[t.month - 1]}, ${formatTime(t)}';
}

/// Turns a device id into a display name.
typedef DeviceNameResolver = String Function(String deviceId);

/// Default resolver: shows the id unchanged.
String rawDeviceName(String deviceId) => deviceId;
