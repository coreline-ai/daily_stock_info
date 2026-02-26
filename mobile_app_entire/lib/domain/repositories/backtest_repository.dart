import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/domain/entities/backtest.dart';

abstract interface class BacktestRepository {
  Future<Result<BacktestSummary>> summary(BacktestQuery query);
  Future<Result<BacktestPage>> history(BacktestHistoryQuery query);
}
