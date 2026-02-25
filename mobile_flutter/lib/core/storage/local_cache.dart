import 'dart:convert';

import 'package:coreline_stock_ai/shared/models/app_settings.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalCache {
  static const _boxName = 'coreline_stock_cache';
  static const _settingsKey = 'app_settings';

  Box<dynamic>? _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  bool get isReady => _box != null;

  Future<void> saveSettings(AppSettings settings) async {
    await _box?.put(_settingsKey, settings.toRaw());
  }

  AppSettings? loadSettings() {
    final raw = _box?.get(_settingsKey);
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    try {
      return AppSettings.fromRaw(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> putDashboardPayload({required String key, required Map<String, dynamic> payload}) async {
    await _box?.put('dashboard:$key', jsonEncode(payload));
  }

  Map<String, dynamic>? getDashboardPayload(String key) {
    final raw = _box?.get('dashboard:$key');
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastTriggerIso(String value) async {
    await _box?.put('last_trigger', value);
  }

  String? getLastTriggerIso() {
    final raw = _box?.get('last_trigger');
    return raw is String ? raw : null;
  }

  Future<void> clearTransientCache() async {
    final keys = _box?.keys
            .where((item) => item.toString().startsWith('dashboard:'))
            .toList(growable: false) ??
        const <dynamic>[];
    await _box?.deleteAll(keys);
  }
}
