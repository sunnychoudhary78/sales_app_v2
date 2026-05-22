import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shared_preferences_provider.dart';
import '../storage/storage_keys.dart';

const Color _defaultPrimary = Color(0xFF2563EB); // Blue 600

class AppThemeNotifier extends Notifier<Color> {
  @override
  Color build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final v = prefs.getInt(StorageKeys.primarySeedColor);
    if (v == null) return _defaultPrimary;
    return Color(v);
  }

  void setPrimaryColor(Color color) {
    state = color;
    unawaited(
      ref.read(sharedPreferencesProvider).setInt(
            StorageKeys.primarySeedColor,
            color.toARGB32(),
          ),
    );
  }
}

final appThemeProvider = NotifierProvider<AppThemeNotifier, Color>(
  AppThemeNotifier.new,
);
