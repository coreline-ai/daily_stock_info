import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_entire/domain/entities/backtest.dart';
import 'package:mobile_app_entire/features/history/presentation/history_controller.dart';
import 'package:mobile_app_entire/features/history/presentation/history_page.dart';

void main() {
  testWidgets('renders backtest history title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyControllerProvider.overrideWith(
            () => _FakeHistoryController(),
          ),
        ],
        child: const MaterialApp(home: HistoryPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('백테스트 히스토리'), findsOneWidget);
    expect(find.textContaining('평균 T+1'), findsOneWidget);
  });
}

class _FakeHistoryController extends HistoryController {
  @override
  Future<HistoryState> build() async {
    return const HistoryState(
      summary: BacktestSummary(
        count: 2,
        avgRetT1: 1.2,
        avgRetT3: 2.1,
        avgRetT5: 2.6,
        winRateT1: 60,
        winRateT3: 55,
        winRateT5: 52,
        mddT1: -2.0,
        mddT3: -3.2,
        mddT5: -4.0,
      ),
      page: BacktestPage(
        items: [
          BacktestItem(
            tradeDate: '2026-02-26',
            ticker: '005930',
            companyName: 'Samsung Electronics',
            entryPrice: 70000,
            retT1: 0.5,
            retT3: 1.2,
            retT5: 2.1,
            currentPrice: 70500,
          ),
        ],
        page: 1,
        size: 20,
        total: 1,
      ),
    );
  }
}
