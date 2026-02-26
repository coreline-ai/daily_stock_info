import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/failure/app_failure.dart';
import 'package:mobile_app_entire/core/logger/app_logger.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/core/time/kst_clock.dart';
import 'package:mobile_app_entire/data/dto/news_dto.dart';
import 'package:mobile_app_entire/data/dto/quote_dto.dart';
import 'package:mobile_app_entire/data/dto/time_series_dto.dart';
import 'package:mobile_app_entire/data/gateways/finnhub_gateway.dart';
import 'package:mobile_app_entire/data/gateways/google_news_rss_gateway.dart';
import 'package:mobile_app_entire/data/gateways/naver_free_market_gateway.dart';
import 'package:mobile_app_entire/data/gateways/twelve_data_gateway.dart';
import 'package:mobile_app_entire/data/local/app_database.dart';
import 'package:mobile_app_entire/data/repositories/dashboard_repository_impl.dart';
import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/domain/repositories/credential_repository.dart';
import 'package:mobile_app_entire/domain/services/scoring_service.dart';
import 'package:mobile_app_entire/domain/services/strategy_window_service.dart';
import 'package:mobile_app_entire/domain/value_objects/strategy_weights.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('no-key free mode succeeds with free data and dataMode=free', () async {
    final repository = _makeRepository(
      database: database,
      credentials: ApiCredentials.empty,
      freeBarsProvider: (ticker) async => _bars(seed: ticker.hashCode),
      googleNewsProvider: (ticker, companyName) async => const ['삼성전자 호재 뉴스'],
      premiumBarsProvider: (symbol, apiKey) async => const [],
    );

    final result = await repository.load(
      const DashboardQuery(
        date: '2026-02-26',
        strategy: StrategyKind.premarket,
        weights: StrategyWeights.balanced,
      ),
    );

    expect(result.isSuccess, isTrue);
    result.when(
      success: (snapshot) {
        expect(snapshot.dataMode, 'free');
        expect(snapshot.candidates, isNotEmpty);
      },
      failure: (failure) => fail('unexpected failure: ${failure.message}'),
    );
  });

  test('no-key mode skips missing symbols and records warnings', () async {
    final repository = _makeRepository(
      database: database,
      credentials: ApiCredentials.empty,
      freeBarsProvider: (ticker) async {
        if (ticker == '005930') {
          return _bars(seed: 1);
        }
        return const [];
      },
      googleNewsProvider: (ticker, companyName) async => const [],
      premiumBarsProvider: (symbol, apiKey) async => const [],
    );

    final result = await repository.load(
      const DashboardQuery(
        date: '2026-02-26',
        strategy: StrategyKind.premarket,
        weights: StrategyWeights.balanced,
      ),
    );

    expect(result.isSuccess, isTrue);
    result.when(
      success: (snapshot) {
        expect(snapshot.candidates, isNotEmpty);
        expect(snapshot.dataWarnings, isNotEmpty);
      },
      failure: (failure) => fail('unexpected failure: ${failure.message}'),
    );
  });

  test('no-key mode returns network failure when all symbols fail', () async {
    final repository = _makeRepository(
      database: database,
      credentials: ApiCredentials.empty,
      freeBarsProvider: (_) async => const [],
      googleNewsProvider: (ticker, companyName) async => const [],
      premiumBarsProvider: (symbol, apiKey) async => const [],
    );

    final result = await repository.load(
      const DashboardQuery(
        date: '2026-02-26',
        strategy: StrategyKind.premarket,
        weights: StrategyWeights.balanced,
      ),
    );

    expect(result.isFailure, isTrue);
    result.when(
      success: (_) => fail('expected failure'),
      failure: (failure) {
        expect(failure, isA<NetworkFailure>());
      },
    );
  });

  test(
    'valid premium keys + partial premium failures => dataMode=mixed',
    () async {
      const creds = ApiCredentials(
        twelveDataKey: 'td-key',
        finnhubKey: 'fh-key',
        glmKey: '',
        glmBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      );

      final repository = _makeRepository(
        database: database,
        credentials: creds,
        premiumBarsProvider: (symbol, _) async {
          if (symbol.contains('005930')) {
            return _bars(seed: 11);
          }
          throw Exception('premium fail');
        },
        freeBarsProvider: (ticker) async => _bars(seed: ticker.hashCode),
        googleNewsProvider: (ticker, companyName) async => const ['무료 뉴스'],
      );

      final result = await repository.load(
        const DashboardQuery(
          date: '2026-02-26',
          strategy: StrategyKind.premarket,
          weights: StrategyWeights.balanced,
        ),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (snapshot) {
          expect(snapshot.dataMode, 'mixed');
        },
        failure: (failure) => fail('unexpected failure: ${failure.message}'),
      );
    },
  );

  test('strategy query changes ranking in dashboard repository', () async {
    final barsByTicker = <String, List<TimeSeriesEntryDto>>{
      '005930': _barsFromSeries(_seriesMomentum(), baseVolume: 4200000),
      '000660': _barsFromSeries(_seriesStable(), baseVolume: 1200000),
      '035420': _barsFromSeries(_seriesRebound(), baseVolume: 520000),
      '051910': _barsFromSeries(_seriesWeak(), baseVolume: 380000),
    };

    final repository = _makeRepository(
      database: database,
      credentials: ApiCredentials.empty,
      freeBarsProvider: (ticker) async =>
          barsByTicker[ticker] ?? _bars(seed: 5),
      googleNewsProvider: (ticker, companyName) async {
        switch (ticker) {
          case '035420':
            return const ['실적 개선 기대', '신규 수주 확대'];
          case '005930':
            return const ['반도체 업황 개선'];
          default:
            return const ['중립 뉴스'];
        }
      },
      premiumBarsProvider: (symbol, apiKey) async => const [],
    );

    Future<String> topCode(StrategyKind strategy) async {
      final result = await repository.load(
        DashboardQuery(
          date: '2026-02-26',
          strategy: strategy,
          weights: StrategyWeights.balanced,
        ),
      );
      return result.when(
        success: (snapshot) => snapshot.candidates.first.code,
        failure: (failure) => throw Exception(failure.message),
      );
    }

    final pre = await topCode(StrategyKind.premarket);
    final intra = await topCode(StrategyKind.intraday);
    final close = await topCode(StrategyKind.close);
    expect({pre, intra, close}.length, greaterThanOrEqualTo(2));
  });
}

DashboardRepositoryImpl _makeRepository({
  required AppDatabase database,
  required ApiCredentials credentials,
  required Future<List<TimeSeriesEntryDto>> Function(String ticker)
  freeBarsProvider,
  required Future<List<String>> Function(String ticker, String companyName)
  googleNewsProvider,
  required Future<List<TimeSeriesEntryDto>> Function(
    String symbol,
    String apiKey,
  )
  premiumBarsProvider,
}) {
  return DashboardRepositoryImpl(
    twelveDataGateway: _FakeTwelveDataGateway(onFetch: premiumBarsProvider),
    finnhubGateway: _FakeFinnhubGateway(),
    naverFreeMarketGateway: _FakeNaverFreeMarketGateway(
      onBars: freeBarsProvider,
    ),
    googleNewsRssGateway: _FakeGoogleNewsGateway(onNews: googleNewsProvider),
    credentialRepository: _FakeCredentialRepository(credentials),
    strategyWindowService: const StrategyWindowService(),
    scoringService: const ScoringService(),
    database: database,
    clock: _FixedClock(),
    logger: AppLogger(),
  );
}

List<TimeSeriesEntryDto> _bars({required int seed}) {
  final out = <TimeSeriesEntryDto>[];
  var base = 100 + (seed % 13);
  for (var i = 0; i < 40; i++) {
    base += 1;
    final day = ((i % 28) + 1).toString().padLeft(2, '0');
    out.add(
      TimeSeriesEntryDto(
        datetime: '2026-01-$day',
        open: base.toDouble(),
        high: (base + 2).toDouble(),
        low: (base - 1).toDouble(),
        close: (base + 1).toDouble(),
        volume: (100000 + (i * 1000)).toDouble(),
      ),
    );
  }
  return out;
}

List<TimeSeriesEntryDto> _barsFromSeries(
  List<double> closes, {
  required double baseVolume,
}) {
  final out = <TimeSeriesEntryDto>[];
  for (var i = 0; i < closes.length; i++) {
    final close = closes[i];
    final open = i == 0 ? close : closes[i - 1];
    final high = (close > open ? close : open) + 1.2;
    final low = (close < open ? close : open) - 1.1;
    final day = ((i % 28) + 1).toString().padLeft(2, '0');
    final volume = baseVolume + ((i % 2 == 0) ? 120000 : -70000);
    out.add(
      TimeSeriesEntryDto(
        datetime: '2026-01-$day',
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
      ),
    );
  }
  return out;
}

List<double> _seriesMomentum() {
  final out = <double>[];
  var price = 90.0;
  for (var i = 0; i < 40; i++) {
    price += 1.7 + (i.isEven ? 2.8 : -1.4);
    out.add(double.parse(price.toStringAsFixed(2)));
  }
  return out;
}

List<double> _seriesStable() {
  final out = <double>[];
  var price = 120.0;
  for (var i = 0; i < 40; i++) {
    price += 0.38 + (i % 5 == 0 ? -0.08 : 0.03);
    out.add(double.parse(price.toStringAsFixed(2)));
  }
  return out;
}

List<double> _seriesRebound() {
  final out = <double>[];
  var price = 180.0;
  for (var i = 0; i < 30; i++) {
    price += -1.5 + (i % 3 == 0 ? 0.2 : -0.25);
    out.add(double.parse(price.toStringAsFixed(2)));
  }
  for (var i = 30; i < 40; i++) {
    price += 1.35 + (i % 2 == 0 ? 0.35 : -0.12);
    out.add(double.parse(price.toStringAsFixed(2)));
  }
  return out;
}

List<double> _seriesWeak() {
  final out = <double>[];
  var price = 140.0;
  for (var i = 0; i < 40; i++) {
    price += -0.55 + (i % 4 == 0 ? 0.12 : -0.09);
    out.add(double.parse(price.toStringAsFixed(2)));
  }
  return out;
}

class _FakeCredentialRepository implements CredentialRepository {
  const _FakeCredentialRepository(this.credentials);

  final ApiCredentials credentials;

  @override
  Future<Result<void>> clear() async => const Success(null);

  @override
  Future<Result<ApiCredentials>> load() async => Success(credentials);

  @override
  Future<Result<void>> save(ApiCredentials credentials) async =>
      const Success(null);
}

class _FakeTwelveDataGateway extends TwelveDataGateway {
  _FakeTwelveDataGateway({required this.onFetch}) : super(dio: Dio());

  final Future<List<TimeSeriesEntryDto>> Function(String symbol, String apiKey)
  onFetch;

  @override
  Future<List<TimeSeriesEntryDto>> fetchTimeSeries({
    required String symbol,
    required String apiKey,
    String interval = '1day',
    int outputSize = 120,
  }) {
    return onFetch(symbol, apiKey);
  }
}

class _FakeFinnhubGateway extends FinnhubGateway {
  _FakeFinnhubGateway() : super(dio: Dio());

  @override
  Future<QuoteDto> fetchQuote({
    required String symbol,
    required String apiKey,
  }) async {
    return const QuoteDto(current: 101, change: 1, percentChange: 1.2);
  }

  @override
  Future<List<NewsDto>> fetchCompanyNews({
    required String symbol,
    required String apiKey,
    required String from,
    required String to,
  }) async {
    if (symbol.contains('005930')) {
      return const [
        NewsDto(headline: '프리미엄 뉴스', summary: '', url: '', datetime: 0),
      ];
    }
    return const [];
  }
}

class _FakeNaverFreeMarketGateway extends NaverFreeMarketGateway {
  _FakeNaverFreeMarketGateway({required this.onBars})
    : super(apiDio: Dio(), financeDio: Dio());

  final Future<List<TimeSeriesEntryDto>> Function(String ticker) onBars;

  @override
  Future<List<TimeSeriesEntryDto>> fetchDailyBars(
    String ticker, {
    int days = 120,
  }) {
    return onBars(ticker);
  }

  @override
  Future<List<NewsDto>> fetchStockNews({
    required String ticker,
    int limit = 20,
  }) async {
    return const [
      NewsDto(headline: '네이버 무료 뉴스', summary: '', url: '', datetime: 0),
    ];
  }
}

class _FakeGoogleNewsGateway extends GoogleNewsRssGateway {
  _FakeGoogleNewsGateway({required this.onNews}) : super(dio: Dio());

  final Future<List<String>> Function(String ticker, String companyName) onNews;

  @override
  Future<List<String>> fetchNewsTitles({
    required String ticker,
    required String companyName,
    int limit = 20,
  }) {
    return onNews(ticker, companyName);
  }
}

class _FixedClock extends KstClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 2, 26, 6, 0, 0);
}
