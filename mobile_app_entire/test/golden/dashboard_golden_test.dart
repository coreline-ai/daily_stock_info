import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mobile_app_entire/domain/entities/dashboard.dart';
import 'package:mobile_app_entire/domain/entities/market.dart';
import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/domain/value_objects/strategy_weights.dart';
import 'package:mobile_app_entire/features/dashboard/presentation/dashboard_controller.dart';
import 'package:mobile_app_entire/features/dashboard/presentation/dashboard_page.dart';

void main() {
  testGoldens('dashboard page golden', (tester) async {
    await loadAppFonts();

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          dashboardControllerProvider.overrideWith(
            () => _FakeDashboardController(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardPage())),
      ),
      surfaceSize: const Size(390, 844),
    );

    await screenMatchesGolden(tester, 'dashboard_page');
  });
}

class _FakeDashboardController extends DashboardController {
  @override
  Future<DashboardSnapshot> build() async {
    return DashboardSnapshot(
      strategyStatus: StrategyStatus(
        timezone: 'Asia/Seoul',
        nowKstIso: DateTime(2026).toIso8601String(),
        requestedDate: '2026-02-26',
        availableStrategies: const [StrategyKind.premarket],
        defaultStrategy: StrategyKind.premarket,
        messages: const {
          StrategyKind.premarket: 'ok',
          StrategyKind.intraday: 'ok',
          StrategyKind.close: 'ok',
        },
      ),
      selectedStrategy: StrategyKind.premarket,
      weights: StrategyWeights.balanced,
      overview: const MarketOverview(up: 13, steady: 1, down: 13, warnings: []),
      candidates: const [
        StockCandidate(
          rank: 1,
          name: 'LG Chem',
          code: '051910',
          score: 6.9,
          changeRate: 14.02,
          price: 312000,
          targetPrice: 324000,
          stopLoss: 300000,
          tags: ['Premarket'],
          sector: 'Chemical',
          sparkline60: [1, 2, 1, 3, 4, 3, 5],
          summary: 's',
          strongRecommendation: true,
        ),
      ],
      intradayExtra: const [],
      insight: const MarketInsight(riskFactors: ['r1'], conclusion: 'c1'),
      lastUpdated: DateTime(2026),
      dataMode: 'free',
      usedInformation: const ['주가 소스: 네이버 무료 1개'],
      dataWarnings: const [],
    );
  }
}
