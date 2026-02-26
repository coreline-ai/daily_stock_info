import 'package:csv/csv.dart';
import 'package:mobile_app_entire/core/failure/app_failure.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/data/local/app_database.dart';
import 'package:mobile_app_entire/domain/entities/watchlist.dart';
import 'package:mobile_app_entire/domain/repositories/watchlist_repository.dart';

class WatchlistRepositoryImpl implements WatchlistRepository {
  const WatchlistRepositoryImpl(this._database);

  final AppDatabase _database;

  @override
  Future<Result<List<WatchlistEntry>>> addTicker(String ticker) async {
    final normalized = ticker.trim().toUpperCase();
    if (normalized.isEmpty) {
      return Failure(ValidationFailure('티커를 입력해주세요.'));
    }
    try {
      await _database.upsertTicker(normalized);
      return getAll();
    } catch (error) {
      return Failure(StorageFailure('티커 추가에 실패했습니다: $error'));
    }
  }

  @override
  Future<Result<List<WatchlistEntry>>> getAll() async {
    try {
      final rows = await _database.getWatchlist();
      final entries = rows
          .map((row) => WatchlistEntry(ticker: row.ticker, alias: row.alias))
          .toList(growable: false);
      return Success(entries);
    } catch (error) {
      return Failure(StorageFailure('관심종목 조회에 실패했습니다: $error'));
    }
  }

  @override
  Future<Result<List<WatchlistEntry>>> removeTicker(String ticker) async {
    try {
      await _database.deleteTicker(ticker.trim().toUpperCase());
      return getAll();
    } catch (error) {
      return Failure(StorageFailure('티커 삭제에 실패했습니다: $error'));
    }
  }

  @override
  Future<Result<List<WatchlistEntry>>> replaceFromCsv(String csvRaw) async {
    try {
      final rows = const CsvToListConverter().convert(csvRaw);
      if (rows.isEmpty) {
        return Failure(ValidationFailure('CSV 파일이 비어 있습니다.'));
      }

      final tickers = <String>[];
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) {
          continue;
        }
        final value = row.first.toString().trim().toUpperCase();
        if (i == 0 && value == 'TICKER') {
          continue;
        }
        if (value.isNotEmpty) {
          tickers.add(value);
        }
      }
      if (tickers.isEmpty) {
        return Failure(ValidationFailure('CSV에서 유효한 티커를 찾을 수 없습니다.'));
      }

      await _database.replaceWatchlist(tickers.toSet().toList(growable: false));
      return getAll();
    } catch (error) {
      return Failure(StorageFailure('CSV 가져오기에 실패했습니다: $error'));
    }
  }
}
