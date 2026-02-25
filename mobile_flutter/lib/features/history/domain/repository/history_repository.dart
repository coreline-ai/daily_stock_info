import 'package:coreline_stock_ai/features/history/domain/entities/history_models.dart';
import 'package:dio/dio.dart';

abstract class HistoryRepository {
  Future<BacktestSummaryModel> fetchSummary({
    String? startDate,
    String? endDate,
    double feeBps = 10,
    double slippageBps = 5,
    CancelToken? cancelToken,
  });

  Future<BacktestHistoryPage> fetchHistory({
    String? startDate,
    String? endDate,
    int page = 1,
    int size = 20,
    double feeBps = 10,
    double slippageBps = 5,
    CancelToken? cancelToken,
  });
}
