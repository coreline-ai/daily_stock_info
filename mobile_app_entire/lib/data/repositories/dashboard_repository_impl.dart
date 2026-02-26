import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/failure/app_failure.dart';
import 'package:mobile_app_entire/core/logger/app_logger.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/core/time/kst_clock.dart';
import 'package:mobile_app_entire/data/dto/news_dto.dart';
import 'package:mobile_app_entire/data/dto/time_series_dto.dart';
import 'package:mobile_app_entire/data/gateways/finnhub_gateway.dart';
import 'package:mobile_app_entire/data/gateways/google_news_rss_gateway.dart';
import 'package:mobile_app_entire/data/gateways/naver_free_market_gateway.dart';
import 'package:mobile_app_entire/data/gateways/twelve_data_gateway.dart';
import 'package:mobile_app_entire/data/local/app_database.dart';
import 'package:mobile_app_entire/data/repositories/stock_universe.dart';
import 'package:mobile_app_entire/domain/entities/dashboard.dart';
import 'package:mobile_app_entire/domain/entities/market.dart';
import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/domain/repositories/credential_repository.dart';
import 'package:mobile_app_entire/domain/repositories/dashboard_repository.dart';
import 'package:mobile_app_entire/domain/services/scoring_service.dart';
import 'package:mobile_app_entire/domain/services/strategy_window_service.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl({
    required TwelveDataGateway twelveDataGateway,
    required FinnhubGateway finnhubGateway,
    required NaverFreeMarketGateway naverFreeMarketGateway,
    required GoogleNewsRssGateway googleNewsRssGateway,
    required CredentialRepository credentialRepository,
    required StrategyWindowService strategyWindowService,
    required ScoringService scoringService,
    required AppDatabase database,
    required KstClock clock,
    required AppLogger logger,
  }) : _twelveDataGateway = twelveDataGateway,
       _finnhubGateway = finnhubGateway,
       _naverFreeMarketGateway = naverFreeMarketGateway,
       _googleNewsRssGateway = googleNewsRssGateway,
       _credentialRepository = credentialRepository,
       _strategyWindowService = strategyWindowService,
       _scoringService = scoringService,
       _database = database,
       _clock = clock,
       _logger = logger;

  final TwelveDataGateway _twelveDataGateway;
  final FinnhubGateway _finnhubGateway;
  final NaverFreeMarketGateway _naverFreeMarketGateway;
  final GoogleNewsRssGateway _googleNewsRssGateway;
  final CredentialRepository _credentialRepository;
  final StrategyWindowService _strategyWindowService;
  final ScoringService _scoringService;
  final AppDatabase _database;
  final KstClock _clock;
  final AppLogger _logger;

  static const Duration _barsCacheTtl = Duration(hours: 12);
  static const Duration _newsCacheTtl = Duration(minutes: 30);
  static const int _minBarsForStrategy = 20;

  @override
  Future<Result<DashboardSnapshot>> load(DashboardQuery query) async {
    try {
      final credentialsResult = await _credentialRepository.load();
      final credentials = credentialsResult.when(
        success: (credentials) => credentials,
        failure: (failure) => throw _DashboardFailureException(failure),
      );

      final hasValidPremiumKeys = _hasValidMarketKeys(credentials);
      if (query.strictRealData && !hasValidPremiumKeys) {
        return Failure(
          AuthFailure('실데이터 강제 모드에서는 유효한 TwelveData/Finnhub API 키가 필요합니다.'),
        );
      }

      final requestedDate = DateTime.tryParse(query.date) ?? _clock.nowKst();
      final strategyStatus = _strategyWindowService.resolve(
        nowKst: _clock.nowKst(),
        requestedDate: requestedDate,
      );

      final selectedStrategy =
          strategyStatus.availableStrategies.contains(query.strategy)
          ? query.strategy
          : (strategyStatus.defaultStrategy ?? query.strategy);
      final strategyWarning = strategyStatus.availableStrategies.isEmpty
          ? strategyStatus.messages[selectedStrategy]
          : (!strategyStatus.availableStrategies.contains(query.strategy)
                ? strategyStatus.messages[query.strategy]
                : null);

      final snapshotBuild = await _buildSnapshots(
        credentials: credentials,
        customTickers: query.customTickers,
        strictRealData: query.strictRealData,
        forceRefresh: query.forceRefresh,
      );

      if (snapshotBuild.snapshots.isEmpty) {
        return Failure(
          NetworkFailure(
            query.strictRealData
                ? '실데이터 강제 모드에서 조회 가능한 종목이 없습니다. API 키/쿼터/네트워크를 확인하세요.'
                : '무료 소스 일시 장애 또는 데이터 부족으로 조회 가능한 종목이 없습니다.',
          ),
        );
      }

      final candidates = _scoringService.scoreCandidates(
        snapshots: snapshotBuild.snapshots,
        weights: query.weights,
        strategy: selectedStrategy,
      );
      final overview = _scoringService.buildOverview(candidates);
      final insight = _scoringService.buildInsight(overview);

      List<StockCandidate> intradayExtra = const [];
      if (query.includeIntradayExtra &&
          selectedStrategy != StrategyKind.intraday) {
        intradayExtra = _scoringService
            .scoreCandidates(
              snapshots: snapshotBuild.snapshots,
              weights: query.weights,
              strategy: StrategyKind.intraday,
            )
            .where(
              (item) =>
                  !candidates.take(5).any((main) => main.code == item.code),
            )
            .take(5)
            .toList(growable: false);
      }

      await _persistBacktestRows(
        tradeDate: strategyStatus.requestedDate,
        candidates: candidates.take(5).toList(growable: false),
      );

      final dataWarnings = <String>[];
      if (strategyWarning != null && strategyWarning.isNotEmpty) {
        dataWarnings.add(strategyWarning);
      }
      dataWarnings.addAll(snapshotBuild.dataWarnings);

      _logger.i(
        'dashboard sources mode=${snapshotBuild.dataMode} '
        'symbols_requested=${snapshotBuild.requestedSymbols} '
        'symbols_scored=${snapshotBuild.snapshots.length} '
        'symbols_skipped=${snapshotBuild.skippedSymbols} '
        'news_items_used=${snapshotBuild.newsItemsUsed}',
      );

      return Success(
        DashboardSnapshot(
          strategyStatus: strategyStatus,
          selectedStrategy: selectedStrategy,
          weights: query.weights.normalize(),
          overview: overview,
          candidates: candidates,
          intradayExtra: intradayExtra,
          insight: insight,
          lastUpdated: _clock.nowKst(),
          dataMode: snapshotBuild.dataMode,
          warning: dataWarnings.isEmpty ? null : dataWarnings.join('\n'),
          usedInformation: _buildUsedInformation(
            snapshotBuild: snapshotBuild,
            strictRealData: query.strictRealData,
          ),
          dataWarnings: dataWarnings,
        ),
      );
    } on _DashboardFailureException catch (error) {
      return Failure(error.failure);
    } catch (error) {
      return Failure(UnknownFailure('대시보드 로드에 실패했습니다: $error'));
    }
  }

  Future<_SnapshotBuildResult> _buildSnapshots({
    required ApiCredentials credentials,
    required List<String> customTickers,
    required bool strictRealData,
    required bool forceRefresh,
  }) async {
    final hasPremium = _hasValidMarketKeys(credentials);

    final universe = <UniverseStock>[...defaultUniverse];
    for (final raw in customTickers) {
      final ticker = raw.trim().toUpperCase();
      if (ticker.isEmpty || universe.any((item) => item.ticker == ticker)) {
        continue;
      }
      universe.add(UniverseStock(ticker: ticker, name: ticker, sector: '사용자'));
    }

    final snapshots = <SymbolMarketSnapshot>[];
    final skippedReasons = <String>[];

    var premiumBarsSymbols = 0;
    var freeBarsSymbols = 0;
    var cacheBarsSymbols = 0;
    var staleCacheBarsSymbols = 0;
    var premiumQuoteSymbols = 0;
    var premiumNewsSymbols = 0;
    var googleNewsSymbols = 0;
    var naverNewsSymbols = 0;
    var cacheNewsSymbols = 0;
    var staleCacheNewsSymbols = 0;
    var newsItemsUsed = 0;

    for (final stock in universe) {
      if (!strictRealData && !hasPremium && !_isKrxTicker(stock.ticker)) {
        skippedReasons.add('${stock.ticker}: 무료 모드는 KRX(6자리 코드) 종목만 지원');
        continue;
      }

      final loaded = await _loadSnapshot(
        stock,
        credentials,
        strictRealData: strictRealData,
        forceRefresh: forceRefresh,
      );

      if (loaded == null) {
        skippedReasons.add('${stock.ticker}: 시계열 데이터 부족 또는 소스 장애');
        continue;
      }

      snapshots.add(loaded.snapshot);

      switch (loaded.barsSource) {
        case _BarsSource.premium:
          premiumBarsSymbols += 1;
          break;
        case _BarsSource.free:
          freeBarsSymbols += 1;
          break;
        case _BarsSource.cacheFresh:
          cacheBarsSymbols += 1;
          break;
        case _BarsSource.cacheStale:
          cacheBarsSymbols += 1;
          staleCacheBarsSymbols += 1;
          break;
      }

      if (loaded.quoteFromPremium) {
        premiumQuoteSymbols += 1;
      }

      switch (loaded.newsSource) {
        case _NewsSource.premium:
          premiumNewsSymbols += 1;
          break;
        case _NewsSource.google:
          googleNewsSymbols += 1;
          break;
        case _NewsSource.naver:
          naverNewsSymbols += 1;
          break;
        case _NewsSource.cacheFresh:
          cacheNewsSymbols += 1;
          break;
        case _NewsSource.cacheStale:
          cacheNewsSymbols += 1;
          staleCacheNewsSymbols += 1;
          break;
        case _NewsSource.none:
          break;
      }
      newsItemsUsed += loaded.newsCount;
    }

    var dataMode = 'free';
    final usedPremium =
        premiumBarsSymbols > 0 ||
        premiumQuoteSymbols > 0 ||
        premiumNewsSymbols > 0;
    final usedFree =
        freeBarsSymbols > 0 || googleNewsSymbols > 0 || naverNewsSymbols > 0;
    if (usedPremium && usedFree) {
      dataMode = 'mixed';
    } else if (usedPremium) {
      dataMode = 'premium';
    }

    final dataWarnings = <String>[];
    if (skippedReasons.isNotEmpty) {
      dataWarnings.add('데이터 부족으로 제외된 종목 ${skippedReasons.length}개');
      dataWarnings.addAll(skippedReasons.take(5));
      if (skippedReasons.length > 5) {
        dataWarnings.add('추가 제외 종목 ${skippedReasons.length - 5}개');
      }
    }
    if (staleCacheBarsSymbols > 0 || staleCacheNewsSymbols > 0) {
      dataWarnings.add(
        '무료 소스 장애로 만료 캐시를 사용한 종목이 있습니다. (bars $staleCacheBarsSymbols, news $staleCacheNewsSymbols)',
      );
    }

    return _SnapshotBuildResult(
      snapshots: snapshots,
      requestedSymbols: universe.length,
      skippedSymbols: skippedReasons.length,
      dataMode: dataMode,
      dataWarnings: dataWarnings,
      premiumBarsSymbols: premiumBarsSymbols,
      freeBarsSymbols: freeBarsSymbols,
      cacheBarsSymbols: cacheBarsSymbols,
      staleCacheBarsSymbols: staleCacheBarsSymbols,
      premiumQuoteSymbols: premiumQuoteSymbols,
      premiumNewsSymbols: premiumNewsSymbols,
      googleNewsSymbols: googleNewsSymbols,
      naverNewsSymbols: naverNewsSymbols,
      cacheNewsSymbols: cacheNewsSymbols,
      staleCacheNewsSymbols: staleCacheNewsSymbols,
      newsItemsUsed: newsItemsUsed,
    );
  }

  Future<_LoadedSnapshot?> _loadSnapshot(
    UniverseStock stock,
    ApiCredentials credentials, {
    required bool strictRealData,
    required bool forceRefresh,
  }) async {
    final hasPremium = _hasValidMarketKeys(credentials);

    List<TimeSeriesEntryDto> bars = const [];
    var barsSource = _BarsSource.cacheFresh;

    if (!strictRealData && !forceRefresh) {
      final cache = await _loadBarsFromCache(stock.ticker, allowStale: true);
      if (cache != null) {
        bars = cache.series;
        barsSource = cache.fresh
            ? _BarsSource.cacheFresh
            : _BarsSource.cacheStale;
      }
    }

    if (bars.isEmpty && hasPremium) {
      bars = await _fetchPremiumBars(stock, credentials);
      if (bars.isNotEmpty) {
        barsSource = _BarsSource.premium;
      }
    }

    if (bars.isEmpty && !strictRealData && _isKrxTicker(stock.ticker)) {
      bars = await _fetchFreeBars(stock.ticker);
      if (bars.isNotEmpty) {
        barsSource = _BarsSource.free;
      }
    }

    if (bars.isEmpty && !strictRealData) {
      final cache = await _loadBarsFromCache(stock.ticker, allowStale: true);
      if (cache != null) {
        bars = cache.series;
        barsSource = cache.fresh
            ? _BarsSource.cacheFresh
            : _BarsSource.cacheStale;
      }
    }

    if (bars.length < _minBarsForStrategy) {
      return null;
    }

    final closes = bars.map((e) => e.close).toList(growable: false);
    final volumes = bars.map((e) => e.volume).toList(growable: false);

    var price = closes.last;
    var changeRate = _calcChangeRate(closes);
    var quoteFromPremium = false;

    if (hasPremium) {
      final quote = await _fetchPremiumQuote(stock, credentials);
      if (quote != null) {
        if (quote.current > 0) {
          price = quote.current;
        }
        if (quote.percentChange != 0) {
          changeRate = quote.percentChange;
        }
        quoteFromPremium = true;
      }
    }

    final newsLoad = await _loadNews(
      stock: stock,
      credentials: credentials,
      strictRealData: strictRealData,
      forceRefresh: forceRefresh,
    );

    return _LoadedSnapshot(
      snapshot: SymbolMarketSnapshot(
        code: stock.ticker,
        name: stock.name,
        sector: stock.sector,
        price: price,
        changeRate: changeRate,
        closeSeries: closes,
        volumeSeries: volumes,
        newsSentiment: _estimateNewsSentiment(newsLoad.news),
        newsCount: newsLoad.news.length,
        barsFromApi:
            barsSource == _BarsSource.premium || barsSource == _BarsSource.free,
        quoteFromApi: quoteFromPremium,
        newsFromApi:
            newsLoad.source == _NewsSource.premium ||
            newsLoad.source == _NewsSource.google ||
            newsLoad.source == _NewsSource.naver,
      ),
      barsSource: barsSource,
      quoteFromPremium: quoteFromPremium,
      newsSource: newsLoad.source,
      newsCount: newsLoad.news.length,
    );
  }

  Future<List<TimeSeriesEntryDto>> _fetchPremiumBars(
    UniverseStock stock,
    ApiCredentials credentials,
  ) async {
    for (final symbol in _marketSymbolCandidates(stock.ticker)) {
      try {
        var series = await _twelveDataGateway.fetchTimeSeries(
          symbol: symbol,
          apiKey: credentials.twelveDataKey,
          interval: '1day',
          outputSize: 120,
        );
        if (series.isEmpty) {
          continue;
        }
        series = series.reversed.toList(growable: false);
        await _cacheBars(stock.ticker, series);
        return series;
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  Future<List<TimeSeriesEntryDto>> _fetchFreeBars(String ticker) async {
    try {
      final series = await _naverFreeMarketGateway.fetchDailyBars(
        ticker,
        days: 120,
      );
      if (series.isEmpty) {
        return const [];
      }
      await _cacheBars(ticker, series);
      return series;
    } catch (_) {
      return const [];
    }
  }

  Future<_CachedSeries?> _loadBarsFromCache(
    String ticker, {
    required bool allowStale,
  }) async {
    final cached = await _database.getBarsCache(
      symbol: ticker,
      interval: '1day',
    );
    if (cached == null) {
      return null;
    }

    final bars = _decodeCachedBars(cached.payload);
    if (bars.isEmpty) {
      return null;
    }

    final fresh = _isFresh(cached.updatedAt, _barsCacheTtl);
    if (!fresh && !allowStale) {
      return null;
    }
    return _CachedSeries(series: bars, fresh: fresh);
  }

  Future<_QuoteResult?> _fetchPremiumQuote(
    UniverseStock stock,
    ApiCredentials credentials,
  ) async {
    for (final symbol in _marketSymbolCandidates(stock.ticker)) {
      try {
        final quote = await _finnhubGateway.fetchQuote(
          symbol: symbol,
          apiKey: credentials.finnhubKey,
        );
        return _QuoteResult(
          current: quote.current,
          percentChange: quote.percentChange,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<_NewsLoadResult> _loadNews({
    required UniverseStock stock,
    required ApiCredentials credentials,
    required bool strictRealData,
    required bool forceRefresh,
  }) async {
    final hasPremium = _hasValidMarketKeys(credentials);

    if (!strictRealData && !forceRefresh) {
      final cache = await _loadNewsFromCache(stock.ticker, allowStale: true);
      if (cache != null) {
        return _NewsLoadResult(
          news: cache.news,
          source: cache.fresh ? _NewsSource.cacheFresh : _NewsSource.cacheStale,
        );
      }
    }

    if (hasPremium) {
      final premiumNews = await _fetchPremiumNews(stock, credentials);
      if (premiumNews.isNotEmpty) {
        await _cacheNews(stock.ticker, premiumNews);
        return _NewsLoadResult(news: premiumNews, source: _NewsSource.premium);
      }
      if (strictRealData) {
        return const _NewsLoadResult(news: [], source: _NewsSource.none);
      }
    }

    if (!strictRealData) {
      final googleTitles = await _fetchGoogleNewsTitles(stock);
      if (googleTitles.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final rows = googleTitles
            .map(
              (title) =>
                  NewsDto(headline: title, summary: '', url: '', datetime: now),
            )
            .toList(growable: false);
        await _cacheNews(stock.ticker, rows);
        return _NewsLoadResult(news: rows, source: _NewsSource.google);
      }

      if (_isKrxTicker(stock.ticker)) {
        final naverNews = await _fetchNaverNews(stock.ticker);
        if (naverNews.isNotEmpty) {
          await _cacheNews(stock.ticker, naverNews);
          return _NewsLoadResult(news: naverNews, source: _NewsSource.naver);
        }
      }

      final cache = await _loadNewsFromCache(stock.ticker, allowStale: true);
      if (cache != null) {
        return _NewsLoadResult(
          news: cache.news,
          source: cache.fresh ? _NewsSource.cacheFresh : _NewsSource.cacheStale,
        );
      }
    }

    return const _NewsLoadResult(news: [], source: _NewsSource.none);
  }

  Future<List<NewsDto>> _fetchPremiumNews(
    UniverseStock stock,
    ApiCredentials credentials,
  ) async {
    final now = _clock.nowKst();
    final from = DateFormat(
      'yyyy-MM-dd',
    ).format(now.subtract(const Duration(days: 3)));
    final to = DateFormat('yyyy-MM-dd').format(now);

    for (final symbol in _marketSymbolCandidates(stock.ticker)) {
      try {
        final rows = await _finnhubGateway.fetchCompanyNews(
          symbol: symbol,
          apiKey: credentials.finnhubKey,
          from: from,
          to: to,
        );
        if (rows.isNotEmpty) {
          return rows.take(20).toList(growable: false);
        }
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  Future<List<String>> _fetchGoogleNewsTitles(UniverseStock stock) async {
    try {
      return await _googleNewsRssGateway.fetchNewsTitles(
        ticker: stock.ticker,
        companyName: stock.name,
        limit: 20,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<List<NewsDto>> _fetchNaverNews(String ticker) async {
    try {
      return await _naverFreeMarketGateway.fetchStockNews(
        ticker: ticker,
        limit: 20,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<_CachedNews?> _loadNewsFromCache(
    String ticker, {
    required bool allowStale,
  }) async {
    final cached = await _database.getNewsCache(symbol: ticker);
    if (cached == null) {
      return null;
    }

    final rows = _decodeCachedNews(cached.payload);
    if (rows.isEmpty) {
      return null;
    }

    final fresh = _isFresh(cached.updatedAt, _newsCacheTtl);
    if (!fresh && !allowStale) {
      return null;
    }
    return _CachedNews(news: rows, fresh: fresh);
  }

  Future<void> _cacheBars(
    String ticker,
    List<TimeSeriesEntryDto> series,
  ) async {
    await _database.putBarsCache(
      symbol: ticker,
      interval: '1day',
      payload: jsonEncode(
        series
            .map(
              (e) => {
                'datetime': e.datetime,
                'open': e.open,
                'high': e.high,
                'low': e.low,
                'close': e.close,
                'volume': e.volume,
              },
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _cacheNews(String ticker, List<NewsDto> newsList) async {
    await _database.putNewsCache(
      symbol: ticker,
      payload: jsonEncode(
        newsList
            .map(
              (item) => {
                'headline': item.headline,
                'summary': item.summary,
                'url': item.url,
                'datetime': item.datetime,
              },
            )
            .toList(growable: false),
      ),
    );
  }

  List<String> _buildUsedInformation({
    required _SnapshotBuildResult snapshotBuild,
    required bool strictRealData,
  }) {
    final items = <String>[
      '데이터 모드: ${_modeLabel(snapshotBuild.dataMode)}',
      '주가 소스: TwelveData ${snapshotBuild.premiumBarsSymbols}개 / 네이버 무료 ${snapshotBuild.freeBarsSymbols}개 / 캐시 ${snapshotBuild.cacheBarsSymbols}개',
      '뉴스 소스: Finnhub ${snapshotBuild.premiumNewsSymbols}개 / Google RSS ${snapshotBuild.googleNewsSymbols}개 / 네이버 뉴스 ${snapshotBuild.naverNewsSymbols}개 / 캐시 ${snapshotBuild.cacheNewsSymbols}개',
      '반영 종목 수: ${snapshotBuild.snapshots.length}개 (요청 ${snapshotBuild.requestedSymbols}개)',
      '제외 종목 수: ${snapshotBuild.skippedSymbols}개',
      '캐시 사용 여부: ${snapshotBuild.cacheBarsSymbols > 0 || snapshotBuild.cacheNewsSymbols > 0 ? '사용' : '미사용'}',
      if (snapshotBuild.staleCacheBarsSymbols > 0 ||
          snapshotBuild.staleCacheNewsSymbols > 0)
        '만료 캐시 사용: bars ${snapshotBuild.staleCacheBarsSymbols}개 / news ${snapshotBuild.staleCacheNewsSymbols}개',
      '뉴스 반영 건수: 총 ${snapshotBuild.newsItemsUsed}건',
      '전략 계산 팩터: 모멘텀 + 안정성 + 유동성 + 뉴스심리',
      '실데이터 강제 모드: ${strictRealData ? '활성' : '비활성'}',
    ];
    return items;
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'premium':
        return '프리미엄 데이터 모드';
      case 'mixed':
        return '혼합 데이터 모드';
      default:
        return '무료 데이터 모드';
    }
  }

  bool _hasValidMarketKeys(ApiCredentials credentials) {
    return !_isDemoKey(credentials.twelveDataKey) &&
        !_isDemoKey(credentials.finnhubKey) &&
        credentials.hasMarketKeys;
  }

  bool _isDemoKey(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'demo';
  }

  bool _isKrxTicker(String ticker) {
    return RegExp(r'^\d{6}$').hasMatch(ticker);
  }

  bool _isFresh(DateTime updatedAt, Duration ttl) {
    return _clock.nowKst().difference(updatedAt).abs() <= ttl;
  }

  List<String> _marketSymbolCandidates(String ticker) {
    return [ticker, '$ticker:KRX', '$ticker.KS'];
  }

  List<TimeSeriesEntryDto> _decodeCachedBars(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .map(TimeSeriesEntryDto.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<NewsDto> _decodeCachedNews(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .map(NewsDto.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  double _estimateNewsSentiment(List<NewsDto> newsList) {
    if (newsList.isEmpty) {
      return 0;
    }

    const positiveKeywords = [
      '호재',
      '상승',
      '수주',
      '신고가',
      '실적개선',
      '증가',
      '확대',
      '성장',
      '강세',
      '최대',
    ];
    const negativeKeywords = [
      '악재',
      '하락',
      '리콜',
      '소송',
      '감소',
      '적자',
      '급락',
      '경고',
      '불확실',
      '부진',
    ];

    var score = 0.0;
    final sample = newsList.take(20).toList(growable: false);
    for (final news in sample) {
      final text = '${news.headline} ${news.summary}'.toLowerCase();
      for (final token in positiveKeywords) {
        if (text.contains(token)) {
          score += 1;
        }
      }
      for (final token in negativeKeywords) {
        if (text.contains(token)) {
          score -= 1;
        }
      }
    }

    return (score / (sample.length * 2)).clamp(-1.0, 1.0).toDouble();
  }

  double _calcChangeRate(List<double> closes) {
    if (closes.length < 2) {
      return 0;
    }
    final prev = closes[closes.length - 2];
    if (prev == 0) {
      return 0;
    }
    return ((closes.last - prev) / prev) * 100;
  }

  Future<void> _persistBacktestRows({
    required String tradeDate,
    required List<StockCandidate> candidates,
  }) async {
    for (final candidate in candidates) {
      final spark = candidate.sparkline60;
      final retT1 = spark.length > 1
          ? ((spark.last - spark[spark.length - 2]) / spark[spark.length - 2]) *
                100
          : null;
      final retT3 = spark.length > 3
          ? ((spark.last - spark[spark.length - 4]) / spark[spark.length - 4]) *
                100
          : null;
      final retT5 = spark.length > 5
          ? ((spark.last - spark[spark.length - 6]) / spark[spark.length - 6]) *
                100
          : null;
      await _database.addBacktestRow(
        BacktestCacheTableCompanion.insert(
          tradeDate: tradeDate,
          ticker: candidate.code,
          companyName: candidate.name,
          entryPrice: candidate.price,
          retT1: Value(retT1),
          retT3: Value(retT3),
          retT5: Value(retT5),
          currentPrice: Value(candidate.price),
        ),
      );
    }
  }
}

enum _BarsSource { premium, free, cacheFresh, cacheStale }

enum _NewsSource { premium, google, naver, cacheFresh, cacheStale, none }

class _SnapshotBuildResult {
  const _SnapshotBuildResult({
    required this.snapshots,
    required this.requestedSymbols,
    required this.skippedSymbols,
    required this.dataMode,
    required this.dataWarnings,
    required this.premiumBarsSymbols,
    required this.freeBarsSymbols,
    required this.cacheBarsSymbols,
    required this.staleCacheBarsSymbols,
    required this.premiumQuoteSymbols,
    required this.premiumNewsSymbols,
    required this.googleNewsSymbols,
    required this.naverNewsSymbols,
    required this.cacheNewsSymbols,
    required this.staleCacheNewsSymbols,
    required this.newsItemsUsed,
  });

  final List<SymbolMarketSnapshot> snapshots;
  final int requestedSymbols;
  final int skippedSymbols;
  final String dataMode;
  final List<String> dataWarnings;
  final int premiumBarsSymbols;
  final int freeBarsSymbols;
  final int cacheBarsSymbols;
  final int staleCacheBarsSymbols;
  final int premiumQuoteSymbols;
  final int premiumNewsSymbols;
  final int googleNewsSymbols;
  final int naverNewsSymbols;
  final int cacheNewsSymbols;
  final int staleCacheNewsSymbols;
  final int newsItemsUsed;
}

class _LoadedSnapshot {
  const _LoadedSnapshot({
    required this.snapshot,
    required this.barsSource,
    required this.quoteFromPremium,
    required this.newsSource,
    required this.newsCount,
  });

  final SymbolMarketSnapshot snapshot;
  final _BarsSource barsSource;
  final bool quoteFromPremium;
  final _NewsSource newsSource;
  final int newsCount;
}

class _CachedSeries {
  const _CachedSeries({required this.series, required this.fresh});

  final List<TimeSeriesEntryDto> series;
  final bool fresh;
}

class _CachedNews {
  const _CachedNews({required this.news, required this.fresh});

  final List<NewsDto> news;
  final bool fresh;
}

class _NewsLoadResult {
  const _NewsLoadResult({required this.news, required this.source});

  final List<NewsDto> news;
  final _NewsSource source;
}

class _QuoteResult {
  const _QuoteResult({required this.current, required this.percentChange});

  final double current;
  final double percentChange;
}

class _DashboardFailureException implements Exception {
  const _DashboardFailureException(this.failure);

  final AppFailure failure;
}
