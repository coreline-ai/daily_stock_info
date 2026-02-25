import 'package:coreline_stock_ai/features/dashboard/domain/entities/dashboard_models.dart';
import 'package:dio/dio.dart';

abstract class AnalysisRepository {
  Future<StrategyValidation> getValidation({
    required StrategyKind strategy,
    required String date,
    CancelToken? cancelToken,
  });
}
