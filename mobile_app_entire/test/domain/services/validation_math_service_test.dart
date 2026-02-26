import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_entire/domain/services/validation_math_service.dart';

void main() {
  const service = ValidationMathService();

  test('compute PBO from train/test sharpe pairs', () {
    final pbo = service.computePbo(
      [1.2, 1.1, 0.9, 1.4],
      [0.6, -0.2, 0.3, -0.1],
    );
    expect(pbo, 0.5);
  });

  test('compute DSR positive for stable positive returns', () {
    final dsr = service.computeDsr([0.5, 0.7, 0.6, 0.8, 0.55, 0.66], trials: 2);
    expect(dsr > 0, isTrue);
  });

  test('gate status returns fail on weak metrics', () {
    final gate = service.gateStatus(
      pbo: 0.3,
      dsr: -0.2,
      netSharpe: 0.1,
      sampleSize: 100,
    );
    expect(gate, 'fail');
  });
}
