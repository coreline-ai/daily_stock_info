import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/domain/entities/watchlist.dart';

abstract interface class WatchlistRepository {
  Future<Result<List<WatchlistEntry>>> getAll();
  Future<Result<List<WatchlistEntry>>> addTicker(String ticker);
  Future<Result<List<WatchlistEntry>>> removeTicker(String ticker);
  Future<Result<List<WatchlistEntry>>> replaceFromCsv(String csvRaw);
}
