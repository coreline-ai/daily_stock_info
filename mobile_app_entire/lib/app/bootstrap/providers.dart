import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app_entire/application/usecases/generate_ai_report_usecase.dart';
import 'package:mobile_app_entire/application/usecases/get_backtest_history_usecase.dart';
import 'package:mobile_app_entire/application/usecases/get_backtest_summary_usecase.dart';
import 'package:mobile_app_entire/application/usecases/get_watchlist_usecase.dart';
import 'package:mobile_app_entire/application/usecases/load_dashboard_usecase.dart';
import 'package:mobile_app_entire/application/usecases/run_validation_usecase.dart';
import 'package:mobile_app_entire/core/logger/app_logger.dart';
import 'package:mobile_app_entire/core/network/dio_client_factory.dart';
import 'package:mobile_app_entire/core/time/kst_clock.dart';
import 'package:mobile_app_entire/data/gateways/finnhub_gateway.dart';
import 'package:mobile_app_entire/data/gateways/glm_gateway.dart';
import 'package:mobile_app_entire/data/gateways/google_news_rss_gateway.dart';
import 'package:mobile_app_entire/data/gateways/naver_free_market_gateway.dart';
import 'package:mobile_app_entire/data/gateways/twelve_data_gateway.dart';
import 'package:mobile_app_entire/data/local/app_database.dart';
import 'package:mobile_app_entire/data/repositories/ai_report_repository_impl.dart';
import 'package:mobile_app_entire/data/repositories/backtest_repository_impl.dart';
import 'package:mobile_app_entire/data/repositories/credential_repository_impl.dart';
import 'package:mobile_app_entire/data/repositories/dashboard_repository_impl.dart';
import 'package:mobile_app_entire/data/repositories/validation_repository_impl.dart';
import 'package:mobile_app_entire/data/repositories/watchlist_repository_impl.dart';
import 'package:mobile_app_entire/data/secure/credential_store.dart';
import 'package:mobile_app_entire/domain/repositories/ai_report_repository.dart';
import 'package:mobile_app_entire/domain/repositories/backtest_repository.dart';
import 'package:mobile_app_entire/domain/repositories/credential_repository.dart';
import 'package:mobile_app_entire/domain/repositories/dashboard_repository.dart';
import 'package:mobile_app_entire/domain/repositories/validation_repository.dart';
import 'package:mobile_app_entire/domain/repositories/watchlist_repository.dart';
import 'package:mobile_app_entire/domain/services/backtest_math_service.dart';
import 'package:mobile_app_entire/domain/services/scoring_service.dart';
import 'package:mobile_app_entire/domain/services/strategy_window_service.dart';
import 'package:mobile_app_entire/domain/services/validation_math_service.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

final appLoggerProvider = Provider<AppLogger>((ref) => AppLogger());
final kstClockProvider = Provider<KstClock>((ref) => KstClock());
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final dioFactoryProvider = Provider<DioClientFactory>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return DioClientFactory(logger);
});

final twelveDataDioProvider = Provider<Dio>((ref) {
  final factory = ref.watch(dioFactoryProvider);
  return factory.create(baseUrl: 'https://api.twelvedata.com');
});

final finnhubDioProvider = Provider<Dio>((ref) {
  final factory = ref.watch(dioFactoryProvider);
  return factory.create(baseUrl: 'https://finnhub.io/api/v1');
});

final naverStockDioProvider = Provider<Dio>((ref) {
  final factory = ref.watch(dioFactoryProvider);
  return factory.create(baseUrl: 'https://api.stock.naver.com');
});

final naverFinanceDioProvider = Provider<Dio>((ref) {
  final factory = ref.watch(dioFactoryProvider);
  return factory.create(baseUrl: 'https://finance.naver.com');
});

final googleNewsDioProvider = Provider<Dio>((ref) {
  final factory = ref.watch(dioFactoryProvider);
  return factory.create(baseUrl: 'https://news.google.com');
});

final glmDioProvider = Provider<Dio>((ref) {
  final factory = ref.watch(dioFactoryProvider);
  return factory.create(baseUrl: 'https://open.bigmodel.cn/api/paas/v4');
});

final twelveDataGatewayProvider = Provider<TwelveDataGateway>((ref) {
  final dio = ref.watch(twelveDataDioProvider);
  return TwelveDataGateway(dio: dio);
});

final finnhubGatewayProvider = Provider<FinnhubGateway>((ref) {
  final dio = ref.watch(finnhubDioProvider);
  return FinnhubGateway(dio: dio);
});

final naverFreeMarketGatewayProvider = Provider<NaverFreeMarketGateway>((ref) {
  return NaverFreeMarketGateway(
    apiDio: ref.watch(naverStockDioProvider),
    financeDio: ref.watch(naverFinanceDioProvider),
  );
});

final googleNewsRssGatewayProvider = Provider<GoogleNewsRssGateway>((ref) {
  return GoogleNewsRssGateway(dio: ref.watch(googleNewsDioProvider));
});

final glmGatewayProvider = Provider<GlmGateway>((ref) {
  final dio = ref.watch(glmDioProvider);
  return GlmGateway(dio: dio);
});

final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => CredentialStore(),
);

final credentialRepositoryProvider = Provider<CredentialRepository>((ref) {
  final store = ref.watch(credentialStoreProvider);
  return CredentialRepositoryImpl(store);
});

final apiKeysReadyProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(credentialRepositoryProvider);
  final result = await repository.load();
  return result.when(
    success: (credentials) {
      bool valid(String value) {
        final normalized = value.trim().toLowerCase();
        return normalized.isNotEmpty && normalized != 'demo';
      }

      return valid(credentials.twelveDataKey) && valid(credentials.finnhubKey);
    },
    failure: (_) => false,
  );
});

final strategyWindowServiceProvider = Provider<StrategyWindowService>(
  (ref) => const StrategyWindowService(),
);
final scoringServiceProvider = Provider<ScoringService>(
  (ref) => const ScoringService(),
);
final validationMathServiceProvider = Provider<ValidationMathService>(
  (ref) => const ValidationMathService(),
);
final backtestMathServiceProvider = Provider<BacktestMathService>(
  (ref) => const BacktestMathService(),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    twelveDataGateway: ref.watch(twelveDataGatewayProvider),
    finnhubGateway: ref.watch(finnhubGatewayProvider),
    naverFreeMarketGateway: ref.watch(naverFreeMarketGatewayProvider),
    googleNewsRssGateway: ref.watch(googleNewsRssGatewayProvider),
    credentialRepository: ref.watch(credentialRepositoryProvider),
    strategyWindowService: ref.watch(strategyWindowServiceProvider),
    scoringService: ref.watch(scoringServiceProvider),
    database: ref.watch(appDatabaseProvider),
    clock: ref.watch(kstClockProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final validationRepositoryProvider = Provider<ValidationRepository>((ref) {
  return ValidationRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    validationMathService: ref.watch(validationMathServiceProvider),
  );
});

final backtestRepositoryProvider = Provider<BacktestRepository>((ref) {
  return BacktestRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    backtestMathService: ref.watch(backtestMathServiceProvider),
  );
});

final aiReportRepositoryProvider = Provider<AiReportRepository>((ref) {
  return AiReportRepositoryImpl(
    gateway: ref.watch(glmGatewayProvider),
    credentialRepository: ref.watch(credentialRepositoryProvider),
    database: ref.watch(appDatabaseProvider),
  );
});

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  return WatchlistRepositoryImpl(ref.watch(appDatabaseProvider));
});

final loadDashboardUsecaseProvider = Provider<LoadDashboardUsecase>((ref) {
  return LoadDashboardUsecase(ref.watch(dashboardRepositoryProvider));
});

final runValidationUsecaseProvider = Provider<RunValidationUsecase>((ref) {
  return RunValidationUsecase(ref.watch(validationRepositoryProvider));
});

final getBacktestSummaryUsecaseProvider = Provider<GetBacktestSummaryUsecase>((
  ref,
) {
  return GetBacktestSummaryUsecase(ref.watch(backtestRepositoryProvider));
});

final getBacktestHistoryUsecaseProvider = Provider<GetBacktestHistoryUsecase>((
  ref,
) {
  return GetBacktestHistoryUsecase(ref.watch(backtestRepositoryProvider));
});

final generateAiReportUsecaseProvider = Provider<GenerateAiReportUsecase>((
  ref,
) {
  return GenerateAiReportUsecase(ref.watch(aiReportRepositoryProvider));
});

final getWatchlistUsecaseProvider = Provider<GetWatchlistUsecase>((ref) {
  return GetWatchlistUsecase(ref.watch(watchlistRepositoryProvider));
});
