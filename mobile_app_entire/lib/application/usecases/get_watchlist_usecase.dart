import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/domain/entities/watchlist.dart';
import 'package:mobile_app_entire/domain/repositories/watchlist_repository.dart';

class GetWatchlistUsecase {
  const GetWatchlistUsecase(this._repository);

  final WatchlistRepository _repository;

  Future<Result<List<WatchlistEntry>>> call() {
    return _repository.getAll();
  }
}
