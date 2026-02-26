import 'package:mobile_app_entire/domain/entities/strategy.dart';

class StrategyWindowService {
  const StrategyWindowService();

  StrategyStatus resolve({
    required DateTime nowKst,
    required DateTime requestedDate,
  }) {
    final nowDate = DateTime(nowKst.year, nowKst.month, nowKst.day);
    final reqDate = DateTime(
      requestedDate.year,
      requestedDate.month,
      requestedDate.day,
    );
    final messages = <StrategyKind, String>{
      StrategyKind.premarket: '',
      StrategyKind.intraday: '',
      StrategyKind.close: '',
    };

    if (reqDate.isAfter(nowDate)) {
      const msg = '미래 날짜는 조회할 수 없습니다.';
      return StrategyStatus(
        timezone: 'Asia/Seoul',
        nowKstIso: nowKst.toIso8601String(),
        requestedDate: _iso(reqDate),
        availableStrategies: const [],
        defaultStrategy: null,
        messages: {
          StrategyKind.premarket: msg,
          StrategyKind.intraday: msg,
          StrategyKind.close: msg,
        },
      );
    }

    if (reqDate.isBefore(nowDate)) {
      return StrategyStatus(
        timezone: 'Asia/Seoul',
        nowKstIso: nowKst.toIso8601String(),
        requestedDate: _iso(reqDate),
        availableStrategies: const [StrategyKind.premarket, StrategyKind.close],
        defaultStrategy: StrategyKind.close,
        messages: {
          StrategyKind.premarket: '과거 거래일 장전 리플레이 조회가 가능합니다.',
          StrategyKind.intraday: '장중 전략은 당일 장중 시간에만 조회할 수 있습니다.',
          StrategyKind.close: '과거 거래일 종가 리플레이 조회가 가능합니다.',
        },
      );
    }

    final minutes = nowKst.hour * 60 + nowKst.minute;
    final premarketStart = 8 * 60;
    final intradayStart = 9 * 60 + 5;
    final closeStart = 15 * 60;
    final intradayEnd = 15 * 60 + 20;

    List<StrategyKind> available;
    StrategyKind? defaultStrategy;

    if (minutes < premarketStart) {
      available = const [StrategyKind.premarket];
      defaultStrategy = StrategyKind.premarket;
      messages[StrategyKind.premarket] =
          '08:00(KST) 이전에는 전일 데이터 기반 장전 리플레이를 제공합니다.';
      messages[StrategyKind.intraday] = '장중 전략은 09:05~15:20(KST) 사이 조회 가능합니다.';
      messages[StrategyKind.close] = '종가 전략은 15:00(KST) 이후 조회 가능합니다.';
    } else if (minutes < intradayStart) {
      available = const [StrategyKind.premarket];
      defaultStrategy = StrategyKind.premarket;
      messages[StrategyKind.premarket] = '현재 장전 전략 조회 가능 시간입니다.';
      messages[StrategyKind.intraday] = '장중 전략은 09:05(KST) 이후 조회 가능합니다.';
      messages[StrategyKind.close] = '종가 전략은 15:00(KST) 이후 조회 가능합니다.';
    } else if (minutes < closeStart) {
      available = const [StrategyKind.premarket, StrategyKind.intraday];
      defaultStrategy = StrategyKind.intraday;
      messages[StrategyKind.premarket] = '당일 장전 전략 리플레이 조회가 가능합니다.';
      messages[StrategyKind.intraday] = '현재 장중 전략 조회 가능 시간입니다.';
      messages[StrategyKind.close] = '종가 전략은 15:00(KST) 이후 조회 가능합니다.';
    } else if (minutes <= intradayEnd) {
      available = const [
        StrategyKind.premarket,
        StrategyKind.intraday,
        StrategyKind.close,
      ];
      defaultStrategy = StrategyKind.intraday;
      messages[StrategyKind.premarket] = '당일 장전 전략 리플레이 조회가 가능합니다.';
      messages[StrategyKind.intraday] = '현재 장중 전략 조회 가능 시간입니다.';
      messages[StrategyKind.close] = '현재 종가 전략 조회 가능 시간입니다.';
    } else {
      available = const [StrategyKind.premarket, StrategyKind.close];
      defaultStrategy = StrategyKind.close;
      messages[StrategyKind.premarket] = '당일 장전 전략 리플레이 조회가 가능합니다.';
      messages[StrategyKind.intraday] = '장중 전략은 15:20(KST)에 마감되었습니다.';
      messages[StrategyKind.close] = '현재 종가 전략 조회 가능 시간입니다.';
    }

    return StrategyStatus(
      timezone: 'Asia/Seoul',
      nowKstIso: nowKst.toIso8601String(),
      requestedDate: _iso(reqDate),
      availableStrategies: available,
      defaultStrategy: defaultStrategy,
      messages: messages,
    );
  }

  String _iso(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}
