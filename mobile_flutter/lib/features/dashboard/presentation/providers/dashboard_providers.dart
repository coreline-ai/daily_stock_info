import 'dart:convert';

import 'package:coreline_stock_ai/core/storage/local_cache.dart';
import 'package:coreline_stock_ai/core/network/dio_client.dart';
import 'package:coreline_stock_ai/core/util/date_kst.dart';
import 'package:coreline_stock_ai/features/dashboard/data/repository_impl/dashboard_repository_impl.dart';
import 'package:coreline_stock_ai/features/dashboard/domain/entities/dashboard_models.dart';
import 'package:coreline_stock_ai/features/dashboard/domain/repository/dashboard_repository.dart';
import 'package:coreline_stock_ai/features/dashboard/domain/usecase/load_dashboard_usecase.dart';
import 'package:coreline_stock_ai/shared/providers/app_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

enum StrategyPreset { balanced, aggressive, defensive, custom }

class DashboardState {
  const DashboardState({
    required this.initialized,
    required this.isLoading,
    required this.isFromCache,
    required this.selectedDateIso,
    required this.selectedStrategy,
    required this.effectiveStrategy,
    required this.preset,
    required this.weights,
    required this.showIntradayExtra,
    required this.customTickerInput,
    required this.customTickers,
    required this.searchQuery,
    required this.strategyStatus,
    required this.marketOverview,
    required this.candidates,
    required this.intradayExtraCandidates,
    required this.validation,
    required this.marketInsight,
    required this.stockDetails,
    required this.detailLoadingTickers,
    required this.expandedTickers,
    required this.lastTriggerIso,
    required this.warning,
    required this.error,
  });

  factory DashboardState.initial() {
    return DashboardState(
      initialized: false,
      isLoading: false,
      isFromCache: false,
      selectedDateIso: DateKst.todayIso(),
      selectedStrategy: StrategyKind.premarket,
      effectiveStrategy: StrategyKind.premarket,
      preset: StrategyPreset.balanced,
      weights: StrategyWeights.balanced,
      showIntradayExtra: true,
      customTickerInput: '',
      customTickers: const [],
      searchQuery: '',
      strategyStatus: null,
      marketOverview: null,
      candidates: const [],
      intradayExtraCandidates: const [],
      validation: null,
      marketInsight: null,
      stockDetails: const {},
      detailLoadingTickers: const {},
      expandedTickers: const {},
      lastTriggerIso: null,
      warning: null,
      error: null,
    );
  }

  final bool initialized;
  final bool isLoading;
  final bool isFromCache;
  final String selectedDateIso;
  final StrategyKind selectedStrategy;
  final StrategyKind effectiveStrategy;
  final StrategyPreset preset;
  final StrategyWeights weights;
  final bool showIntradayExtra;
  final String customTickerInput;
  final List<String> customTickers;
  final String searchQuery;
  final StrategyStatus? strategyStatus;
  final MarketOverview? marketOverview;
  final List<StockCandidate> candidates;
  final List<StockCandidate> intradayExtraCandidates;
  final StrategyValidation? validation;
  final MarketInsight? marketInsight;
  final Map<String, StockDetail> stockDetails;
  final Set<String> detailLoadingTickers;
  final Set<String> expandedTickers;
  final String? lastTriggerIso;
  final String? warning;
  final String? error;

  static const _sentinel = Object();

  DashboardState copyWith({
    bool? initialized,
    bool? isLoading,
    bool? isFromCache,
    String? selectedDateIso,
    StrategyKind? selectedStrategy,
    StrategyKind? effectiveStrategy,
    StrategyPreset? preset,
    StrategyWeights? weights,
    bool? showIntradayExtra,
    String? customTickerInput,
    List<String>? customTickers,
    String? searchQuery,
    StrategyStatus? strategyStatus,
    MarketOverview? marketOverview,
    List<StockCandidate>? candidates,
    List<StockCandidate>? intradayExtraCandidates,
    Object? validation = _sentinel,
    Object? marketInsight = _sentinel,
    Map<String, StockDetail>? stockDetails,
    Set<String>? detailLoadingTickers,
    Set<String>? expandedTickers,
    Object? lastTriggerIso = _sentinel,
    Object? warning = _sentinel,
    Object? error = _sentinel,
  }) {
    return DashboardState(
      initialized: initialized ?? this.initialized,
      isLoading: isLoading ?? this.isLoading,
      isFromCache: isFromCache ?? this.isFromCache,
      selectedDateIso: selectedDateIso ?? this.selectedDateIso,
      selectedStrategy: selectedStrategy ?? this.selectedStrategy,
      effectiveStrategy: effectiveStrategy ?? this.effectiveStrategy,
      preset: preset ?? this.preset,
      weights: weights ?? this.weights,
      showIntradayExtra: showIntradayExtra ?? this.showIntradayExtra,
      customTickerInput: customTickerInput ?? this.customTickerInput,
      customTickers: customTickers ?? this.customTickers,
      searchQuery: searchQuery ?? this.searchQuery,
      strategyStatus: strategyStatus ?? this.strategyStatus,
      marketOverview: marketOverview ?? this.marketOverview,
      candidates: candidates ?? this.candidates,
      intradayExtraCandidates: intradayExtraCandidates ?? this.intradayExtraCandidates,
      validation: validation == _sentinel ? this.validation : validation as StrategyValidation?,
      marketInsight: marketInsight == _sentinel ? this.marketInsight : marketInsight as MarketInsight?,
      stockDetails: stockDetails ?? this.stockDetails,
      detailLoadingTickers: detailLoadingTickers ?? this.detailLoadingTickers,
      expandedTickers: expandedTickers ?? this.expandedTickers,
      lastTriggerIso: lastTriggerIso == _sentinel ? this.lastTriggerIso : lastTriggerIso as String?,
      warning: warning == _sentinel ? this.warning : warning as String?,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  String cacheKey() {
    final custom = customTickers.join(',');
    return '$selectedDateIso|${selectedStrategy.value}|${weights.cacheKey()}|$custom|${showIntradayExtra ? 1 : 0}';
  }

  List<StockCandidate> filteredCandidates() {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return candidates;
    }
    return candidates
        .where(
          (item) => item.name.toLowerCase().contains(query) ||
              item.code.toLowerCase().contains(query) ||
              (item.sector ?? '').toLowerCase().contains(query),
        )
        .toList(growable: false);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return DashboardRepositoryImpl(dio: dio);
});

final loadDashboardUsecaseProvider = Provider<LoadDashboardUsecase>((ref) {
  final repository = ref.watch(dashboardRepositoryProvider);
  return LoadDashboardUsecase(repository);
});

final dashboardControllerProvider = StateNotifierProvider<DashboardController, DashboardState>((ref) {
  final usecase = ref.watch(loadDashboardUsecaseProvider);
  final repository = ref.watch(dashboardRepositoryProvider);
  final cache = ref.watch(localCacheProvider);
  final logger = ref.watch(loggerProvider);
  return DashboardController(
    usecase: usecase,
    repository: repository,
    cache: cache,
    logger: logger,
  );
});

class DashboardController extends StateNotifier<DashboardState> {
  DashboardController({
    required LoadDashboardUsecase usecase,
    required DashboardRepository repository,
    required LocalCache cache,
    required Logger logger,
  })  : _usecase = usecase,
        _repository = repository,
        _cache = cache,
        _logger = logger,
        super(DashboardState.initial()) {
    final lastTrigger = _cache.getLastTriggerIso();
    if (lastTrigger != null && lastTrigger.isNotEmpty) {
      state = state.copyWith(lastTriggerIso: lastTrigger);
    }
  }

  final LoadDashboardUsecase _usecase;
  final DashboardRepository _repository;
  final LocalCache _cache;
  final Logger _logger;

  CancelToken? _loadCancelToken;
  int _requestSeq = 0;

  Future<void> loadInitial() async {
    if (state.initialized) {
      return;
    }
    await reload(reason: 'initial');
  }

  Future<void> reload({
    bool forceRefresh = false,
    String reason = 'manual',
  }) async {
    final requestId = ++_requestSeq;
    _loadCancelToken?.cancel();
    final cancelToken = CancelToken();
    _loadCancelToken = cancelToken;

    final now = DateTime.now().toUtc();
    final triggerIso = now.toIso8601String();
    await _cache.setLastTriggerIso(triggerIso);

    state = state.copyWith(
      initialized: true,
      isLoading: true,
      isFromCache: false,
      lastTriggerIso: triggerIso,
      warning: null,
      error: null,
    );

    final refreshToken = '${now.microsecondsSinceEpoch}-$reason';

    try {
      final result = await _usecase.call(
        date: state.selectedDateIso,
        preferredStrategy: state.selectedStrategy,
        weights: state.weights,
        includeIntradayExtra: state.showIntradayExtra,
        forceRefresh: forceRefresh,
        userKey: 'default',
        customTickers: state.customTickers,
        refreshToken: refreshToken,
        cancelToken: cancelToken,
      );

      if (requestId != _requestSeq) {
        return;
      }

      final unavailableMessage = result.selectedStrategy == state.selectedStrategy
          ? null
          : result.strategyStatus.messages[state.selectedStrategy.value];

      state = state.copyWith(
        isLoading: false,
        isFromCache: false,
        strategyStatus: result.strategyStatus,
        effectiveStrategy: result.selectedStrategy,
        marketOverview: result.marketOverview,
        candidates: result.candidates,
        intradayExtraCandidates: result.intradayExtra,
        validation: result.validation,
        marketInsight: result.marketInsight,
        warning: unavailableMessage,
        error: null,
      );

      final payload = DashboardCachePayload(
        generatedAtIso: triggerIso,
        strategyStatus: result.strategyStatus,
        selectedStrategy: result.selectedStrategy,
        marketOverview: result.marketOverview,
        candidates: result.candidates,
        validation: result.validation,
        marketInsight: result.marketInsight,
        intradayExtra: result.intradayExtra,
      );
      await _cache.putDashboardPayload(key: state.cacheKey(), payload: jsonDecode(payload.toRaw()) as Map<String, dynamic>);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        if (requestId == _requestSeq) {
          state = state.copyWith(isLoading: false);
        }
        return;
      }
      _logger.w('dashboard reload failed: ${error.message}');
      await _restoreFromCacheOrError(error.toString(), requestId: requestId);
    } catch (error) {
      _logger.w('dashboard reload failed: $error');
      await _restoreFromCacheOrError(error.toString(), requestId: requestId);
    }
  }

  Future<void> _restoreFromCacheOrError(String message, {required int requestId}) async {
    final cached = _cache.getDashboardPayload(state.cacheKey());
    if (cached != null) {
      try {
        final payload = DashboardCachePayload.fromJson(cached);
        if (requestId != _requestSeq) {
          return;
        }
        state = state.copyWith(
          isLoading: false,
          isFromCache: true,
          strategyStatus: payload.strategyStatus,
          effectiveStrategy: payload.selectedStrategy ?? state.selectedStrategy,
          marketOverview: payload.marketOverview,
          candidates: payload.candidates,
          intradayExtraCandidates: payload.intradayExtra,
          validation: payload.validation,
          marketInsight: payload.marketInsight,
          warning: '네트워크 오류로 저장된 데이터가 표시됩니다.',
          error: null,
        );
        return;
      } catch (_) {
        // Keep falling through to error rendering.
      }
    }
    if (requestId != _requestSeq) {
      return;
    }
    state = state.copyWith(
      isLoading: false,
      isFromCache: false,
      error: message,
    );
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  Future<void> setDate(DateTime date) async {
    final next = date.toIso8601String().split('T').first;
    state = state.copyWith(selectedDateIso: next);
    await reload(reason: 'date-change');
  }

  Future<void> setStrategy(StrategyKind strategy) async {
    state = state.copyWith(selectedStrategy: strategy);
    await reload(reason: 'strategy-change');
  }

  Future<void> setPreset(StrategyPreset preset) async {
    final nextWeights = switch (preset) {
      StrategyPreset.balanced => StrategyWeights.balanced,
      StrategyPreset.aggressive => StrategyWeights.aggressive,
      StrategyPreset.defensive => StrategyWeights.defensive,
      StrategyPreset.custom => state.weights,
    };
    state = state.copyWith(preset: preset, weights: nextWeights);
    await reload(reason: 'preset-change');
  }

  Future<void> setShowIntradayExtra(bool value) async {
    state = state.copyWith(showIntradayExtra: value);
    await reload(reason: 'intraday-extra-toggle');
  }

  void setCustomTickerInput(String value) {
    state = state.copyWith(customTickerInput: value);
  }

  Future<void> applyCustomTickers() async {
    final tickers = state.customTickerInput
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    state = state.copyWith(customTickers: tickers);
    await reload(reason: 'custom-tickers');
  }

  Future<void> manualRefresh() async {
    await reload(forceRefresh: state.selectedStrategy == StrategyKind.intraday, reason: 'manual-refresh');
  }

  Future<void> toggleExpanded(String ticker) async {
    final nextExpanded = Set<String>.from(state.expandedTickers);
    if (nextExpanded.contains(ticker)) {
      nextExpanded.remove(ticker);
      state = state.copyWith(expandedTickers: nextExpanded);
      return;
    }

    nextExpanded.add(ticker);
    state = state.copyWith(expandedTickers: nextExpanded);
    if (state.stockDetails.containsKey(ticker)) {
      return;
    }
    await loadStockDetail(ticker);
  }

  Future<void> loadStockDetail(String ticker) async {
    if (state.detailLoadingTickers.contains(ticker)) {
      return;
    }

    final loading = Set<String>.from(state.detailLoadingTickers)..add(ticker);
    state = state.copyWith(detailLoadingTickers: loading);

    try {
      final detail = await _repository.loadStockDetail(
        ticker: ticker,
        date: state.selectedDateIso,
        strategy: state.effectiveStrategy,
        weights: state.weights,
        userKey: 'default',
        customTickers: state.customTickers,
      );
      final detailMap = Map<String, StockDetail>.from(state.stockDetails)..[ticker] = detail;
      final done = Set<String>.from(state.detailLoadingTickers)..remove(ticker);
      state = state.copyWith(stockDetails: detailMap, detailLoadingTickers: done);
    } catch (error) {
      final done = Set<String>.from(state.detailLoadingTickers)..remove(ticker);
      state = state.copyWith(detailLoadingTickers: done, warning: error.toString());
    }
  }

  @override
  void dispose() {
    _loadCancelToken?.cancel();
    super.dispose();
  }
}
