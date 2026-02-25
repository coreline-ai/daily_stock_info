import 'package:coreline_stock_ai/app/router/app_router.dart';
import 'package:coreline_stock_ai/app/theme/app_theme.dart';
import 'package:coreline_stock_ai/shared/models/app_settings.dart';
import 'package:coreline_stock_ai/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BootstrapApp extends ConsumerWidget {
  const BootstrapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(appRouterProvider);

    final themeMode = switch (settings.theme) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Coreline Stock AI',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
