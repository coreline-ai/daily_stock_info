import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/domain/entities/backtest.dart';
import 'package:mobile_app_entire/domain/repositories/backtest_repository.dart';

class GetBacktestSummaryUsecase {
  const GetBacktestSummaryUsecase(this._repository);

  final BacktestRepository _repository;

  Future<Result<BacktestSummary>> call(BacktestQuery query) {
    return _repository.summary(query);
  }
}
