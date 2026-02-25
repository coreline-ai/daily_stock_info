import 'dart:async';

import 'package:coreline_stock_ai/core/storage/local_cache.dart';
import 'package:coreline_stock_ai/shared/models/app_settings.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localCacheProvider = Provider<LocalCache>((ref) {
  throw UnimplementedError('localCacheProvider must be overridden in main()');
});

final loggerProvider = Provider<Logger>((ref) {
  return Logger(printer: PrettyPrinter(methodCount: 0, lineLength: 100));
});

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier(this._cache) : super(AppSettings.defaults()) {
    unawaited(_load());
  }

  final LocalCache _cache;

  Future<void> _load() async {
    final cached = _cache.loadSettings();
    if (cached != null) {
      state = cached;
    }
  }

  Future<void> updateApiBaseUrl(String value) async {
    state = state.copyWith(apiBaseUrl: value.trim());
    await _cache.saveSettings(state);
  }

  Future<void> updateTimeoutSeconds(int value) async {
    state = state.copyWith(timeoutSeconds: value);
    await _cache.saveSettings(state);
  }

  Future<void> updateTheme(AppThemePreference value) async {
    state = state.copyWith(theme: value);
    await _cache.saveSettings(state);
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final cache = ref.watch(localCacheProvider);
  return AppSettingsNotifier(cache);
});
