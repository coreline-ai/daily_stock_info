import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app_entire/app/bootstrap/providers.dart';
import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/domain/entities/dashboard.dart';
import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/domain/value_objects/strategy_weights.dart';

final dashboardQueryProvider = StateProvider<DashboardQuery>((ref) {
  final clock = ref.watch(kstClockProvider);
  final now = clock.nowKst();
  final strategyStatus = ref
      .watch(strategyWindowServiceProvider)
      .resolve(nowKst: now, requestedDate: now);
  return DashboardQuery(
    date: clock.todayIsoKst(),
    strategy: strategyStatus.defaultStrategy ?? StrategyKind.premarket,
    weights: StrategyWeights.balanced,
    strictRealData: false,
  );
});

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardSnapshot>(
      DashboardController.new,
    );

enum StrategyPreset { balanced, aggressive, defensive }

class DashboardController extends AsyncNotifier<DashboardSnapshot> {
  bool _backgroundRefreshing = false;

  @override
  Future<DashboardSnapshot> build() async {
    return _load();
  }

  Future<DashboardSnapshot> _load({bool forceRefresh = false}) async {
    final usecase = ref.read(loadDashboardUsecaseProvider);
    final query = ref.read(dashboardQueryProvider);
    final result = await usecase(query.copyWith(forceRefresh: forceRefresh));

    return result.when(
      success: (snapshot) => snapshot,
      failure: (failure) => throw DashboardLoadException(failure.message),
    );
  }

  Future<void> reload({bool forceRefresh = false}) async {
    state = const AsyncLoading<DashboardSnapshot>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(forceRefresh: forceRefresh));
  }

  Future<void> setDate(String date) async {
    final clock = ref.read(kstClockProvider);
    final now = clock.nowKst();
    final requestedDate = DateTime.tryParse(date) ?? now;
    final strategyStatus = ref
        .read(strategyWindowServiceProvider)
        .resolve(nowKst: now, requestedDate: requestedDate);
    ref.read(dashboardQueryProvider.notifier).update((state) {
      final normalizedStrategy =
          strategyStatus.availableStrategies.contains(state.strategy)
          ? state.strategy
          : (strategyStatus.defaultStrategy ?? state.strategy);
      return state.copyWith(date: date, strategy: normalizedStrategy);
    });
    await reload(forceRefresh: true);
  }

  Future<void> setStrategy(StrategyKind strategy) async {
    final current = ref.read(dashboardQueryProvider).strategy;
    if (current == strategy) {
      return;
    }
    ref
        .read(dashboardQueryProvider.notifier)
        .update((state) => state.copyWith(strategy: strategy));
    await reload();
    unawaited(_refreshInBackground());
  }

  Future<void> setPreset(StrategyPreset preset) async {
    final weights = switch (preset) {
      StrategyPreset.balanced => StrategyWeights.balanced,
      StrategyPreset.aggressive => StrategyWeights.aggressive,
      StrategyPreset.defensive => StrategyWeights.defensive,
    };
    ref
        .read(dashboardQueryProvider.notifier)
        .update((state) => state.copyWith(weights: weights));
    await reload();
    unawaited(_refreshInBackground());
  }

  Future<void> _refreshInBackground() async {
    if (_backgroundRefreshing) {
      return;
    }
    _backgroundRefreshing = true;
    final loadingState = const AsyncLoading<DashboardSnapshot>()
        .copyWithPrevious(state);
    state = loadingState;

    final refreshed = await AsyncValue.guard(() => _load(forceRefresh: true));
    if (refreshed.hasValue) {
      state = refreshed;
    } else if (loadingState.valueOrNull != null) {
      state = AsyncData(loadingState.valueOrNull!);
    } else {
      state = refreshed;
    }

    _backgroundRefreshing = false;
  }
}

class DashboardLoadException implements Exception {
  const DashboardLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension on DashboardQuery {
  DashboardQuery copyWith({
    String? date,
    StrategyKind? strategy,
    StrategyWeights? weights,
    List<String>? customTickers,
    bool? includeIntradayExtra,
    bool? strictRealData,
    bool? forceRefresh,
  }) {
    return DashboardQuery(
      date: date ?? this.date,
      strategy: strategy ?? this.strategy,
      weights: weights ?? this.weights,
      customTickers: customTickers ?? this.customTickers,
      includeIntradayExtra: includeIntradayExtra ?? this.includeIntradayExtra,
      strictRealData: strictRealData ?? this.strictRealData,
      forceRefresh: forceRefresh ?? this.forceRefresh,
    );
  }
}
