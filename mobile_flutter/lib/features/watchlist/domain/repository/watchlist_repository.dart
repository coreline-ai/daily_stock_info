import 'package:dio/dio.dart';

class WatchlistUploadResult {
  const WatchlistUploadResult({
    required this.tickers,
    required this.uploadedCount,
    required this.invalidRows,
    required this.mode,
  });

  final List<String> tickers;
  final int uploadedCount;
  final List<int> invalidRows;
  final String mode;
}

abstract class WatchlistRepository {
  Future<List<String>> getWatchlist({String userKey = 'default', CancelToken? cancelToken});

  Future<List<String>> addTickers({
    required List<String> tickers,
    String userKey = 'default',
    CancelToken? cancelToken,
  });

  Future<List<String>> removeTicker({
    required String ticker,
    String userKey = 'default',
    CancelToken? cancelToken,
  });

  Future<WatchlistUploadResult> uploadCsv({
    required List<int> bytes,
    required String filename,
    required bool replace,
    String userKey = 'default',
    CancelToken? cancelToken,
  });
}
