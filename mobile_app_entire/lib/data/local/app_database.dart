import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('WatchlistRow')
class WatchlistTable extends Table {
  TextColumn get ticker => text()();
  TextColumn get alias => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {ticker};
}

@DataClassName('CacheBarRow')
class CacheBarsTable extends Table {
  TextColumn get symbol => text()();
  TextColumn get interval => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {symbol, interval};
}

@DataClassName('CacheNewsRow')
class CacheNewsTable extends Table {
  TextColumn get symbol => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {symbol};
}

@DataClassName('CacheAiRow')
class CacheAiTable extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};
}

@DataClassName('ValidationCacheRow')
class ValidationCacheTable extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};
}

@DataClassName('BacktestCacheRow')
class BacktestCacheTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tradeDate => text()();
  TextColumn get ticker => text()();
  TextColumn get companyName => text()();
  RealColumn get entryPrice => real()();
  RealColumn get retT1 => real().nullable()();
  RealColumn get retT3 => real().nullable()();
  RealColumn get retT5 => real().nullable()();
  RealColumn get currentPrice => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('SettingRow')
class AppSettingsTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    WatchlistTable,
    CacheBarsTable,
    CacheNewsTable,
    CacheAiTable,
    ValidationCacheTable,
    BacktestCacheTable,
    AppSettingsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'mobile_app_entire'));

  @override
  int get schemaVersion => 1;

  Future<List<WatchlistRow>> getWatchlist() {
    final query = select(watchlistTable)
      ..orderBy([(t) => OrderingTerm.asc(t.ticker)]);
    return query.get();
  }

  Future<void> upsertTicker(String ticker, {String? alias}) async {
    await into(watchlistTable).insertOnConflictUpdate(
      WatchlistTableCompanion(ticker: Value(ticker), alias: Value(alias)),
    );
  }

  Future<void> deleteTicker(String ticker) {
    return (delete(watchlistTable)..where((t) => t.ticker.equals(ticker))).go();
  }

  Future<void> replaceWatchlist(List<String> tickers) async {
    await transaction(() async {
      await delete(watchlistTable).go();
      for (final ticker in tickers) {
        await upsertTicker(ticker);
      }
    });
  }

  Future<void> putBarsCache({
    required String symbol,
    required String interval,
    required String payload,
  }) {
    return into(cacheBarsTable).insertOnConflictUpdate(
      CacheBarsTableCompanion(
        symbol: Value(symbol),
        interval: Value(interval),
        payload: Value(payload),
      ),
    );
  }

  Future<CacheBarRow?> getBarsCache({
    required String symbol,
    required String interval,
  }) {
    return (select(cacheBarsTable)
          ..where((t) => t.symbol.equals(symbol) & t.interval.equals(interval)))
        .getSingleOrNull();
  }

  Future<void> putNewsCache({required String symbol, required String payload}) {
    return into(cacheNewsTable).insertOnConflictUpdate(
      CacheNewsTableCompanion(symbol: Value(symbol), payload: Value(payload)),
    );
  }

  Future<CacheNewsRow?> getNewsCache({required String symbol}) {
    return (select(
      cacheNewsTable,
    )..where((t) => t.symbol.equals(symbol))).getSingleOrNull();
  }

  Future<void> putAiCache({required String cacheKey, required String payload}) {
    return into(cacheAiTable).insertOnConflictUpdate(
      CacheAiTableCompanion(cacheKey: Value(cacheKey), payload: Value(payload)),
    );
  }

  Future<CacheAiRow?> getAiCache({required String cacheKey}) {
    return (select(
      cacheAiTable,
    )..where((t) => t.cacheKey.equals(cacheKey))).getSingleOrNull();
  }

  Future<void> putValidationCache({
    required String cacheKey,
    required String payload,
  }) {
    return into(validationCacheTable).insertOnConflictUpdate(
      ValidationCacheTableCompanion(
        cacheKey: Value(cacheKey),
        payload: Value(payload),
      ),
    );
  }

  Future<ValidationCacheRow?> getValidationCache({required String cacheKey}) {
    return (select(
      validationCacheTable,
    )..where((t) => t.cacheKey.equals(cacheKey))).getSingleOrNull();
  }

  Future<void> addBacktestRow(BacktestCacheTableCompanion row) {
    return into(backtestCacheTable).insert(row);
  }

  Future<List<BacktestCacheRow>> listBacktestRows({
    required int page,
    required int size,
    String? startDate,
    String? endDate,
  }) {
    final query = select(backtestCacheTable)
      ..orderBy([
        (t) => OrderingTerm.desc(t.tradeDate),
        (t) => OrderingTerm.asc(t.ticker),
      ])
      ..limit(size, offset: (page - 1) * size);

    if (startDate != null && startDate.isNotEmpty) {
      query.where((t) => t.tradeDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null && endDate.isNotEmpty) {
      query.where((t) => t.tradeDate.isSmallerOrEqualValue(endDate));
    }
    return query.get();
  }

  Future<int> countBacktestRows({String? startDate, String? endDate}) async {
    final countExp = backtestCacheTable.id.count();
    final query = selectOnly(backtestCacheTable)..addColumns([countExp]);
    if (startDate != null && startDate.isNotEmpty) {
      query.where(backtestCacheTable.tradeDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null && endDate.isNotEmpty) {
      query.where(backtestCacheTable.tradeDate.isSmallerOrEqualValue(endDate));
    }
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<List<BacktestCacheRow>> listAllBacktestRows({
    String? startDate,
    String? endDate,
  }) {
    final query = select(backtestCacheTable)
      ..orderBy([
        (t) => OrderingTerm.desc(t.tradeDate),
        (t) => OrderingTerm.asc(t.ticker),
      ]);
    if (startDate != null && startDate.isNotEmpty) {
      query.where((t) => t.tradeDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null && endDate.isNotEmpty) {
      query.where((t) => t.tradeDate.isSmallerOrEqualValue(endDate));
    }
    return query.get();
  }

  Future<void> putSetting(String key, String value) {
    return into(appSettingsTable).insertOnConflictUpdate(
      AppSettingsTableCompanion(key: Value(key), value: Value(value)),
    );
  }

  Future<String?> getSetting(String key) async {
    final row = await (select(
      appSettingsTable,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }
}
