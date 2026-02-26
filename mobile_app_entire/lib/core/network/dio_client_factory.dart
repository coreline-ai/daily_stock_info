import 'package:dio/dio.dart';
import 'package:mobile_app_entire/core/logger/app_logger.dart';

class DioClientFactory {
  const DioClientFactory(this._logger);

  final AppLogger _logger;

  Dio create({
    required String baseUrl,
    Duration timeout = const Duration(seconds: 15),
    Map<String, String>? headers,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        headers: headers ?? const {},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.d('[REQ] ${options.method} ${options.uri}');
          handler.next(options);
        },
        onError: (error, handler) {
          _logger.w(
            '[ERR] ${error.requestOptions.method} ${error.requestOptions.uri} (${error.response?.statusCode})',
          );
          handler.next(error);
        },
      ),
    );
    return dio;
  }
}
