import 'dart:convert';

enum AppThemePreference { system, light, dark }

class AppSettings {
  const AppSettings({
    required this.apiBaseUrl,
    required this.timeoutSeconds,
    required this.theme,
  });

  final String apiBaseUrl;
  final int timeoutSeconds;
  final AppThemePreference theme;

  factory AppSettings.defaults() {
    return AppSettings(
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000'),
      timeoutSeconds: 15,
      theme: AppThemePreference.system,
    );
  }

  AppSettings copyWith({
    String? apiBaseUrl,
    int? timeoutSeconds,
    AppThemePreference? theme,
  }) {
    return AppSettings(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      theme: theme ?? this.theme,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiBaseUrl': apiBaseUrl,
      'timeoutSeconds': timeoutSeconds,
      'theme': theme.name,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawTheme = (json['theme'] ?? AppThemePreference.system.name).toString();
    final theme = AppThemePreference.values.firstWhere(
      (value) => value.name == rawTheme,
      orElse: () => AppThemePreference.system,
    );
    return AppSettings(
      apiBaseUrl: (json['apiBaseUrl'] ?? AppSettings.defaults().apiBaseUrl).toString(),
      timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt() ?? 15,
      theme: theme,
    );
  }

  String toRaw() => jsonEncode(toJson());

  factory AppSettings.fromRaw(String raw) {
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
