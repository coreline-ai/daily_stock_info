class StrategyWeights {
  const StrategyWeights({
    required this.returnWeight,
    required this.stabilityWeight,
    required this.marketWeight,
  });

  final double returnWeight;
  final double stabilityWeight;
  final double marketWeight;

  static const balanced = StrategyWeights(
    returnWeight: 0.4,
    stabilityWeight: 0.3,
    marketWeight: 0.3,
  );
  static const aggressive = StrategyWeights(
    returnWeight: 0.6,
    stabilityWeight: 0.2,
    marketWeight: 0.2,
  );
  static const defensive = StrategyWeights(
    returnWeight: 0.2,
    stabilityWeight: 0.6,
    marketWeight: 0.2,
  );

  StrategyWeights normalize() {
    final total = returnWeight + stabilityWeight + marketWeight;
    if (total <= 0) {
      return balanced;
    }
    return StrategyWeights(
      returnWeight: double.parse((returnWeight / total).toStringAsFixed(4)),
      stabilityWeight: double.parse(
        (stabilityWeight / total).toStringAsFixed(4),
      ),
      marketWeight: double.parse((marketWeight / total).toStringAsFixed(4)),
    );
  }

  String cacheKey() =>
      '${normalize().returnWeight}|${normalize().stabilityWeight}|${normalize().marketWeight}';
}
