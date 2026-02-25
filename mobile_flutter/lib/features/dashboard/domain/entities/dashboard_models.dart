import 'dart:convert';

enum StrategyKind { premarket, intraday, close }

extension StrategyKindX on StrategyKind {
  String get value => name;

  static StrategyKind? tryParse(String? value) {
    if (value == null) return null;
    for (final item in StrategyKind.values) {
      if (item.name == value) return item;
    }
    return null;
  }
}

class StrategyWeights {
  const StrategyWeights({
    required this.returnWeight,
    required this.stabilityWeight,
    required this.marketWeight,
  });

  final double returnWeight;
  final double stabilityWeight;
  final double marketWeight;

  static const balanced = StrategyWeights(returnWeight: 0.4, stabilityWeight: 0.3, marketWeight: 0.3);
  static const aggressive = StrategyWeights(returnWeight: 0.6, stabilityWeight: 0.2, marketWeight: 0.2);
  static const defensive = StrategyWeights(returnWeight: 0.2, stabilityWeight: 0.6, marketWeight: 0.2);

  Map<String, dynamic> toJson() => {
        'return': returnWeight,
        'stability': stabilityWeight,
        'market': marketWeight,
      };

  String cacheKey() => '${returnWeight.toStringAsFixed(2)}-${stabilityWeight.toStringAsFixed(2)}-${marketWeight.toStringAsFixed(2)}';
}

class StrategyStatus {
  const StrategyStatus({
    required this.requestedDate,
    required this.availableStrategies,
    required this.messages,
    this.defaultStrategy,
    this.errorCode,
    this.detail,
  });

  final String requestedDate;
  final List<StrategyKind> availableStrategies;
  final StrategyKind? defaultStrategy;
  final Map<String, String> messages;
  final String? errorCode;
  final String? detail;

  factory StrategyStatus.fromJson(Map<String, dynamic> json) {
    final availableRaw = (json['availableStrategies'] as List<dynamic>? ?? const []);
    final available = availableRaw
        .map((e) => StrategyKindX.tryParse(e.toString()))
        .whereType<StrategyKind>()
        .toList(growable: false);

    final msgRaw = (json['messages'] as Map<String, dynamic>? ?? const {});
    return StrategyStatus(
      requestedDate: (json['requestedDate'] ?? '').toString(),
      availableStrategies: available,
      defaultStrategy: StrategyKindX.tryParse(json['defaultStrategy']?.toString()),
      messages: {
        'premarket': (msgRaw['premarket'] ?? '').toString(),
        'intraday': (msgRaw['intraday'] ?? '').toString(),
        'close': (msgRaw['close'] ?? '').toString(),
      },
      errorCode: json['errorCode']?.toString(),
      detail: json['detail']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'requestedDate': requestedDate,
        'availableStrategies': availableStrategies.map((e) => e.value).toList(growable: false),
        'defaultStrategy': defaultStrategy?.value,
        'messages': messages,
        'errorCode': errorCode,
        'detail': detail,
      };
}

class MarketOverview {
  const MarketOverview({
    required this.up,
    required this.steady,
    required this.down,
    required this.warnings,
    this.sessionDate,
    this.signalDate,
    this.strategyReason,
  });

  final int up;
  final int steady;
  final int down;
  final List<String> warnings;
  final String? sessionDate;
  final String? signalDate;
  final String? strategyReason;

  factory MarketOverview.fromJson(Map<String, dynamic> json) {
    final warningsRaw = (json['warnings'] as List<dynamic>? ?? const []);
    return MarketOverview(
      up: (json['up'] as num?)?.toInt() ?? 0,
      steady: (json['steady'] as num?)?.toInt() ?? 0,
      down: (json['down'] as num?)?.toInt() ?? 0,
      warnings: warningsRaw
          .map((item) => item is Map<String, dynamic> ? (item['message'] ?? '').toString() : item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      sessionDate: json['sessionDate']?.toString(),
      signalDate: json['signalDate']?.toString(),
      strategyReason: json['strategyReason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'up': up,
        'steady': steady,
        'down': down,
        'warnings': warnings,
        'sessionDate': sessionDate,
        'signalDate': signalDate,
        'strategyReason': strategyReason,
      };
}

class StrategyValidation {
  const StrategyValidation({
    required this.gateStatus,
    required this.gatePassed,
    required this.netSharpe,
    required this.pbo,
    required this.dsr,
    required this.sampleSize,
    this.intradaySignalBranch,
    this.alerts = const [],
  });

  final String gateStatus;
  final bool gatePassed;
  final double netSharpe;
  final double pbo;
  final double dsr;
  final int sampleSize;
  final String? intradaySignalBranch;
  final List<String> alerts;

  factory StrategyValidation.fromJson(Map<String, dynamic> json) {
    final metrics = (json['metrics'] as Map<String, dynamic>? ?? const {});
    final protocol = (json['protocol'] as Map<String, dynamic>? ?? const {});
    final monitoring = (json['monitoring'] as Map<String, dynamic>? ?? const {});
    return StrategyValidation(
      gateStatus: (json['gateStatus'] ?? 'warn').toString(),
      gatePassed: json['gatePassed'] == true,
      netSharpe: (metrics['netSharpe'] as num?)?.toDouble() ?? 0,
      pbo: (metrics['pbo'] as num?)?.toDouble() ?? 0,
      dsr: (metrics['dsr'] as num?)?.toDouble() ?? 0,
      sampleSize: (metrics['sampleSize'] as num?)?.toInt() ?? 0,
      intradaySignalBranch: protocol['intradaySignalBranch']?.toString(),
      alerts: (monitoring['alerts'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'gateStatus': gateStatus,
        'gatePassed': gatePassed,
        'metrics': {
          'netSharpe': netSharpe,
          'pbo': pbo,
          'dsr': dsr,
          'sampleSize': sampleSize,
        },
        'protocol': {
          'intradaySignalBranch': intradaySignalBranch,
        },
        'monitoring': {'alerts': alerts},
      };
}

class MarketInsight {
  const MarketInsight({required this.conclusion, required this.riskFactors});

  final String conclusion;
  final List<String> riskFactors;

  factory MarketInsight.fromJson(Map<String, dynamic> json) {
    final riskRaw = (json['riskFactors'] as List<dynamic>? ?? const []);
    return MarketInsight(
      conclusion: (json['conclusion'] ?? '').toString(),
      riskFactors: riskRaw
          .map((item) => item is Map<String, dynamic> ? (item['description'] ?? '').toString() : item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'conclusion': conclusion,
        'riskFactors': riskFactors,
      };
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
    required this.summary,
    required this.sparkline60,
    this.sector,
    this.strongRecommendation = false,
    this.intradaySignals,
    this.validationGate,
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
  final String summary;
  final List<double> sparkline60;
  final String? sector;
  final bool strongRecommendation;
  final IntradaySignals? intradaySignals;
  final String? validationGate;

  factory StockCandidate.fromJson(Map<String, dynamic> json) {
    final details = (json['details'] as Map<String, dynamic>? ?? const {});
    final validation = (details['validation'] as Map<String, dynamic>? ?? const {});
    final intradayRaw = details['intradaySignals'];

    return StockCandidate(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      changeRate: (json['changeRate'] as num?)?.toDouble() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      targetPrice: (json['targetPrice'] as num?)?.toDouble() ?? 0,
      stopLoss: (json['stopLoss'] as num?)?.toDouble() ?? 0,
      tags: (json['tags'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(growable: false),
      summary: (json['summary'] ?? '').toString(),
      sparkline60: (json['sparkline60'] as List<dynamic>? ?? const [])
          .map((e) => (e as num?)?.toDouble() ?? 0)
          .toList(growable: false),
      sector: json['sector']?.toString(),
      strongRecommendation: json['strongRecommendation'] == true || ((json['rank'] as num?)?.toInt() ?? 0) <= 5,
      intradaySignals: intradayRaw is Map<String, dynamic> ? IntradaySignals.fromJson(intradayRaw) : null,
      validationGate: validation['gateStatus']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'name': name,
        'code': code,
        'score': score,
        'changeRate': changeRate,
        'price': price,
        'targetPrice': targetPrice,
        'stopLoss': stopLoss,
        'tags': tags,
        'summary': summary,
        'sparkline60': sparkline60,
        'sector': sector,
        'strongRecommendation': strongRecommendation,
        'details': {
          'intradaySignals': intradaySignals?.toJson(),
          'validation': {'gateStatus': validationGate},
        },
      };
}

class IntradaySignals {
  const IntradaySignals({
    required this.mode,
    required this.orbScore,
    required this.vwapScore,
    required this.rvolScore,
  });

  final String mode;
  final double orbScore;
  final double vwapScore;
  final double rvolScore;

  factory IntradaySignals.fromJson(Map<String, dynamic> json) {
    return IntradaySignals(
      mode: (json['mode'] ?? '').toString(),
      orbScore: (json['orbProxyScore'] as num?)?.toDouble() ?? 0,
      vwapScore: (json['vwapProxyScore'] as num?)?.toDouble() ?? 0,
      rvolScore: (json['rvolScore'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'orbProxyScore': orbScore,
        'vwapProxyScore': vwapScore,
        'rvolScore': rvolScore,
      };
}

class StockDetail {
  const StockDetail({
    required this.ticker,
    required this.name,
    required this.currentPrice,
    required this.targetPrice,
    required this.stopLoss,
    required this.expectedReturn,
    required this.tags,
    required this.newsSummary3,
    required this.themes,
    required this.riskFactors,
    required this.aiSummary,
  });

  final String ticker;
  final String name;
  final double currentPrice;
  final double targetPrice;
  final double stopLoss;
  final double expectedReturn;
  final List<String> tags;
  final List<String> newsSummary3;
  final List<String> themes;
  final List<String> riskFactors;
  final String aiSummary;

  factory StockDetail.fromJson(Map<String, dynamic> json) {
    final aiReport = (json['aiReport'] as Map<String, dynamic>? ?? const {});
    final risk = (aiReport['riskFactors'] as List<dynamic>? ?? const []);
    return StockDetail(
      ticker: (json['ticker'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0,
      targetPrice: (json['targetPrice'] as num?)?.toDouble() ?? 0,
      stopLoss: (json['stopLoss'] as num?)?.toDouble() ?? 0,
      expectedReturn: (json['expectedReturn'] as num?)?.toDouble() ?? 0,
      tags: (json['tags'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(growable: false),
      newsSummary3: (json['newsSummary3'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(growable: false),
      themes: (json['themes'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(growable: false),
      riskFactors: risk
          .map((e) => e is Map<String, dynamic> ? (e['description'] ?? '').toString() : e.toString())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      aiSummary: (aiReport['summary'] ?? '').toString(),
    );
  }
}

class DashboardCachePayload {
  const DashboardCachePayload({
    required this.generatedAtIso,
    required this.strategyStatus,
    required this.selectedStrategy,
    required this.marketOverview,
    required this.candidates,
    this.validation,
    this.marketInsight,
    this.intradayExtra = const [],
  });

  final String generatedAtIso;
  final StrategyStatus strategyStatus;
  final StrategyKind? selectedStrategy;
  final MarketOverview marketOverview;
  final List<StockCandidate> candidates;
  final StrategyValidation? validation;
  final MarketInsight? marketInsight;
  final List<StockCandidate> intradayExtra;

  Map<String, dynamic> toJson() => {
        'generatedAtIso': generatedAtIso,
        'strategyStatus': strategyStatus.toJson(),
        'selectedStrategy': selectedStrategy?.value,
        'marketOverview': marketOverview.toJson(),
        'candidates': candidates.map((e) => e.toJson()).toList(growable: false),
        'validation': validation?.toJson(),
        'marketInsight': marketInsight?.toJson(),
        'intradayExtra': intradayExtra.map((e) => e.toJson()).toList(growable: false),
      };

  factory DashboardCachePayload.fromJson(Map<String, dynamic> json) {
    return DashboardCachePayload(
      generatedAtIso: (json['generatedAtIso'] ?? '').toString(),
      strategyStatus: StrategyStatus.fromJson(json['strategyStatus'] as Map<String, dynamic>? ?? const {}),
      selectedStrategy: StrategyKindX.tryParse(json['selectedStrategy']?.toString()),
      marketOverview: MarketOverview.fromJson(json['marketOverview'] as Map<String, dynamic>? ?? const {}),
      candidates: (json['candidates'] as List<dynamic>? ?? const [])
          .map((e) => StockCandidate.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      validation: json['validation'] is Map<String, dynamic>
          ? StrategyValidation.fromJson(json['validation'] as Map<String, dynamic>)
          : null,
      marketInsight: json['marketInsight'] is Map<String, dynamic>
          ? MarketInsight.fromJson(json['marketInsight'] as Map<String, dynamic>)
          : null,
      intradayExtra: (json['intradayExtra'] as List<dynamic>? ?? const [])
          .map((e) => StockCandidate.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  String toRaw() => jsonEncode(toJson());
}
