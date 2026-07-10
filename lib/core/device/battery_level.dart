import 'package:battery_plus/battery_plus.dart';

Future<int?> readBatteryPercent() async {
  try {
    final level = await Battery().batteryLevel;
    if (level < 0 || level > 100) return null;
    return level;
  } catch (_) {
    return null;
  }
}
