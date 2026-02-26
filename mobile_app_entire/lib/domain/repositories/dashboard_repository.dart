import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/domain/entities/dashboard.dart';

abstract interface class DashboardRepository {
  Future<Result<DashboardSnapshot>> load(DashboardQuery query);
}
