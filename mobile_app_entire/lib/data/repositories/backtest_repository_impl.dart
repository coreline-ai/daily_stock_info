import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/failure/app_failure.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/data/local/app_database.dart';
import 'package:mobile_app_entire/domain/entities/backtest.dart';
import 'package:mobile_app_entire/domain/repositories/backtest_repository.dart';
import 'package:mobile_app_entire/domain/services/backtest_math_service.dart';

class BacktestRepositoryImpl implements BacktestRepository {
  const BacktestRepositoryImpl({
    required AppDatabase database,
    required BacktestMathService backtestMathService,
  }) : _database = database,
       _backtestMathService = backtestMathService;

  final AppDatabase _database;
  final BacktestMathService _backtestMathService;

  @override
  Future<Result<BacktestPage>> history(BacktestHistoryQuery query) async {
    try {
      final rows = await _database.listBacktestRows(
        page: query.page,
        size: query.size,
        startDate: query.startDate,
        endDate: query.endDate,
      );
      final total = await _database.countBacktestRows(
        startDate: query.startDate,
        endDate: query.endDate,
      );

      final items = rows
          .map(
            (row) => BacktestItem(
              tradeDate: row.tradeDate,
              ticker: row.ticker,
              companyName: row.companyName,
              entryPrice: row.entryPrice,
              retT1: row.retT1,
              retT3: row.retT3,
              retT5: row.retT5,
              currentPrice: row.currentPrice,
            ),
          )
          .toList(growable: false);

      return Success(
        BacktestPage(
          items: items,
          page: query.page,
          size: query.size,
          total: total,
        ),
      );
    } catch (error) {
      return Failure(StorageFailure('백테스트 히스토리 조회에 실패했습니다: $error'));
    }
  }

  @override
  Future<Result<BacktestSummary>> summary(BacktestQuery query) async {
    try {
      final rows = await _database.listAllBacktestRows(
        startDate: query.startDate,
        endDate: query.endDate,
      );

      final t1 = rows.map((e) => e.retT1).toList(growable: false);
      final t3 = rows.map((e) => e.retT3).toList(growable: false);
      final t5 = rows.map((e) => e.retT5).toList(growable: false);

      return Success(
        BacktestSummary(
          count: rows.length,
          avgRetT1: _backtestMathService.average(t1),
          avgRetT3: _backtestMathService.average(t3),
          avgRetT5: _backtestMathService.average(t5),
          winRateT1: _backtestMathService.winRate(t1),
          winRateT3: _backtestMathService.winRate(t3),
          winRateT5: _backtestMathService.winRate(t5),
          mddT1: _backtestMathService.mdd(t1),
          mddT3: _backtestMathService.mdd(t3),
          mddT5: _backtestMathService.mdd(t5),
        ),
      );
    } catch (error) {
      return Failure(StorageFailure('백테스트 요약 조회에 실패했습니다: $error'));
    }
  }
}
