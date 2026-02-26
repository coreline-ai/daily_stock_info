enum StrategyKind { premarket, intraday, close }

extension StrategyKindX on StrategyKind {
  String get value => switch (this) {
    StrategyKind.premarket => 'premarket',
    StrategyKind.intraday => 'intraday',
    StrategyKind.close => 'close',
  };

  String get label => switch (this) {
    StrategyKind.premarket => '장전 전략',
    StrategyKind.intraday => '장중 전략',
    StrategyKind.close => '종가 전략',
  };

  String get shortLabel => switch (this) {
    StrategyKind.premarket => '장전',
    StrategyKind.intraday => '장중',
    StrategyKind.close => '종가',
  };

  static StrategyKind fromValue(String raw) {
    return StrategyKind.values.firstWhere(
      (it) => it.value == raw,
      orElse: () => StrategyKind.close,
    );
  }
}

class StrategyStatus {
  const StrategyStatus({
    required this.timezone,
    required this.nowKstIso,
    required this.requestedDate,
    required this.availableStrategies,
    required this.defaultStrategy,
    required this.messages,
  });

  final String timezone;
  final String nowKstIso;
  final String requestedDate;
  final List<StrategyKind> availableStrategies;
  final StrategyKind? defaultStrategy;
  final Map<StrategyKind, String> messages;
}
