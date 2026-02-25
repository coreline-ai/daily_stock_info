import 'package:coreline_stock_ai/features/dashboard/domain/entities/dashboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StrategyStatus parses available strategy and messages', () {
    final status = StrategyStatus.fromJson({
      'requestedDate': '2026-02-25',
      'availableStrategies': ['premarket', 'close'],
      'defaultStrategy': 'premarket',
      'messages': {
        'premarket': 'ok',
        'intraday': '장중만 사용 가능',
        'close': 'ok',
      },
    });

    expect(status.availableStrategies.contains(StrategyKind.premarket), isTrue);
    expect(status.availableStrategies.contains(StrategyKind.close), isTrue);
    expect(status.defaultStrategy, StrategyKind.premarket);
    expect(status.messages['intraday'], contains('장중'));
  });

  test('StockCandidate parses optional intraday signals and validation gate', () {
    final candidate = StockCandidate.fromJson({
      'rank': 1,
      'name': 'Samsung Elec',
      'code': '005930',
      'score': 7.2,
      'changeRate': 1.2,
      'price': 71500,
      'targetPrice': 74000,
      'stopLoss': 69000,
      'tags': ['AI'],
      'summary': '테스트 요약',
      'sparkline60': [1, 2, 3],
      'details': {
        'intradaySignals': {
          'mode': 'proxy',
          'orbProxyScore': 7.0,
          'vwapProxyScore': 6.5,
          'rvolScore': 8.0,
        },
        'validation': {
          'gateStatus': 'pass',
        },
      },
    });

    expect(candidate.intradaySignals, isNotNull);
    expect(candidate.validationGate, 'pass');
    expect(candidate.strongRecommendation, isTrue);
  });
}
