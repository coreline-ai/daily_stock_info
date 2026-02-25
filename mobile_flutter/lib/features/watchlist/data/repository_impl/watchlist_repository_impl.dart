import 'package:coreline_stock_ai/core/error/app_exception.dart';
import 'package:coreline_stock_ai/core/network/api_endpoints.dart';
import 'package:coreline_stock_ai/features/watchlist/domain/repository/watchlist_repository.dart';
import 'package:dio/dio.dart';

class WatchlistRepositoryImpl implements WatchlistRepository {
  WatchlistRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<String>> getWatchlist({String userKey = 'default', CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get<Object>(
        ApiEndpoints.watchlist,
        queryParameters: {'user_key': userKey},
        cancelToken: cancelToken,
      );
      return _tickersFromPayload(response.data);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel) {
        rethrow;
      }
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<List<String>> addTickers({
    required List<String> tickers,
    String userKey = 'default',
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<Object>(
        ApiEndpoints.watchlist,
        data: {'user_key': userKey, 'tickers': tickers},
        cancelToken: cancelToken,
      );
      return _tickersFromPayload(response.data);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel) {
        rethrow;
      }
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<List<String>> removeTicker({
    required String ticker,
    String userKey = 'default',
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete<Object>(
        ApiEndpoints.watchlistItem(ticker),
        queryParameters: {'user_key': userKey},
        cancelToken: cancelToken,
      );
      return _tickersFromPayload(response.data);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel) {
        rethrow;
      }
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<WatchlistUploadResult> uploadCsv({
    required List<int> bytes,
    required String filename,
    required bool replace,
    String userKey = 'default',
    CancelToken? cancelToken,
  }) async {
    try {
      final formData = FormData.fromMap({
        'user_key': userKey,
        'replace': replace,
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post<Object>(
        ApiEndpoints.watchlistUploadCsv,
        data: formData,
        cancelToken: cancelToken,
        options: Options(contentType: 'multipart/form-data'),
      );

      final map = _asMap(response.data);
      return WatchlistUploadResult(
        tickers: _tickersFromPayload(map),
        uploadedCount: (map['uploadedCount'] as num?)?.toInt() ?? 0,
        invalidRows: (map['invalidRows'] as List<dynamic>? ?? const []).map((e) => (e as num?)?.toInt() ?? -1).toList(growable: false),
        mode: (map['mode'] ?? '').toString(),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel) {
        rethrow;
      }
      throw AppException.fromDio(error);
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  List<String> _tickersFromPayload(Object? payload) {
    final map = _asMap(payload);
    return (map['tickers'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(growable: false);
  }
}
