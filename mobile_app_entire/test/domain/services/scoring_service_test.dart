import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/domain/services/scoring_service.dart';
import 'package:mobile_app_entire/domain/value_objects/strategy_weights.dart';

void main() {
  const service = ScoringService();

  test('strategy kinds produce different top picks on same snapshots', () {
    final snapshots = _fixtureSnapshots();
    final premarket = service.scoreCandidates(
      snapshots: snapshots,
      weights: StrategyWeights.balanced,
      strategy: StrategyKind.premarket,
    );
    final intraday = service.scoreCandidates(
      snapshots: snapshots,
      weights: StrategyWeights.balanced,
      strategy: StrategyKind.intraday,
    );
    final close = service.scoreCandidates(
      snapshots: snapshots,
      weights: StrategyWeights.balanced,
      strategy: StrategyKind.close,
    );

    expect(premarket, isNotEmpty);
    expect(intraday, isNotEmpty);
    expect(close, isNotEmpty);

    final topCodes = {
      premarket.first.code,
      intraday.first.code,
      close.first.code,
    };
    expect(topCodes.length, greaterThanOrEqualTo(2));
    expect(premarket.first.summary, contains('장전 전략'));
    expect(intraday.first.summary, contains('장중 전략'));
    expect(close.first.summary, contains('종가 전략'));
  });

  test('aggressive and defensive presets produce different ranking', () {
    final snapshots = _fixtureSnapshots();
    final aggressive = service.scoreCandidates(
      snapshots: snapshots,
      weights: StrategyWeights.aggressive,
      strategy: StrategyKind.intraday,
    );
    final defensive = service.scoreCandidates(
      snapshots: snapshots,
      weights: StrategyWeights.defensive,
      strategy: StrategyKind.intraday,
    );

    expect(aggressive, isNotEmpty);
    expect(defensive, isNotEmpty);
    expect(
      aggressive.take(4).map((e) => e.code).toList(growable: false),
      isNot(
        equals(defensive.take(4).map((e) => e.code).toList(growable: false)),
      ),
    );
    expect(aggressive.first.summary, contains('공격형'));
    expect(defensive.first.summary, contains('방어형'));
  });
}

List<SymbolMarketSnapshot> _fixtureSnapshots() {
  return [
    SymbolMarketSnapshot(
      code: '111111',
      name: '모멘텀전자',
      sector: '반도체',
      price: 184000,
      changeRate: 2.3,
      closeSeries: _momentumSeries(),
      volumeSeries: _volumeSeries(base: 4500000, swing: 1000000),
      newsSentiment: 0.15,
      newsCount: 6,
      barsFromApi: true,
      quoteFromApi: true,
      newsFromApi: true,
    ),
    SymbolMarketSnapshot(
      code: '222222',
      name: '안정금융',
      sector: '금융',
      price: 138500,
      changeRate: 0.35,
      closeSeries: _stableSeries(),
      volumeSeries: _volumeSeries(base: 1200000, swing: 120000),
      newsSentiment: 0.05,
      newsCount: 4,
      barsFromApi: true,
      quoteFromApi: true,
      newsFromApi: true,
    ),
    SymbolMarketSnapshot(
      code: '333333',
      name: '리바운드화학',
      sector: '화학',
      price: 96500,
      changeRate: 1.4,
      closeSeries: _reboundSeries(),
      volumeSeries: _volumeSeries(base: 420000, swing: 70000),
      newsSentiment: 0.75,
      newsCount: 12,
      barsFromApi: true,
      quoteFromApi: true,
      newsFromApi: true,
    ),
    SymbolMarketSnapshot(
      code: '444444',
      name: '약세자동차',
      sector: '자동차',
      price: 75500,
      changeRate: -1.2,
      closeSeries: _weakSeries(),
      volumeSeries: _volumeSeries(base: 380000, swing: 50000),
      newsSentiment: -0.6,
      newsCount: 5,
      barsFromApi: true,
      quoteFromApi: true,
      newsFromApi: true,
    ),
  ];
}

List<double> _momentumSeries() {
  final out = <double>[];
  var price = 90.0;
  for (var i = 0; i < 40; i++) {
    price += 1.7 + (i.isEven ? 2.8 : -1.4);
    out.add(double.parse(price.toStringAsFixed(2)));
  }
  return out;
}

List<double> _stableSeries() {
  final out = <double>[];
  var price = 120.0;
  for (var i = 0; i < 40; i++) {
    price += 0.38 + (i % 5 == 0 ? -0.08 : 0.03);
    out.add(double.parse(price.toStringAsFixed(2)));
  }
  return out;
}

List<double> _reboundSeries() {
  final out = <double>[];
  var price = 180.0;
  for (var i = 0; i < 30; i++) {
    price += -1.5 + (i % 3 == 0 ? 0.2 : -0.25);
    out.add(double.parse(price.toStringAsFixed(2)));
  }
  for (var i = 30; i < 40; i++) {
    price += 1.35 + (i % 2 == 0 ? 0.35 : -0.12);
    out.add(double.parse(price.toStringAsFixed(2)));
  }
  return out;
}

List<double> _weakSeries() {
  final out = <double>[];
  var price = 140.0;
  for (var i = 0; i < 40; i++) {
    price += -0.55 + (i % 4 == 0 ? 0.12 : -0.09);
    out.add(double.parse(price.toStringAsFixed(2)));
  }
  return out;
}

List<double> _volumeSeries({required double base, required double swing}) {
  return List<double>.generate(
    40,
    (index) => base + (index.isEven ? swing : -swing / 2),
  );
}
