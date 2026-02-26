class AiReport {
  const AiReport({
    required this.provider,
    required this.model,
    required this.generatedAt,
    required this.summary,
    required this.conclusion,
    required this.riskFactors,
    required this.confidenceScore,
    required this.confidenceLevel,
    required this.warnings,
  });

  final String provider;
  final String model;
  final DateTime generatedAt;
  final String summary;
  final String conclusion;
  final List<String> riskFactors;
  final int confidenceScore;
  final String confidenceLevel;
  final List<String> warnings;
}
