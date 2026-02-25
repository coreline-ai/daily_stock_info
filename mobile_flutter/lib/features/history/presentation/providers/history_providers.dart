import 'package:coreline_stock_ai/core/network/dio_client.dart';
import 'package:coreline_stock_ai/features/history/data/repository_impl/history_repository_impl.dart';
import 'package:coreline_stock_ai/features/history/domain/entities/history_models.dart';
import 'package:coreline_stock_ai/features/history/domain/repository/history_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryState {
  const HistoryState({
    required this.loading,
    required this.startDate,
    required this.endDate,
    required this.feeBps,
    required this.slippageBps,
    required this.page,
    required this.size,
    required this.summary,
    required this.history,
    required this.error,
  });

  factory HistoryState.initial() => const HistoryState(
        loading: false,
        startDate: null,
        endDate: null,
        feeBps: 10,
        slippageBps: 5,
        page: 1,
        size: 20,
        summary: null,
        history: null,
        error: null,
      );

  final bool loading;
  final String? startDate;
  final String? endDate;
  final double feeBps;
  final double slippageBps;
  final int page;
  final int size;
  final BacktestSummaryModel? summary;
  final BacktestHistoryPage? history;
  final String? error;

  static const _sentinel = Object();

  HistoryState copyWith({
    bool? loading,
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
    double? feeBps,
    double? slippageBps,
    int? page,
    int? size,
    BacktestSummaryModel? summary,
    BacktestHistoryPage? history,
    Object? error = _sentinel,
  }) {
    return HistoryState(
      loading: loading ?? this.loading,
      startDate: startDate == _sentinel ? this.startDate : startDate as String?,
      endDate: endDate == _sentinel ? this.endDate : endDate as String?,
      feeBps: feeBps ?? this.feeBps,
      slippageBps: slippageBps ?? this.slippageBps,
      page: page ?? this.page,
      size: size ?? this.size,
      summary: summary ?? this.summary,
      history: history ?? this.history,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HistoryRepositoryImpl(dio: dio);
});

final historyControllerProvider = StateNotifierProvider<HistoryController, HistoryState>((ref) {
  final repository = ref.watch(historyRepositoryProvider);
  return HistoryController(repository);
});

class HistoryController extends StateNotifier<HistoryState> {
  HistoryController(this._repository) : super(HistoryState.initial());

  final HistoryRepository _repository;
  CancelToken? _token;

  Future<void> load({int? page}) async {
    _token?.cancel();
    final token = CancelToken();
    _token = token;

    final nextPage = page ?? state.page;
    state = state.copyWith(loading: true, page: nextPage, error: null);

    try {
      final summaryFuture = _repository.fetchSummary(
        startDate: state.startDate,
        endDate: state.endDate,
        feeBps: state.feeBps,
        slippageBps: state.slippageBps,
        cancelToken: token,
      );
      final historyFuture = _repository.fetchHistory(
        startDate: state.startDate,
        endDate: state.endDate,
        page: nextPage,
        size: state.size,
        feeBps: state.feeBps,
        slippageBps: state.slippageBps,
        cancelToken: token,
      );

      final results = await Future.wait<Object>([summaryFuture, historyFuture]);
      state = state.copyWith(
        loading: false,
        page: nextPage,
        summary: results[0] as BacktestSummaryModel,
        history: results[1] as BacktestHistoryPage,
        error: null,
      );
    } catch (error) {
      if (error is DioException && (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel)) {
        return;
      }
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> setStartDate(String? value) async {
    state = state.copyWith(startDate: value);
    await load(page: 1);
  }

  Future<void> setEndDate(String? value) async {
    state = state.copyWith(endDate: value);
    await load(page: 1);
  }

  Future<void> setCosts({required double feeBps, required double slippageBps}) async {
    state = state.copyWith(feeBps: feeBps, slippageBps: slippageBps);
    await load(page: 1);
  }

  Future<void> nextPage() async {
    final history = state.history;
    if (history == null) {
      await load(page: 1);
      return;
    }
    final hasNext = history.page * history.size < history.total;
    if (!hasNext) {
      return;
    }
    await load(page: history.page + 1);
  }

  Future<void> prevPage() async {
    final history = state.history;
    if (history == null || history.page <= 1) {
      return;
    }
    await load(page: history.page - 1);
  }

  @override
  void dispose() {
    _token?.cancel();
    super.dispose();
  }
}
