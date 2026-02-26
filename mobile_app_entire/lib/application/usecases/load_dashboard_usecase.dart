import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/domain/entities/dashboard.dart';
import 'package:mobile_app_entire/domain/repositories/dashboard_repository.dart';

class LoadDashboardUsecase {
  const LoadDashboardUsecase(this._repository);

  final DashboardRepository _repository;

  Future<Result<DashboardSnapshot>> call(DashboardQuery query) {
    return _repository.load(query);
  }
}
