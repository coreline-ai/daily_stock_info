import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/domain/services/strategy_window_service.dart';

void main() {
  const service = StrategyWindowService();

  test('supports premarket window', () {
    final now = DateTime(2026, 2, 26, 8, 10);
    final status = service.resolve(
      nowKst: now,
      requestedDate: DateTime(2026, 2, 26),
    );
    expect(status.availableStrategies, [StrategyKind.premarket]);
    expect(status.defaultStrategy, StrategyKind.premarket);
  });

  test('supports intraday window', () {
    final now = DateTime(2026, 2, 26, 10, 00);
    final status = service.resolve(
      nowKst: now,
      requestedDate: DateTime(2026, 2, 26),
    );
    expect(status.availableStrategies.contains(StrategyKind.intraday), isTrue);
    expect(status.defaultStrategy, StrategyKind.intraday);
  });

  test('blocks future date', () {
    final now = DateTime(2026, 2, 26, 10, 00);
    final status = service.resolve(
      nowKst: now,
      requestedDate: DateTime(2026, 2, 27),
    );
    expect(status.availableStrategies, isEmpty);
    expect(status.defaultStrategy, isNull);
  });
}
