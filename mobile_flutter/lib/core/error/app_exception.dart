import 'package:dio/dio.dart';

class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;

  static AppException fromDio(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        final message = detail is String
            ? detail
            : detail is Map<String, dynamic>
                ? (detail['message']?.toString() ?? detail.toString())
                : null;
        if (message != null && message.isNotEmpty) {
          return AppException(message, statusCode: statusCode);
        }
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return AppException('요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.');
      }
      if (error.type == DioExceptionType.connectionError) {
        return AppException('네트워크 연결 오류입니다. API 주소/서버 상태를 확인해주세요.');
      }
      return AppException('요청 처리 중 오류가 발생했습니다. (${statusCode ?? '-'})', statusCode: statusCode);
    }

    return AppException(error.toString());
  }
}
