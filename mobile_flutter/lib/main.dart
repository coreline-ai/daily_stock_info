import 'package:coreline_stock_ai/app/bootstrap.dart';
import 'package:coreline_stock_ai/core/storage/local_cache.dart';
import 'package:coreline_stock_ai/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cache = LocalCache();
  await cache.init();

  runApp(
    ProviderScope(
      overrides: [
        localCacheProvider.overrideWithValue(cache),
      ],
      child: const BootstrapApp(),
    ),
  );
}
