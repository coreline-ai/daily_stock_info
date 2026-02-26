import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/domain/entities/backtest.dart';
import 'package:mobile_app_entire/domain/repositories/backtest_repository.dart';

class GetBacktestHistoryUsecase {
  const GetBacktestHistoryUsecase(this._repository);

  final BacktestRepository _repository;

  Future<Result<BacktestPage>> call(BacktestHistoryQuery query) {
    return _repository.history(query);
  }
}
