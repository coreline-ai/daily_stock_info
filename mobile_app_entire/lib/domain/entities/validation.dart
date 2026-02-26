class StrategyValidation {
  const StrategyValidation({
    required this.strategy,
    required this.asOfDate,
    required this.gateStatus,
    required this.gatePassed,
    required this.insufficientData,
    required this.validationPenalty,
    required this.metrics,
  });

  final String strategy;
  final String asOfDate;
  final String gateStatus;
  final bool gatePassed;
  final bool insufficientData;
  final double validationPenalty;
  final ValidationMetrics metrics;
}

class ValidationMetrics {
  const ValidationMetrics({
    required this.netSharpe,
    required this.maxDrawdown,
    required this.hitRate,
    required this.turnover,
    required this.pbo,
    required this.dsr,
    required this.sampleSize,
  });

  final double netSharpe;
  final double maxDrawdown;
  final double hitRate;
  final double turnover;
  final double pbo;
  final double dsr;
  final int sampleSize;
}
