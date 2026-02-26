import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_entire/domain/entities/dashboard.dart';
import 'package:mobile_app_entire/domain/entities/market.dart';
import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/domain/value_objects/strategy_weights.dart';
import 'package:mobile_app_entire/features/dashboard/presentation/dashboard_controller.dart';
import 'package:mobile_app_entire/features/dashboard/presentation/dashboard_page.dart';

void main() {
  testWidgets('renders dashboard sections', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardControllerProvider.overrideWith(
            () => _FakeDashboardController(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardPage())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('전략 가중치'), findsOneWidget);
    expect(find.text('시장 개요'), findsOneWidget);
    expect(find.text('추천 종목'), findsOneWidget);
    expect(find.text('무료 데이터 모드'), findsOneWidget);
  });

  testWidgets('shows snackbar when unavailable strategy tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardControllerProvider.overrideWith(
            () => _FakeDashboardController(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardPage())),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('장중'));
    await tester.pump();

    expect(find.textContaining('09:05~15:20'), findsOneWidget);
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
          StrategyKind.premarket: '현재 장전 전략 조회 가능 시간입니다.',
          StrategyKind.intraday: '장중 전략은 09:05~15:20(KST) 사이 조회 가능합니다.',
          StrategyKind.close: '종가 전략은 15:00(KST) 이후 조회 가능합니다.',
        },
      ),
      selectedStrategy: StrategyKind.premarket,
      weights: StrategyWeights.balanced,
      overview: const MarketOverview(up: 3, steady: 1, down: 2, warnings: []),
      candidates: const [
        StockCandidate(
          rank: 1,
          name: '삼성전자',
          code: '005930',
          score: 7.2,
          changeRate: 1.2,
          price: 70100,
          targetPrice: 72000,
          stopLoss: 68000,
          tags: ['장전 전략'],
          sector: '반도체',
          sparkline60: [1, 2, 3, 2, 4],
          summary: 'summary',
          strongRecommendation: true,
        ),
      ],
      intradayExtra: const [],
      insight: const MarketInsight(riskFactors: ['r1'], conclusion: 'c1'),
      lastUpdated: DateTime(2026),
      dataMode: 'free',
      usedInformation: const ['주가 소스: 네이버 무료 1개'],
      dataWarnings: const ['테스트 경고'],
    );
  }
}
