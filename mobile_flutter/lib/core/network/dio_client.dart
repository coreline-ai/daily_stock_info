import 'package:coreline_stock_ai/shared/providers/app_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  final settings = ref.watch(appSettingsProvider);
  final logger = ref.watch(loggerProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: settings.apiBaseUrl,
      connectTimeout: Duration(seconds: settings.timeoutSeconds),
      receiveTimeout: Duration(seconds: settings.timeoutSeconds),
      sendTimeout: Duration(seconds: settings.timeoutSeconds),
      headers: const {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        logger.d('[REQ] ${options.method} ${options.baseUrl}${options.path}');
        handler.next(options);
      },
      onError: (error, handler) {
        logger.w('[ERR] ${error.requestOptions.path} -> ${error.message}');
        handler.next(error);
      },
    ),
  );

  return dio;
});
