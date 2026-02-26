import 'dart:math' as math;

import 'package:mobile_app_entire/domain/entities/market.dart';
import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/domain/value_objects/strategy_weights.dart';

class SymbolMarketSnapshot {
  const SymbolMarketSnapshot({
    required this.code,
    required this.name,
    required this.sector,
    required this.price,
    required this.changeRate,
    required this.closeSeries,
    required this.volumeSeries,
    required this.newsSentiment,
    required this.newsCount,
    required this.barsFromApi,
    required this.quoteFromApi,
    required this.newsFromApi,
  });

  final String code;
  final String name;
  final String sector;
  final double price;
  final double changeRate;
  final List<double> closeSeries;
  final List<double> volumeSeries;
  final double newsSentiment;
  final int newsCount;
  final bool barsFromApi;
  final bool quoteFromApi;
  final bool newsFromApi;
}

class ScoringService {
  const ScoringService();

  List<StockCandidate> scoreCandidates({
    required List<SymbolMarketSnapshot> snapshots,
    required StrategyWeights weights,
    required StrategyKind strategy,
  }) {
    final normalizedWeights = weights.normalize();
    final presetStyle = _presetStyle(normalizedWeights);
    final rankedCandidates = <_CandidateRank>[];

    for (final snapshot in snapshots) {
      if (snapshot.closeSeries.length < 5) {
        continue;
      }
      final rsi = _estimateRsi(snapshot.closeSeries);
      final momentum20 = _momentum(snapshot.closeSeries, window: 20);
      final momentum5 = _momentum(snapshot.closeSeries, window: 5);
      final stability = _stability(snapshot.closeSeries);
      final volatility = _volatility(snapshot.closeSeries);
      final drawdown = _maxDrawdown(snapshot.closeSeries);
      final liquidity = _liquidity(snapshot.volumeSeries);
      final newsMomentum = snapshot.newsSentiment.clamp(-1.0, 1.0).toDouble();
      final newsCoverage = (snapshot.newsCount.clamp(0, 20).toDouble() / 20.0);

      final factors = _strategyComponents(
        strategy: strategy,
        rsi: rsi,
        momentum20: momentum20,
        momentum5: momentum5,
        stability: stability,
        volatility: volatility,
        drawdown: drawdown,
        liquidity: liquidity,
        newsMomentum: newsMomentum,
        newsCoverage: newsCoverage,
        changeRate: snapshot.changeRate,
      );

      final baseScore =
          (factors.returnScore * normalizedWeights.returnWeight) +
          (factors.stabilityScore * normalizedWeights.stabilityWeight) +
          (factors.marketScore * normalizedWeights.marketWeight);
      final rankingScore = _applyPresetTilt(
        style: presetStyle,
        strategy: strategy,
        baseScore: baseScore,
        momentum20: momentum20,
        momentum5: momentum5,
        stability: stability,
        volatility: volatility,
        drawdown: drawdown,
        liquidity: liquidity,
        newsMomentum: newsMomentum,
      );
      final score = _displayScore(rankingScore);

      final target =
          snapshot.price *
          (1 + _targetGain(strategy, score, normalizedWeights, presetStyle));
      final stop =
          snapshot.price *
          (1 - _stopGap(strategy, score, normalizedWeights, presetStyle));

      rankedCandidates.add(
        _CandidateRank(
          rankingScore: rankingScore,
          candidate: StockCandidate(
            rank: 0,
            name: snapshot.name,
            code: snapshot.code,
            score: double.parse(score.toStringAsFixed(2)),
            changeRate: snapshot.changeRate,
            price: snapshot.price,
            targetPrice: double.parse(target.toStringAsFixed(2)),
            stopLoss: double.parse(stop.toStringAsFixed(2)),
            tags: _buildTags(
              strategy: strategy,
              style: presetStyle,
              rsi: rsi,
              momentum20: momentum20,
              momentum5: momentum5,
              stability: stability,
              volatility: volatility,
              newsSentiment: newsMomentum,
              newsCount: snapshot.newsCount,
            ),
            sector: snapshot.sector,
            sparkline60: _sparkline(snapshot.closeSeries),
            summary: _buildSummary(
              strategy: strategy,
              style: presetStyle,
              momentum20: momentum20,
              momentum5: momentum5,
              stability: stability,
              volatility: volatility,
              newsSentiment: newsMomentum,
              newsCount: snapshot.newsCount,
            ),
            strongRecommendation: false,
          ),
        ),
      );
    }

    rankedCandidates.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));
    return rankedCandidates
        .asMap()
        .entries
        .map((entry) {
          final rank = entry.key + 1;
          return entry.value.candidate.copyWith(
            rank: rank,
            strongRecommendation: rank <= 5,
          );
        })
        .toList(growable: false);
  }

  ({double returnScore, double stabilityScore, double marketScore})
  _strategyComponents({
    required StrategyKind strategy,
    required double rsi,
    required double momentum20,
    required double momentum5,
    required double stability,
    required double volatility,
    required double drawdown,
    required double liquidity,
    required double newsMomentum,
    required double newsCoverage,
    required double changeRate,
  }) {
    final rsiMiddle = (1 - ((rsi - 50).abs() / 50)).clamp(0, 1).toDouble();
    final oversold = ((40 - rsi) / 20).clamp(0, 1).toDouble();
    final overbought = ((rsi - 70) / 20).clamp(0, 1).toDouble();

    switch (strategy) {
      case StrategyKind.premarket:
        return (
          returnScore: _clamp10(
            4.2 +
                (momentum20 * 10.0) +
                (changeRate / 3.5) +
                (newsMomentum * 2.2) +
                (oversold * 1.2) -
                (drawdown * 2.5) -
                (overbought * 4.5),
          ),
          stabilityScore: _clamp10(
            4.5 +
                (stability * 6.2) -
                (volatility * 2.2) +
                (rsiMiddle * 1.4) -
                (overbought * 1.5),
          ),
          marketScore: _clamp10(
            4.0 +
                (liquidity * 4.5) +
                (newsCoverage * 1.6) +
                (newsMomentum * 1.4) +
                (oversold * 0.8) -
                (overbought * 1.2),
          ),
        );
      case StrategyKind.intraday:
        return (
          returnScore: _clamp10(
            3.8 +
                (momentum5 * 25.0) +
                (momentum20 * 6.0) +
                (liquidity * 2.4) -
                (drawdown * 2.2) -
                (overbought * 0.6),
          ),
          stabilityScore: _clamp10(
            4.0 +
                (stability * 4.2) +
                (liquidity * 2.0) -
                (volatility * 2.8) -
                (overbought * 1.0),
          ),
          marketScore: _clamp10(
            4.2 +
                (liquidity * 5.0) +
                (changeRate / 2.4) +
                (newsCoverage * 1.1) +
                (momentum5 * 8.0) -
                (volatility * 1.8),
          ),
        );
      case StrategyKind.close:
        return (
          returnScore: _clamp10(
            4.0 +
                (momentum20 * 8.0) +
                (rsiMiddle * 1.4) +
                (newsMomentum * 1.2) -
                (drawdown * 7.0) -
                (volatility * 4.8) -
                (overbought * 3.4),
          ),
          stabilityScore: _clamp10(
            4.8 +
                (stability * 8.4) -
                (drawdown * 8.0) -
                (volatility * 5.0) +
                (rsiMiddle * 1.4) -
                (overbought * 2.0),
          ),
          marketScore: _clamp10(
            4.1 +
                (liquidity * 3.6) +
                (newsCoverage * 1.2) +
                (newsMomentum * 1.6) +
                (stability * 1.8) -
                (overbought * 1.4) -
                (volatility * 1.4),
          ),
        );
    }
  }

  double _applyPresetTilt({
    required _PresetStyle style,
    required StrategyKind strategy,
    required double baseScore,
    required double momentum20,
    required double momentum5,
    required double stability,
    required double volatility,
    required double drawdown,
    required double liquidity,
    required double newsMomentum,
  }) {
    switch (style) {
      case _PresetStyle.aggressive:
        final growthEdge =
            (math.max(0, momentum20) * 4.0) +
            (math.max(0, momentum5) * 3.0) +
            (liquidity * 1.5) +
            (newsMomentum > 0 ? newsMomentum * 1.2 : newsMomentum * 0.4);
        final riskPenalty = (drawdown * 1.8) + (volatility * 0.8);
        return baseScore + growthEdge - riskPenalty;
      case _PresetStyle.defensive:
        final safetyEdge =
            (stability * 3.2) +
            ((1 - drawdown).clamp(0, 1) * 2.0) +
            (liquidity * 0.6);
        final fragilityPenalty =
            (volatility * 4.8) +
            (drawdown * 5.5) +
            (math.max(0, -momentum20) * 1.2) +
            (math.max(0, -newsMomentum) * 0.8);
        return baseScore + safetyEdge - fragilityPenalty;
      case _PresetStyle.balanced:
        final balanceEdge =
            (stability * 1.3) +
            (math.max(0, momentum20) * 1.0) +
            (liquidity * 0.6) -
            (drawdown * 1.8) -
            (volatility * 0.8);
        final strategyBias = switch (strategy) {
          StrategyKind.premarket => newsMomentum * 0.5,
          StrategyKind.intraday => momentum5 * 1.4,
          StrategyKind.close => (stability * 0.8) - (volatility * 0.4),
        };
        return baseScore + balanceEdge + strategyBias;
    }
  }

  double _displayScore(double rankingScore) {
    final scaled = 5 + ((rankingScore - 5) * 0.8);
    return _clamp10(scaled);
  }

  double _targetGain(
    StrategyKind strategy,
    double score,
    StrategyWeights normalizedWeights,
    _PresetStyle style,
  ) {
    final strategyBase = switch (strategy) {
      StrategyKind.premarket => 0.014,
      StrategyKind.intraday => 0.020,
      StrategyKind.close => 0.016,
    };
    final scoreFactor = ((score - 5) / 180).clamp(-0.01, 0.035).toDouble();
    final presetFactor = switch (style) {
      _PresetStyle.aggressive => 0.005,
      _PresetStyle.defensive => -0.002,
      _PresetStyle.balanced => 0.0,
    };
    final weightFactor = (normalizedWeights.returnWeight * 0.01);
    return (strategyBase + scoreFactor + presetFactor + weightFactor)
        .clamp(0.01, 0.08)
        .toDouble();
  }

  double _stopGap(
    StrategyKind strategy,
    double score,
    StrategyWeights normalizedWeights,
    _PresetStyle style,
  ) {
    final strategyBase = switch (strategy) {
      StrategyKind.premarket => 0.013,
      StrategyKind.intraday => 0.016,
      StrategyKind.close => 0.011,
    };
    final scoreFactor = ((10 - score) / 170).clamp(0.0, 0.05).toDouble();
    final presetFactor = switch (style) {
      _PresetStyle.aggressive => 0.004,
      _PresetStyle.defensive => -0.003,
      _PresetStyle.balanced => 0.0,
    };
    final weightFactor = ((1 - normalizedWeights.stabilityWeight) * 0.004);
    return (strategyBase + scoreFactor + presetFactor + weightFactor)
        .clamp(0.008, 0.07)
        .toDouble();
  }

  _PresetStyle _presetStyle(StrategyWeights normalizedWeights) {
    if (normalizedWeights.returnWeight >=
            normalizedWeights.stabilityWeight + 0.15 &&
        normalizedWeights.returnWeight >= normalizedWeights.marketWeight) {
      return _PresetStyle.aggressive;
    }
    if (normalizedWeights.stabilityWeight >=
            normalizedWeights.returnWeight + 0.15 &&
        normalizedWeights.stabilityWeight >= normalizedWeights.marketWeight) {
      return _PresetStyle.defensive;
    }
    return _PresetStyle.balanced;
  }

  MarketOverview buildOverview(List<StockCandidate> candidates) {
    final up = candidates.where((c) => c.changeRate > 0).length;
    final down = candidates.where((c) => c.changeRate < 0).length;
    final steady = math.max(0, candidates.length - up - down);
    final warnings = <String>[];

    if (candidates.isEmpty) {
      warnings.add('추천 종목이 생성되지 않았습니다. API 키 또는 네트워크를 확인하세요.');
    }
    if (down > up * 2 && candidates.isNotEmpty) {
      warnings.add('시장 약세 구간입니다. 리스크 관리를 보수적으로 적용하세요.');
    }

    return MarketOverview(
      up: up,
      steady: steady,
      down: down,
      warnings: warnings,
    );
  }

  MarketInsight buildInsight(MarketOverview overview) {
    if (overview.down > overview.up * 2) {
      return const MarketInsight(
        riskFactors: ['시장 전반 하락 압력이 우세합니다.', '안정성 중심 접근이 유리합니다.'],
        conclusion: '보수적 진입과 엄격한 손절 규칙을 권장합니다.',
      );
    }
    if (overview.up > overview.down * 2) {
      return const MarketInsight(
        riskFactors: ['주도 섹터 모멘텀이 강합니다.', '단기 과열 리스크를 주의하세요.'],
        conclusion: '추세 추종과 분할 익절 전략이 유효합니다.',
      );
    }
    return const MarketInsight(
      riskFactors: ['종목 선별 장세가 이어지고 있습니다.', '섹터 간 성과 편차가 큰 구간입니다.'],
      conclusion: '팩터 가중치 기반 선별이 유효합니다.',
    );
  }

  double _estimateRsi(List<double> closes) {
    if (closes.length < 15) {
      return 50;
    }
    var gain = 0.0;
    var loss = 0.0;
    for (var i = closes.length - 14; i < closes.length; i++) {
      final prev = closes[i - 1];
      final curr = closes[i];
      final diff = curr - prev;
      if (diff > 0) {
        gain += diff;
      } else {
        loss += diff.abs();
      }
    }
    if (loss == 0) {
      return 70;
    }
    final rs = gain / loss;
    return 100 - (100 / (1 + rs));
  }

  double _momentum(List<double> closes, {required int window}) {
    if (window <= 0 || closes.length < window + 1) {
      return 0;
    }
    final first = closes[closes.length - (window + 1)];
    final last = closes.last;
    if (first == 0) {
      return 0;
    }
    return (last - first) / first;
  }

  double _stability(List<double> closes) {
    if (closes.length < 20) {
      return 0;
    }
    final returns = <double>[];
    for (var i = 1; i < closes.length; i++) {
      final prev = closes[i - 1];
      if (prev == 0) {
        continue;
      }
      returns.add((closes[i] - prev) / prev);
    }
    if (returns.isEmpty) {
      return 0;
    }
    final mean = returns.reduce((a, b) => a + b) / returns.length;
    final variance =
        returns
            .map((r) => math.pow((r - mean), 2))
            .fold<double>(0, (acc, v) => acc + v) /
        returns.length;
    final std = math.sqrt(variance);
    return 1 - (std * 12).clamp(0, 1);
  }

  double _volatility(List<double> closes) {
    if (closes.length < 10) {
      return 0.35;
    }
    final returns = <double>[];
    for (var i = 1; i < closes.length; i++) {
      final prev = closes[i - 1];
      if (prev <= 0) {
        continue;
      }
      returns.add((closes[i] - prev) / prev);
    }
    if (returns.isEmpty) {
      return 0.35;
    }
    final mean = returns.reduce((a, b) => a + b) / returns.length;
    final variance =
        returns
            .map((r) => math.pow(r - mean, 2))
            .fold<double>(0, (acc, v) => acc + v) /
        returns.length;
    return (math.sqrt(variance) * 20).clamp(0, 1).toDouble();
  }

  double _maxDrawdown(List<double> closes) {
    if (closes.isEmpty) {
      return 0;
    }
    var peak = closes.first;
    var maxDrawdown = 0.0;
    for (final close in closes) {
      if (close > peak) {
        peak = close;
      }
      if (peak <= 0) {
        continue;
      }
      final drawdown = (peak - close) / peak;
      if (drawdown > maxDrawdown) {
        maxDrawdown = drawdown;
      }
    }
    return maxDrawdown.clamp(0, 1).toDouble();
  }

  double _liquidity(List<double> volumes) {
    if (volumes.isEmpty) {
      return 0;
    }
    final recent = volumes.length <= 20
        ? volumes
        : volumes.sublist(volumes.length - 20);
    final avg = recent.reduce((a, b) => a + b) / recent.length;
    if (avg <= 0) {
      return 0;
    }
    final norm = (math.log(avg + 1) / 16).clamp(0, 1);
    return norm.toDouble();
  }

  List<String> _buildTags({
    required StrategyKind strategy,
    required _PresetStyle style,
    required double rsi,
    required double momentum20,
    required double momentum5,
    required double stability,
    required double volatility,
    required double newsSentiment,
    required int newsCount,
  }) {
    final tags = <String>[strategy.label, _presetLabel(style)];
    if (momentum5 > 0.03) {
      tags.add('단기 강세');
    }
    if (momentum20 > 0.06) {
      tags.add('중기 상승');
    }
    if (rsi >= 60) {
      tags.add('RSI 강세');
    } else if (rsi <= 35) {
      tags.add('반등 후보');
    }
    if (stability >= 0.65 && volatility <= 0.35) {
      tags.add('변동성 낮음');
    } else if (volatility >= 0.6) {
      tags.add('변동성 높음');
    }
    if (newsCount >= 3) {
      tags.add('뉴스 $newsCount건');
    }
    if (newsSentiment >= 0.2) {
      tags.add('뉴스 우호');
    } else if (newsSentiment <= -0.2) {
      tags.add('뉴스 경계');
    }
    return tags;
  }

  String _buildSummary({
    required StrategyKind strategy,
    required _PresetStyle style,
    required double momentum20,
    required double momentum5,
    required double stability,
    required double volatility,
    required double newsSentiment,
    required int newsCount,
  }) {
    final momentumText = momentum20 >= 0.03
        ? '중기 상승 추세'
        : momentum5 >= 0.02
        ? '단기 반등 구간'
        : '모멘텀 약세 구간';
    final stabilityText = stability >= 0.6 ? '안정형' : '변동성 확대';
    final riskText = volatility >= 0.6 ? '고변동' : '리스크 보통';
    final newsText = newsCount == 0
        ? '뉴스 데이터 없음'
        : newsSentiment >= 0.2
        ? '뉴스 우호'
        : newsSentiment <= -0.2
        ? '뉴스 경계'
        : '뉴스 중립';
    return '${strategy.label} · ${_presetLabel(style)}: $momentumText, $stabilityText, $riskText, $newsText';
  }

  String _presetLabel(_PresetStyle style) {
    switch (style) {
      case _PresetStyle.aggressive:
        return '공격형';
      case _PresetStyle.defensive:
        return '방어형';
      case _PresetStyle.balanced:
        return '균형형';
    }
  }

  List<double> _sparkline(List<double> closes) {
    if (closes.isEmpty) {
      return const [];
    }
    if (closes.length <= 60) {
      return closes
          .map((e) => double.parse(e.toStringAsFixed(2)))
          .toList(growable: false);
    }
    final step = closes.length / 60;
    final out = <double>[];
    for (var i = 0; i < 60; i++) {
      final idx = (i * step).floor().clamp(0, closes.length - 1);
      out.add(double.parse(closes[idx].toStringAsFixed(2)));
    }
    return out;
  }

  double _clamp10(double value) => value.clamp(1, 10).toDouble();
}

enum _PresetStyle { aggressive, defensive, balanced }

class _CandidateRank {
  const _CandidateRank({required this.candidate, required this.rankingScore});

  final StockCandidate candidate;
  final double rankingScore;
}
