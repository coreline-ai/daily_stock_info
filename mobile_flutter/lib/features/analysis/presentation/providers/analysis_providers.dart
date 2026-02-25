import 'package:coreline_stock_ai/core/network/dio_client.dart';
import 'package:coreline_stock_ai/core/util/date_kst.dart';
import 'package:coreline_stock_ai/features/analysis/data/repository_impl/analysis_repository_impl.dart';
import 'package:coreline_stock_ai/features/analysis/domain/repository/analysis_repository.dart';
import 'package:coreline_stock_ai/features/dashboard/domain/entities/dashboard_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalysisState {
  const AnalysisState({
    required this.date,
    required this.strategy,
    required this.loading,
    required this.validation,
    required this.error,
  });

  factory AnalysisState.initial() => AnalysisState(
        date: DateKst.todayIso(),
        strategy: StrategyKind.intraday,
        loading: false,
        validation: null,
        error: null,
      );

  final String date;
  final StrategyKind strategy;
  final bool loading;
  final StrategyValidation? validation;
  final String? error;

  AnalysisState copyWith({
    String? date,
    StrategyKind? strategy,
    bool? loading,
    StrategyValidation? validation,
    Object? error = _sentinel,
  }) {
    return AnalysisState(
      date: date ?? this.date,
      strategy: strategy ?? this.strategy,
      loading: loading ?? this.loading,
      validation: validation ?? this.validation,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AnalysisRepositoryImpl(dio: dio);
});

final analysisControllerProvider = StateNotifierProvider<AnalysisController, AnalysisState>((ref) {
  final repository = ref.watch(analysisRepositoryProvider);
  return AnalysisController(repository);
});

class AnalysisController extends StateNotifier<AnalysisState> {
  AnalysisController(this._repository) : super(AnalysisState.initial());

  final AnalysisRepository _repository;
  CancelToken? _cancelToken;

  Future<void> load() async {
    _cancelToken?.cancel();
    final token = CancelToken();
    _cancelToken = token;

    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repository.getValidation(
        strategy: state.strategy,
        date: state.date,
        cancelToken: token,
      );
      state = state.copyWith(loading: false, validation: result, error: null);
    } catch (error) {
      if (error is DioException && (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel)) {
        return;
      }
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> setDate(DateTime date) async {
    final next = date.toIso8601String().split('T').first;
    state = state.copyWith(date: next);
    await load();
  }

  Future<void> setStrategy(StrategyKind strategy) async {
    state = state.copyWith(strategy: strategy);
    await load();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }
}
