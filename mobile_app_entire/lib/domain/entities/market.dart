class PriceBar {
  const PriceBar({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
}

class MarketOverview {
  const MarketOverview({
    required this.up,
    required this.steady,
    required this.down,
    required this.warnings,
  });

  final int up;
  final int steady;
  final int down;
  final List<String> warnings;
}

class MarketInsight {
  const MarketInsight({required this.riskFactors, required this.conclusion});

  final List<String> riskFactors;
  final String conclusion;
}

class StockCandidate {
  const StockCandidate({
    required this.rank,
    required this.name,
    required this.code,
    required this.score,
    required this.changeRate,
    required this.price,
    required this.targetPrice,
    required this.stopLoss,
    required this.tags,
    required this.sector,
    required this.sparkline60,
    required this.summary,
    required this.strongRecommendation,
  });

  final int rank;
  final String name;
  final String code;
  final double score;
  final double changeRate;
  final double price;
  final double targetPrice;
  final double stopLoss;
  final List<String> tags;
  final String sector;
  final List<double> sparkline60;
  final String summary;
  final bool strongRecommendation;

  StockCandidate copyWith({
    int? rank,
    double? score,
    bool? strongRecommendation,
  }) {
    return StockCandidate(
      rank: rank ?? this.rank,
      name: name,
      code: code,
      score: score ?? this.score,
      changeRate: changeRate,
      price: price,
      targetPrice: targetPrice,
      stopLoss: stopLoss,
      tags: tags,
      sector: sector,
      sparkline60: sparkline60,
      summary: summary,
      strongRecommendation: strongRecommendation ?? this.strongRecommendation,
    );
  }
}

class StockDetail {
  const StockDetail({
    required this.ticker,
    required this.name,
    required this.currentPrice,
    required this.targetPrice,
    required this.stopLoss,
    required this.expectedReturn,
    required this.newsSummary,
    required this.themes,
    required this.signals,
  });

  final String ticker;
  final String name;
  final double currentPrice;
  final double targetPrice;
  final double stopLoss;
  final double expectedReturn;
  final List<String> newsSummary;
  final List<String> themes;
  final List<String> signals;
}
