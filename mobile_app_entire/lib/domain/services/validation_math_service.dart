import 'dart:math' as math;

class ValidationMathService {
  const ValidationMathService();

  double computePbo(List<double> trainSharpes, List<double> testSharpes) {
    if (trainSharpes.isEmpty ||
        testSharpes.isEmpty ||
        trainSharpes.length != testSharpes.length) {
      return 1.0;
    }
    var overfit = 0;
    var usable = 0;
    for (var i = 0; i < trainSharpes.length; i++) {
      final train = trainSharpes[i];
      final test = testSharpes[i];
      if (train.isNaN || test.isNaN) {
        continue;
      }
      usable += 1;
      if (train > 0 && test < 0) {
        overfit += 1;
      }
    }
    if (usable == 0) {
      return 1.0;
    }
    return overfit / usable;
  }

  double computeDsr(List<double> returns, {int trials = 1}) {
    if (returns.length < 2) {
      return 0;
    }
    final mean = returns.reduce((a, b) => a + b) / returns.length;
    final variance =
        returns
            .map((e) => math.pow(e - mean, 2))
            .fold<double>(0, (a, b) => a + b) /
        (returns.length - 1);
    final std = math.sqrt(variance);
    if (std == 0) {
      return 0;
    }
    final sharpe = mean / std * math.sqrt(252);
    final adjustment = math.sqrt(2 * math.log(math.max(1, trials)));
    return sharpe - adjustment;
  }

  String gateStatus({
    required double pbo,
    required double dsr,
    required double netSharpe,
    required int sampleSize,
    double pboMax = 0.20,
    double dsrMin = 0,
    double netSharpeMin = 0.5,
    int sampleMin = 60,
  }) {
    if (sampleSize < sampleMin) {
      return 'warn';
    }
    if (pbo > pboMax || dsr < dsrMin || netSharpe < netSharpeMin) {
      return 'fail';
    }
    return 'pass';
  }
}
