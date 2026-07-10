import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'battery_level.dart';

Future<Map<String, dynamic>?> readDeviceInfoPayload() async {
  final payload = <String, dynamic>{};

  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version.trim();
    final build = packageInfo.buildNumber.trim();
    if (version.isNotEmpty) payload['app_version'] = version;
    if (build.isNotEmpty) payload['app_build'] = build;
  } catch (_) {}

  try {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      payload['platform'] = 'android';
      _putIfNotEmpty(payload, 'manufacturer', info.manufacturer);
      _putIfNotEmpty(payload, 'model', info.model);
      _putIfNotEmpty(payload, 'brand', info.brand);
      _putIfNotEmpty(payload, 'device_name', info.device);
      _putIfNotEmpty(payload, 'os_version', info.version.release);
      _putIfNotEmpty(payload, 'device_id', info.id);
    } else if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      payload['platform'] = 'ios';
      _putIfNotEmpty(payload, 'manufacturer', 'Apple');
      _putIfNotEmpty(payload, 'model', info.model);
      _putIfNotEmpty(payload, 'device_name', info.name);
      _putIfNotEmpty(payload, 'os_version', info.systemVersion);
      _putIfNotEmpty(payload, 'device_id', info.identifierForVendor);
    }
  } catch (_) {}

  try {
    final batteryPercent = await readBatteryPercent();
    if (batteryPercent != null) {
      payload['battery_percent'] = batteryPercent;
    }
  } catch (_) {}

  return payload.isEmpty ? null : payload;
}

void _putIfNotEmpty(Map<String, dynamic> map, String key, String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return;
  map[key] = trimmed;
}
