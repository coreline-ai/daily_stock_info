import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_entire/domain/services/backtest_math_service.dart';

void main() {
  const service = BacktestMathService();

  test('forward return computes from first close to offset', () {
    final ret = service.forwardReturn([100, 102, 105, 104, 108], offset: 3);
    expect(ret, closeTo(4.0, 0.0001));
  });

  test('average and winrate', () {
    expect(service.average([1, 3, null, -2]), closeTo(0.6667, 0.001));
    expect(service.winRate([1, 3, null, -2]), closeTo(66.666, 0.1));
  });

  test('mdd gets minimum value', () {
    expect(service.mdd([1.2, -5.1, -1.0, 2.0]), -5.1);
  });
}
