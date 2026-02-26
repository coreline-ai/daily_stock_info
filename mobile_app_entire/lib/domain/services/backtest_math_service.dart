class BacktestMathService {
  const BacktestMathService();

  double? forwardReturn(List<double> closeSeries, {required int offset}) {
    if (closeSeries.isEmpty || closeSeries.length <= offset) {
      return null;
    }
    final entry = closeSeries.first;
    if (entry == 0) {
      return null;
    }
    final future = closeSeries[offset];
    return ((future - entry) / entry) * 100;
  }

  double average(List<double?> values) {
    final valid = values.whereType<double>().toList(growable: false);
    if (valid.isEmpty) {
      return 0;
    }
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  double winRate(List<double?> values) {
    final valid = values.whereType<double>().toList(growable: false);
    if (valid.isEmpty) {
      return 0;
    }
    final wins = valid.where((v) => v > 0).length;
    return wins / valid.length * 100;
  }

  double mdd(List<double?> values) {
    final valid = values.whereType<double>().toList(growable: false);
    if (valid.isEmpty) {
      return 0;
    }
    valid.sort();
    return valid.first;
  }
}
