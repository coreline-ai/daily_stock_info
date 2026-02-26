// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WatchlistTableTable extends WatchlistTable
    with TableInfo<$WatchlistTableTable, WatchlistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchlistTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tickerMeta = const VerificationMeta('ticker');
  @override
  late final GeneratedColumn<String> ticker = GeneratedColumn<String>(
    'ticker',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [ticker, alias, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watchlist_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchlistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ticker')) {
      context.handle(
        _tickerMeta,
        ticker.isAcceptableOrUnknown(data['ticker']!, _tickerMeta),
      );
    } else if (isInserting) {
      context.missing(_tickerMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ticker};
  @override
  WatchlistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchlistRow(
      ticker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ticker'],
      )!,
      alias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WatchlistTableTable createAlias(String alias) {
    return $WatchlistTableTable(attachedDatabase, alias);
  }
}

class WatchlistRow extends DataClass implements Insertable<WatchlistRow> {
  final String ticker;
  final String? alias;
  final DateTime createdAt;
  const WatchlistRow({
    required this.ticker,
    this.alias,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ticker'] = Variable<String>(ticker);
    if (!nullToAbsent || alias != null) {
      map['alias'] = Variable<String>(alias);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WatchlistTableCompanion toCompanion(bool nullToAbsent) {
    return WatchlistTableCompanion(
      ticker: Value(ticker),
      alias: alias == null && nullToAbsent
          ? const Value.absent()
          : Value(alias),
      createdAt: Value(createdAt),
    );
  }

  factory WatchlistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchlistRow(
      ticker: serializer.fromJson<String>(json['ticker']),
      alias: serializer.fromJson<String?>(json['alias']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ticker': serializer.toJson<String>(ticker),
      'alias': serializer.toJson<String?>(alias),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WatchlistRow copyWith({
    String? ticker,
    Value<String?> alias = const Value.absent(),
    DateTime? createdAt,
  }) => WatchlistRow(
    ticker: ticker ?? this.ticker,
    alias: alias.present ? alias.value : this.alias,
    createdAt: createdAt ?? this.createdAt,
  );
  WatchlistRow copyWithCompanion(WatchlistTableCompanion data) {
    return WatchlistRow(
      ticker: data.ticker.present ? data.ticker.value : this.ticker,
      alias: data.alias.present ? data.alias.value : this.alias,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistRow(')
          ..write('ticker: $ticker, ')
          ..write('alias: $alias, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ticker, alias, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchlistRow &&
          other.ticker == this.ticker &&
          other.alias == this.alias &&
          other.createdAt == this.createdAt);
}

class WatchlistTableCompanion extends UpdateCompanion<WatchlistRow> {
  final Value<String> ticker;
  final Value<String?> alias;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WatchlistTableCompanion({
    this.ticker = const Value.absent(),
    this.alias = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchlistTableCompanion.insert({
    required String ticker,
    this.alias = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ticker = Value(ticker);
  static Insertable<WatchlistRow> custom({
    Expression<String>? ticker,
    Expression<String>? alias,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ticker != null) 'ticker': ticker,
      if (alias != null) 'alias': alias,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchlistTableCompanion copyWith({
    Value<String>? ticker,
    Value<String?>? alias,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WatchlistTableCompanion(
      ticker: ticker ?? this.ticker,
      alias: alias ?? this.alias,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ticker.present) {
      map['ticker'] = Variable<String>(ticker.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistTableCompanion(')
          ..write('ticker: $ticker, ')
          ..write('alias: $alias, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheBarsTableTable extends CacheBarsTable
    with TableInfo<$CacheBarsTableTable, CacheBarRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheBarsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intervalMeta = const VerificationMeta(
    'interval',
  );
  @override
  late final GeneratedColumn<String> interval = GeneratedColumn<String>(
    'interval',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [symbol, interval, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_bars_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheBarRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('interval')) {
      context.handle(
        _intervalMeta,
        interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta),
      );
    } else if (isInserting) {
      context.missing(_intervalMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, interval};
  @override
  CacheBarRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheBarRow(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      interval: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}interval'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CacheBarsTableTable createAlias(String alias) {
    return $CacheBarsTableTable(attachedDatabase, alias);
  }
}

class CacheBarRow extends DataClass implements Insertable<CacheBarRow> {
  final String symbol;
  final String interval;
  final String payload;
  final DateTime updatedAt;
  const CacheBarRow({
    required this.symbol,
    required this.interval,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['interval'] = Variable<String>(interval);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CacheBarsTableCompanion toCompanion(bool nullToAbsent) {
    return CacheBarsTableCompanion(
      symbol: Value(symbol),
      interval: Value(interval),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory CacheBarRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheBarRow(
      symbol: serializer.fromJson<String>(json['symbol']),
      interval: serializer.fromJson<String>(json['interval']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'interval': serializer.toJson<String>(interval),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CacheBarRow copyWith({
    String? symbol,
    String? interval,
    String? payload,
    DateTime? updatedAt,
  }) => CacheBarRow(
    symbol: symbol ?? this.symbol,
    interval: interval ?? this.interval,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CacheBarRow copyWithCompanion(CacheBarsTableCompanion data) {
    return CacheBarRow(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      interval: data.interval.present ? data.interval.value : this.interval,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheBarRow(')
          ..write('symbol: $symbol, ')
          ..write('interval: $interval, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(symbol, interval, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheBarRow &&
          other.symbol == this.symbol &&
          other.interval == this.interval &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class CacheBarsTableCompanion extends UpdateCompanion<CacheBarRow> {
  final Value<String> symbol;
  final Value<String> interval;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CacheBarsTableCompanion({
    this.symbol = const Value.absent(),
    this.interval = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheBarsTableCompanion.insert({
    required String symbol,
    required String interval,
    required String payload,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       interval = Value(interval),
       payload = Value(payload);
  static Insertable<CacheBarRow> custom({
    Expression<String>? symbol,
    Expression<String>? interval,
    Expression<String>? payload,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (interval != null) 'interval': interval,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheBarsTableCompanion copyWith({
    Value<String>? symbol,
    Value<String>? interval,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CacheBarsTableCompanion(
      symbol: symbol ?? this.symbol,
      interval: interval ?? this.interval,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (interval.present) {
      map['interval'] = Variable<String>(interval.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheBarsTableCompanion(')
          ..write('symbol: $symbol, ')
          ..write('interval: $interval, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheNewsTableTable extends CacheNewsTable
    with TableInfo<$CacheNewsTableTable, CacheNewsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheNewsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [symbol, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_news_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheNewsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol};
  @override
  CacheNewsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheNewsRow(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CacheNewsTableTable createAlias(String alias) {
    return $CacheNewsTableTable(attachedDatabase, alias);
  }
}

class CacheNewsRow extends DataClass implements Insertable<CacheNewsRow> {
  final String symbol;
  final String payload;
  final DateTime updatedAt;
  const CacheNewsRow({
    required this.symbol,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CacheNewsTableCompanion toCompanion(bool nullToAbsent) {
    return CacheNewsTableCompanion(
      symbol: Value(symbol),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory CacheNewsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheNewsRow(
      symbol: serializer.fromJson<String>(json['symbol']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CacheNewsRow copyWith({
    String? symbol,
    String? payload,
    DateTime? updatedAt,
  }) => CacheNewsRow(
    symbol: symbol ?? this.symbol,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CacheNewsRow copyWithCompanion(CacheNewsTableCompanion data) {
    return CacheNewsRow(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheNewsRow(')
          ..write('symbol: $symbol, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(symbol, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheNewsRow &&
          other.symbol == this.symbol &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class CacheNewsTableCompanion extends UpdateCompanion<CacheNewsRow> {
  final Value<String> symbol;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CacheNewsTableCompanion({
    this.symbol = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheNewsTableCompanion.insert({
    required String symbol,
    required String payload,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       payload = Value(payload);
  static Insertable<CacheNewsRow> custom({
    Expression<String>? symbol,
    Expression<String>? payload,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheNewsTableCompanion copyWith({
    Value<String>? symbol,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CacheNewsTableCompanion(
      symbol: symbol ?? this.symbol,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheNewsTableCompanion(')
          ..write('symbol: $symbol, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheAiTableTable extends CacheAiTable
    with TableInfo<$CacheAiTableTable, CacheAiRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheAiTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [cacheKey, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_ai_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheAiRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  CacheAiRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheAiRow(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CacheAiTableTable createAlias(String alias) {
    return $CacheAiTableTable(attachedDatabase, alias);
  }
}

class CacheAiRow extends DataClass implements Insertable<CacheAiRow> {
  final String cacheKey;
  final String payload;
  final DateTime updatedAt;
  const CacheAiRow({
    required this.cacheKey,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CacheAiTableCompanion toCompanion(bool nullToAbsent) {
    return CacheAiTableCompanion(
      cacheKey: Value(cacheKey),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory CacheAiRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheAiRow(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CacheAiRow copyWith({
    String? cacheKey,
    String? payload,
    DateTime? updatedAt,
  }) => CacheAiRow(
    cacheKey: cacheKey ?? this.cacheKey,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CacheAiRow copyWithCompanion(CacheAiTableCompanion data) {
    return CacheAiRow(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheAiRow(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheAiRow &&
          other.cacheKey == this.cacheKey &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class CacheAiTableCompanion extends UpdateCompanion<CacheAiRow> {
  final Value<String> cacheKey;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CacheAiTableCompanion({
    this.cacheKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheAiTableCompanion.insert({
    required String cacheKey,
    required String payload,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       payload = Value(payload);
  static Insertable<CacheAiRow> custom({
    Expression<String>? cacheKey,
    Expression<String>? payload,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheAiTableCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CacheAiTableCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheAiTableCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ValidationCacheTableTable extends ValidationCacheTable
    with TableInfo<$ValidationCacheTableTable, ValidationCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ValidationCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [cacheKey, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'validation_cache_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ValidationCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  ValidationCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ValidationCacheRow(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ValidationCacheTableTable createAlias(String alias) {
    return $ValidationCacheTableTable(attachedDatabase, alias);
  }
}

class ValidationCacheRow extends DataClass
    implements Insertable<ValidationCacheRow> {
  final String cacheKey;
  final String payload;
  final DateTime updatedAt;
  const ValidationCacheRow({
    required this.cacheKey,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ValidationCacheTableCompanion toCompanion(bool nullToAbsent) {
    return ValidationCacheTableCompanion(
      cacheKey: Value(cacheKey),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory ValidationCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ValidationCacheRow(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ValidationCacheRow copyWith({
    String? cacheKey,
    String? payload,
    DateTime? updatedAt,
  }) => ValidationCacheRow(
    cacheKey: cacheKey ?? this.cacheKey,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ValidationCacheRow copyWithCompanion(ValidationCacheTableCompanion data) {
    return ValidationCacheRow(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ValidationCacheRow(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ValidationCacheRow &&
          other.cacheKey == this.cacheKey &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class ValidationCacheTableCompanion
    extends UpdateCompanion<ValidationCacheRow> {
  final Value<String> cacheKey;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ValidationCacheTableCompanion({
    this.cacheKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ValidationCacheTableCompanion.insert({
    required String cacheKey,
    required String payload,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       payload = Value(payload);
  static Insertable<ValidationCacheRow> custom({
    Expression<String>? cacheKey,
    Expression<String>? payload,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ValidationCacheTableCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ValidationCacheTableCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ValidationCacheTableCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BacktestCacheTableTable extends BacktestCacheTable
    with TableInfo<$BacktestCacheTableTable, BacktestCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BacktestCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tradeDateMeta = const VerificationMeta(
    'tradeDate',
  );
  @override
  late final GeneratedColumn<String> tradeDate = GeneratedColumn<String>(
    'trade_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tickerMeta = const VerificationMeta('ticker');
  @override
  late final GeneratedColumn<String> ticker = GeneratedColumn<String>(
    'ticker',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyNameMeta = const VerificationMeta(
    'companyName',
  );
  @override
  late final GeneratedColumn<String> companyName = GeneratedColumn<String>(
    'company_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryPriceMeta = const VerificationMeta(
    'entryPrice',
  );
  @override
  late final GeneratedColumn<double> entryPrice = GeneratedColumn<double>(
    'entry_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retT1Meta = const VerificationMeta('retT1');
  @override
  late final GeneratedColumn<double> retT1 = GeneratedColumn<double>(
    'ret_t1',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retT3Meta = const VerificationMeta('retT3');
  @override
  late final GeneratedColumn<double> retT3 = GeneratedColumn<double>(
    'ret_t3',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retT5Meta = const VerificationMeta('retT5');
  @override
  late final GeneratedColumn<double> retT5 = GeneratedColumn<double>(
    'ret_t5',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentPriceMeta = const VerificationMeta(
    'currentPrice',
  );
  @override
  late final GeneratedColumn<double> currentPrice = GeneratedColumn<double>(
    'current_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tradeDate,
    ticker,
    companyName,
    entryPrice,
    retT1,
    retT3,
    retT5,
    currentPrice,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backtest_cache_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<BacktestCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trade_date')) {
      context.handle(
        _tradeDateMeta,
        tradeDate.isAcceptableOrUnknown(data['trade_date']!, _tradeDateMeta),
      );
    } else if (isInserting) {
      context.missing(_tradeDateMeta);
    }
    if (data.containsKey('ticker')) {
      context.handle(
        _tickerMeta,
        ticker.isAcceptableOrUnknown(data['ticker']!, _tickerMeta),
      );
    } else if (isInserting) {
      context.missing(_tickerMeta);
    }
    if (data.containsKey('company_name')) {
      context.handle(
        _companyNameMeta,
        companyName.isAcceptableOrUnknown(
          data['company_name']!,
          _companyNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_companyNameMeta);
    }
    if (data.containsKey('entry_price')) {
      context.handle(
        _entryPriceMeta,
        entryPrice.isAcceptableOrUnknown(data['entry_price']!, _entryPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_entryPriceMeta);
    }
    if (data.containsKey('ret_t1')) {
      context.handle(
        _retT1Meta,
        retT1.isAcceptableOrUnknown(data['ret_t1']!, _retT1Meta),
      );
    }
    if (data.containsKey('ret_t3')) {
      context.handle(
        _retT3Meta,
        retT3.isAcceptableOrUnknown(data['ret_t3']!, _retT3Meta),
      );
    }
    if (data.containsKey('ret_t5')) {
      context.handle(
        _retT5Meta,
        retT5.isAcceptableOrUnknown(data['ret_t5']!, _retT5Meta),
      );
    }
    if (data.containsKey('current_price')) {
      context.handle(
        _currentPriceMeta,
        currentPrice.isAcceptableOrUnknown(
          data['current_price']!,
          _currentPriceMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BacktestCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BacktestCacheRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tradeDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trade_date'],
      )!,
      ticker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ticker'],
      )!,
      companyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_name'],
      )!,
      entryPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}entry_price'],
      )!,
      retT1: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ret_t1'],
      ),
      retT3: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ret_t3'],
      ),
      retT5: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ret_t5'],
      ),
      currentPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_price'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BacktestCacheTableTable createAlias(String alias) {
    return $BacktestCacheTableTable(attachedDatabase, alias);
  }
}

class BacktestCacheRow extends DataClass
    implements Insertable<BacktestCacheRow> {
  final int id;
  final String tradeDate;
  final String ticker;
  final String companyName;
  final double entryPrice;
  final double? retT1;
  final double? retT3;
  final double? retT5;
  final double? currentPrice;
  final DateTime createdAt;
  const BacktestCacheRow({
    required this.id,
    required this.tradeDate,
    required this.ticker,
    required this.companyName,
    required this.entryPrice,
    this.retT1,
    this.retT3,
    this.retT5,
    this.currentPrice,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trade_date'] = Variable<String>(tradeDate);
    map['ticker'] = Variable<String>(ticker);
    map['company_name'] = Variable<String>(companyName);
    map['entry_price'] = Variable<double>(entryPrice);
    if (!nullToAbsent || retT1 != null) {
      map['ret_t1'] = Variable<double>(retT1);
    }
    if (!nullToAbsent || retT3 != null) {
      map['ret_t3'] = Variable<double>(retT3);
    }
    if (!nullToAbsent || retT5 != null) {
      map['ret_t5'] = Variable<double>(retT5);
    }
    if (!nullToAbsent || currentPrice != null) {
      map['current_price'] = Variable<double>(currentPrice);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BacktestCacheTableCompanion toCompanion(bool nullToAbsent) {
    return BacktestCacheTableCompanion(
      id: Value(id),
      tradeDate: Value(tradeDate),
      ticker: Value(ticker),
      companyName: Value(companyName),
      entryPrice: Value(entryPrice),
      retT1: retT1 == null && nullToAbsent
          ? const Value.absent()
          : Value(retT1),
      retT3: retT3 == null && nullToAbsent
          ? const Value.absent()
          : Value(retT3),
      retT5: retT5 == null && nullToAbsent
          ? const Value.absent()
          : Value(retT5),
      currentPrice: currentPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(currentPrice),
      createdAt: Value(createdAt),
    );
  }

  factory BacktestCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BacktestCacheRow(
      id: serializer.fromJson<int>(json['id']),
      tradeDate: serializer.fromJson<String>(json['tradeDate']),
      ticker: serializer.fromJson<String>(json['ticker']),
      companyName: serializer.fromJson<String>(json['companyName']),
      entryPrice: serializer.fromJson<double>(json['entryPrice']),
      retT1: serializer.fromJson<double?>(json['retT1']),
      retT3: serializer.fromJson<double?>(json['retT3']),
      retT5: serializer.fromJson<double?>(json['retT5']),
      currentPrice: serializer.fromJson<double?>(json['currentPrice']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tradeDate': serializer.toJson<String>(tradeDate),
      'ticker': serializer.toJson<String>(ticker),
      'companyName': serializer.toJson<String>(companyName),
      'entryPrice': serializer.toJson<double>(entryPrice),
      'retT1': serializer.toJson<double?>(retT1),
      'retT3': serializer.toJson<double?>(retT3),
      'retT5': serializer.toJson<double?>(retT5),
      'currentPrice': serializer.toJson<double?>(currentPrice),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BacktestCacheRow copyWith({
    int? id,
    String? tradeDate,
    String? ticker,
    String? companyName,
    double? entryPrice,
    Value<double?> retT1 = const Value.absent(),
    Value<double?> retT3 = const Value.absent(),
    Value<double?> retT5 = const Value.absent(),
    Value<double?> currentPrice = const Value.absent(),
    DateTime? createdAt,
  }) => BacktestCacheRow(
    id: id ?? this.id,
    tradeDate: tradeDate ?? this.tradeDate,
    ticker: ticker ?? this.ticker,
    companyName: companyName ?? this.companyName,
    entryPrice: entryPrice ?? this.entryPrice,
    retT1: retT1.present ? retT1.value : this.retT1,
    retT3: retT3.present ? retT3.value : this.retT3,
    retT5: retT5.present ? retT5.value : this.retT5,
    currentPrice: currentPrice.present ? currentPrice.value : this.currentPrice,
    createdAt: createdAt ?? this.createdAt,
  );
  BacktestCacheRow copyWithCompanion(BacktestCacheTableCompanion data) {
    return BacktestCacheRow(
      id: data.id.present ? data.id.value : this.id,
      tradeDate: data.tradeDate.present ? data.tradeDate.value : this.tradeDate,
      ticker: data.ticker.present ? data.ticker.value : this.ticker,
      companyName: data.companyName.present
          ? data.companyName.value
          : this.companyName,
      entryPrice: data.entryPrice.present
          ? data.entryPrice.value
          : this.entryPrice,
      retT1: data.retT1.present ? data.retT1.value : this.retT1,
      retT3: data.retT3.present ? data.retT3.value : this.retT3,
      retT5: data.retT5.present ? data.retT5.value : this.retT5,
      currentPrice: data.currentPrice.present
          ? data.currentPrice.value
          : this.currentPrice,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BacktestCacheRow(')
          ..write('id: $id, ')
          ..write('tradeDate: $tradeDate, ')
          ..write('ticker: $ticker, ')
          ..write('companyName: $companyName, ')
          ..write('entryPrice: $entryPrice, ')
          ..write('retT1: $retT1, ')
          ..write('retT3: $retT3, ')
          ..write('retT5: $retT5, ')
          ..write('currentPrice: $currentPrice, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tradeDate,
    ticker,
    companyName,
    entryPrice,
    retT1,
    retT3,
    retT5,
    currentPrice,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BacktestCacheRow &&
          other.id == this.id &&
          other.tradeDate == this.tradeDate &&
          other.ticker == this.ticker &&
          other.companyName == this.companyName &&
          other.entryPrice == this.entryPrice &&
          other.retT1 == this.retT1 &&
          other.retT3 == this.retT3 &&
          other.retT5 == this.retT5 &&
          other.currentPrice == this.currentPrice &&
          other.createdAt == this.createdAt);
}

class BacktestCacheTableCompanion extends UpdateCompanion<BacktestCacheRow> {
  final Value<int> id;
  final Value<String> tradeDate;
  final Value<String> ticker;
  final Value<String> companyName;
  final Value<double> entryPrice;
  final Value<double?> retT1;
  final Value<double?> retT3;
  final Value<double?> retT5;
  final Value<double?> currentPrice;
  final Value<DateTime> createdAt;
  const BacktestCacheTableCompanion({
    this.id = const Value.absent(),
    this.tradeDate = const Value.absent(),
    this.ticker = const Value.absent(),
    this.companyName = const Value.absent(),
    this.entryPrice = const Value.absent(),
    this.retT1 = const Value.absent(),
    this.retT3 = const Value.absent(),
    this.retT5 = const Value.absent(),
    this.currentPrice = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BacktestCacheTableCompanion.insert({
    this.id = const Value.absent(),
    required String tradeDate,
    required String ticker,
    required String companyName,
    required double entryPrice,
    this.retT1 = const Value.absent(),
    this.retT3 = const Value.absent(),
    this.retT5 = const Value.absent(),
    this.currentPrice = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : tradeDate = Value(tradeDate),
       ticker = Value(ticker),
       companyName = Value(companyName),
       entryPrice = Value(entryPrice);
  static Insertable<BacktestCacheRow> custom({
    Expression<int>? id,
    Expression<String>? tradeDate,
    Expression<String>? ticker,
    Expression<String>? companyName,
    Expression<double>? entryPrice,
    Expression<double>? retT1,
    Expression<double>? retT3,
    Expression<double>? retT5,
    Expression<double>? currentPrice,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tradeDate != null) 'trade_date': tradeDate,
      if (ticker != null) 'ticker': ticker,
      if (companyName != null) 'company_name': companyName,
      if (entryPrice != null) 'entry_price': entryPrice,
      if (retT1 != null) 'ret_t1': retT1,
      if (retT3 != null) 'ret_t3': retT3,
      if (retT5 != null) 'ret_t5': retT5,
      if (currentPrice != null) 'current_price': currentPrice,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BacktestCacheTableCompanion copyWith({
    Value<int>? id,
    Value<String>? tradeDate,
    Value<String>? ticker,
    Value<String>? companyName,
    Value<double>? entryPrice,
    Value<double?>? retT1,
    Value<double?>? retT3,
    Value<double?>? retT5,
    Value<double?>? currentPrice,
    Value<DateTime>? createdAt,
  }) {
    return BacktestCacheTableCompanion(
      id: id ?? this.id,
      tradeDate: tradeDate ?? this.tradeDate,
      ticker: ticker ?? this.ticker,
      companyName: companyName ?? this.companyName,
      entryPrice: entryPrice ?? this.entryPrice,
      retT1: retT1 ?? this.retT1,
      retT3: retT3 ?? this.retT3,
      retT5: retT5 ?? this.retT5,
      currentPrice: currentPrice ?? this.currentPrice,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tradeDate.present) {
      map['trade_date'] = Variable<String>(tradeDate.value);
    }
    if (ticker.present) {
      map['ticker'] = Variable<String>(ticker.value);
    }
    if (companyName.present) {
      map['company_name'] = Variable<String>(companyName.value);
    }
    if (entryPrice.present) {
      map['entry_price'] = Variable<double>(entryPrice.value);
    }
    if (retT1.present) {
      map['ret_t1'] = Variable<double>(retT1.value);
    }
    if (retT3.present) {
      map['ret_t3'] = Variable<double>(retT3.value);
    }
    if (retT5.present) {
      map['ret_t5'] = Variable<double>(retT5.value);
    }
    if (currentPrice.present) {
      map['current_price'] = Variable<double>(currentPrice.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BacktestCacheTableCompanion(')
          ..write('id: $id, ')
          ..write('tradeDate: $tradeDate, ')
          ..write('ticker: $ticker, ')
          ..write('companyName: $companyName, ')
          ..write('entryPrice: $entryPrice, ')
          ..write('retT1: $retT1, ')
          ..write('retT3: $retT3, ')
          ..write('retT5: $retT5, ')
          ..write('currentPrice: $currentPrice, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTableTable extends AppSettingsTable
    with TableInfo<$AppSettingsTableTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTableTable createAlias(String alias) {
    return $AppSettingsTableTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const SettingRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsTableCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SettingRow copyWith({String? key, String? value, DateTime? updatedAt}) =>
      SettingRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SettingRow copyWithCompanion(AppSettingsTableCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsTableCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsTableCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsTableCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WatchlistTableTable watchlistTable = $WatchlistTableTable(this);
  late final $CacheBarsTableTable cacheBarsTable = $CacheBarsTableTable(this);
  late final $CacheNewsTableTable cacheNewsTable = $CacheNewsTableTable(this);
  late final $CacheAiTableTable cacheAiTable = $CacheAiTableTable(this);
  late final $ValidationCacheTableTable validationCacheTable =
      $ValidationCacheTableTable(this);
  late final $BacktestCacheTableTable backtestCacheTable =
      $BacktestCacheTableTable(this);
  late final $AppSettingsTableTable appSettingsTable = $AppSettingsTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    watchlistTable,
    cacheBarsTable,
    cacheNewsTable,
    cacheAiTable,
    validationCacheTable,
    backtestCacheTable,
    appSettingsTable,
  ];
}

typedef $$WatchlistTableTableCreateCompanionBuilder =
    WatchlistTableCompanion Function({
      required String ticker,
      Value<String?> alias,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$WatchlistTableTableUpdateCompanionBuilder =
    WatchlistTableCompanion Function({
      Value<String> ticker,
      Value<String?> alias,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$WatchlistTableTableFilterComposer
    extends Composer<_$AppDatabase, $WatchlistTableTable> {
  $$WatchlistTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ticker => $composableBuilder(
    column: $table.ticker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchlistTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchlistTableTable> {
  $$WatchlistTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ticker => $composableBuilder(
    column: $table.ticker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchlistTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchlistTableTable> {
  $$WatchlistTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ticker =>
      $composableBuilder(column: $table.ticker, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WatchlistTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchlistTableTable,
          WatchlistRow,
          $$WatchlistTableTableFilterComposer,
          $$WatchlistTableTableOrderingComposer,
          $$WatchlistTableTableAnnotationComposer,
          $$WatchlistTableTableCreateCompanionBuilder,
          $$WatchlistTableTableUpdateCompanionBuilder,
          (
            WatchlistRow,
            BaseReferences<_$AppDatabase, $WatchlistTableTable, WatchlistRow>,
          ),
          WatchlistRow,
          PrefetchHooks Function()
        > {
  $$WatchlistTableTableTableManager(
    _$AppDatabase db,
    $WatchlistTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchlistTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchlistTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchlistTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ticker = const Value.absent(),
                Value<String?> alias = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchlistTableCompanion(
                ticker: ticker,
                alias: alias,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ticker,
                Value<String?> alias = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchlistTableCompanion.insert(
                ticker: ticker,
                alias: alias,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchlistTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchlistTableTable,
      WatchlistRow,
      $$WatchlistTableTableFilterComposer,
      $$WatchlistTableTableOrderingComposer,
      $$WatchlistTableTableAnnotationComposer,
      $$WatchlistTableTableCreateCompanionBuilder,
      $$WatchlistTableTableUpdateCompanionBuilder,
      (
        WatchlistRow,
        BaseReferences<_$AppDatabase, $WatchlistTableTable, WatchlistRow>,
      ),
      WatchlistRow,
      PrefetchHooks Function()
    >;
typedef $$CacheBarsTableTableCreateCompanionBuilder =
    CacheBarsTableCompanion Function({
      required String symbol,
      required String interval,
      required String payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CacheBarsTableTableUpdateCompanionBuilder =
    CacheBarsTableCompanion Function({
      Value<String> symbol,
      Value<String> interval,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CacheBarsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CacheBarsTableTable> {
  $$CacheBarsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheBarsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheBarsTableTable> {
  $$CacheBarsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheBarsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheBarsTableTable> {
  $$CacheBarsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CacheBarsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheBarsTableTable,
          CacheBarRow,
          $$CacheBarsTableTableFilterComposer,
          $$CacheBarsTableTableOrderingComposer,
          $$CacheBarsTableTableAnnotationComposer,
          $$CacheBarsTableTableCreateCompanionBuilder,
          $$CacheBarsTableTableUpdateCompanionBuilder,
          (
            CacheBarRow,
            BaseReferences<_$AppDatabase, $CacheBarsTableTable, CacheBarRow>,
          ),
          CacheBarRow,
          PrefetchHooks Function()
        > {
  $$CacheBarsTableTableTableManager(
    _$AppDatabase db,
    $CacheBarsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheBarsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheBarsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheBarsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<String> interval = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheBarsTableCompanion(
                symbol: symbol,
                interval: interval,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required String interval,
                required String payload,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheBarsTableCompanion.insert(
                symbol: symbol,
                interval: interval,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheBarsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheBarsTableTable,
      CacheBarRow,
      $$CacheBarsTableTableFilterComposer,
      $$CacheBarsTableTableOrderingComposer,
      $$CacheBarsTableTableAnnotationComposer,
      $$CacheBarsTableTableCreateCompanionBuilder,
      $$CacheBarsTableTableUpdateCompanionBuilder,
      (
        CacheBarRow,
        BaseReferences<_$AppDatabase, $CacheBarsTableTable, CacheBarRow>,
      ),
      CacheBarRow,
      PrefetchHooks Function()
    >;
typedef $$CacheNewsTableTableCreateCompanionBuilder =
    CacheNewsTableCompanion Function({
      required String symbol,
      required String payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CacheNewsTableTableUpdateCompanionBuilder =
    CacheNewsTableCompanion Function({
      Value<String> symbol,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CacheNewsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CacheNewsTableTable> {
  $$CacheNewsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheNewsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheNewsTableTable> {
  $$CacheNewsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheNewsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheNewsTableTable> {
  $$CacheNewsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CacheNewsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheNewsTableTable,
          CacheNewsRow,
          $$CacheNewsTableTableFilterComposer,
          $$CacheNewsTableTableOrderingComposer,
          $$CacheNewsTableTableAnnotationComposer,
          $$CacheNewsTableTableCreateCompanionBuilder,
          $$CacheNewsTableTableUpdateCompanionBuilder,
          (
            CacheNewsRow,
            BaseReferences<_$AppDatabase, $CacheNewsTableTable, CacheNewsRow>,
          ),
          CacheNewsRow,
          PrefetchHooks Function()
        > {
  $$CacheNewsTableTableTableManager(
    _$AppDatabase db,
    $CacheNewsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheNewsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheNewsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheNewsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheNewsTableCompanion(
                symbol: symbol,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required String payload,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheNewsTableCompanion.insert(
                symbol: symbol,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheNewsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheNewsTableTable,
      CacheNewsRow,
      $$CacheNewsTableTableFilterComposer,
      $$CacheNewsTableTableOrderingComposer,
      $$CacheNewsTableTableAnnotationComposer,
      $$CacheNewsTableTableCreateCompanionBuilder,
      $$CacheNewsTableTableUpdateCompanionBuilder,
      (
        CacheNewsRow,
        BaseReferences<_$AppDatabase, $CacheNewsTableTable, CacheNewsRow>,
      ),
      CacheNewsRow,
      PrefetchHooks Function()
    >;
typedef $$CacheAiTableTableCreateCompanionBuilder =
    CacheAiTableCompanion Function({
      required String cacheKey,
      required String payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CacheAiTableTableUpdateCompanionBuilder =
    CacheAiTableCompanion Function({
      Value<String> cacheKey,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CacheAiTableTableFilterComposer
    extends Composer<_$AppDatabase, $CacheAiTableTable> {
  $$CacheAiTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheAiTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheAiTableTable> {
  $$CacheAiTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheAiTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheAiTableTable> {
  $$CacheAiTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CacheAiTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheAiTableTable,
          CacheAiRow,
          $$CacheAiTableTableFilterComposer,
          $$CacheAiTableTableOrderingComposer,
          $$CacheAiTableTableAnnotationComposer,
          $$CacheAiTableTableCreateCompanionBuilder,
          $$CacheAiTableTableUpdateCompanionBuilder,
          (
            CacheAiRow,
            BaseReferences<_$AppDatabase, $CacheAiTableTable, CacheAiRow>,
          ),
          CacheAiRow,
          PrefetchHooks Function()
        > {
  $$CacheAiTableTableTableManager(_$AppDatabase db, $CacheAiTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheAiTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheAiTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheAiTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheAiTableCompanion(
                cacheKey: cacheKey,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String payload,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheAiTableCompanion.insert(
                cacheKey: cacheKey,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheAiTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheAiTableTable,
      CacheAiRow,
      $$CacheAiTableTableFilterComposer,
      $$CacheAiTableTableOrderingComposer,
      $$CacheAiTableTableAnnotationComposer,
      $$CacheAiTableTableCreateCompanionBuilder,
      $$CacheAiTableTableUpdateCompanionBuilder,
      (
        CacheAiRow,
        BaseReferences<_$AppDatabase, $CacheAiTableTable, CacheAiRow>,
      ),
      CacheAiRow,
      PrefetchHooks Function()
    >;
typedef $$ValidationCacheTableTableCreateCompanionBuilder =
    ValidationCacheTableCompanion Function({
      required String cacheKey,
      required String payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ValidationCacheTableTableUpdateCompanionBuilder =
    ValidationCacheTableCompanion Function({
      Value<String> cacheKey,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ValidationCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $ValidationCacheTableTable> {
  $$ValidationCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ValidationCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ValidationCacheTableTable> {
  $$ValidationCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ValidationCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ValidationCacheTableTable> {
  $$ValidationCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ValidationCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ValidationCacheTableTable,
          ValidationCacheRow,
          $$ValidationCacheTableTableFilterComposer,
          $$ValidationCacheTableTableOrderingComposer,
          $$ValidationCacheTableTableAnnotationComposer,
          $$ValidationCacheTableTableCreateCompanionBuilder,
          $$ValidationCacheTableTableUpdateCompanionBuilder,
          (
            ValidationCacheRow,
            BaseReferences<
              _$AppDatabase,
              $ValidationCacheTableTable,
              ValidationCacheRow
            >,
          ),
          ValidationCacheRow,
          PrefetchHooks Function()
        > {
  $$ValidationCacheTableTableTableManager(
    _$AppDatabase db,
    $ValidationCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ValidationCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ValidationCacheTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ValidationCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ValidationCacheTableCompanion(
                cacheKey: cacheKey,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String payload,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ValidationCacheTableCompanion.insert(
                cacheKey: cacheKey,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ValidationCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ValidationCacheTableTable,
      ValidationCacheRow,
      $$ValidationCacheTableTableFilterComposer,
      $$ValidationCacheTableTableOrderingComposer,
      $$ValidationCacheTableTableAnnotationComposer,
      $$ValidationCacheTableTableCreateCompanionBuilder,
      $$ValidationCacheTableTableUpdateCompanionBuilder,
      (
        ValidationCacheRow,
        BaseReferences<
          _$AppDatabase,
          $ValidationCacheTableTable,
          ValidationCacheRow
        >,
      ),
      ValidationCacheRow,
      PrefetchHooks Function()
    >;
typedef $$BacktestCacheTableTableCreateCompanionBuilder =
    BacktestCacheTableCompanion Function({
      Value<int> id,
      required String tradeDate,
      required String ticker,
      required String companyName,
      required double entryPrice,
      Value<double?> retT1,
      Value<double?> retT3,
      Value<double?> retT5,
      Value<double?> currentPrice,
      Value<DateTime> createdAt,
    });
typedef $$BacktestCacheTableTableUpdateCompanionBuilder =
    BacktestCacheTableCompanion Function({
      Value<int> id,
      Value<String> tradeDate,
      Value<String> ticker,
      Value<String> companyName,
      Value<double> entryPrice,
      Value<double?> retT1,
      Value<double?> retT3,
      Value<double?> retT5,
      Value<double?> currentPrice,
      Value<DateTime> createdAt,
    });

class $$BacktestCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $BacktestCacheTableTable> {
  $$BacktestCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tradeDate => $composableBuilder(
    column: $table.tradeDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ticker => $composableBuilder(
    column: $table.ticker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get entryPrice => $composableBuilder(
    column: $table.entryPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get retT1 => $composableBuilder(
    column: $table.retT1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get retT3 => $composableBuilder(
    column: $table.retT3,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get retT5 => $composableBuilder(
    column: $table.retT5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentPrice => $composableBuilder(
    column: $table.currentPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BacktestCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BacktestCacheTableTable> {
  $$BacktestCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tradeDate => $composableBuilder(
    column: $table.tradeDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ticker => $composableBuilder(
    column: $table.ticker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get entryPrice => $composableBuilder(
    column: $table.entryPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get retT1 => $composableBuilder(
    column: $table.retT1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get retT3 => $composableBuilder(
    column: $table.retT3,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get retT5 => $composableBuilder(
    column: $table.retT5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentPrice => $composableBuilder(
    column: $table.currentPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BacktestCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BacktestCacheTableTable> {
  $$BacktestCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tradeDate =>
      $composableBuilder(column: $table.tradeDate, builder: (column) => column);

  GeneratedColumn<String> get ticker =>
      $composableBuilder(column: $table.ticker, builder: (column) => column);

  GeneratedColumn<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get entryPrice => $composableBuilder(
    column: $table.entryPrice,
    builder: (column) => column,
  );

  GeneratedColumn<double> get retT1 =>
      $composableBuilder(column: $table.retT1, builder: (column) => column);

  GeneratedColumn<double> get retT3 =>
      $composableBuilder(column: $table.retT3, builder: (column) => column);

  GeneratedColumn<double> get retT5 =>
      $composableBuilder(column: $table.retT5, builder: (column) => column);

  GeneratedColumn<double> get currentPrice => $composableBuilder(
    column: $table.currentPrice,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BacktestCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BacktestCacheTableTable,
          BacktestCacheRow,
          $$BacktestCacheTableTableFilterComposer,
          $$BacktestCacheTableTableOrderingComposer,
          $$BacktestCacheTableTableAnnotationComposer,
          $$BacktestCacheTableTableCreateCompanionBuilder,
          $$BacktestCacheTableTableUpdateCompanionBuilder,
          (
            BacktestCacheRow,
            BaseReferences<
              _$AppDatabase,
              $BacktestCacheTableTable,
              BacktestCacheRow
            >,
          ),
          BacktestCacheRow,
          PrefetchHooks Function()
        > {
  $$BacktestCacheTableTableTableManager(
    _$AppDatabase db,
    $BacktestCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BacktestCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BacktestCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BacktestCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> tradeDate = const Value.absent(),
                Value<String> ticker = const Value.absent(),
                Value<String> companyName = const Value.absent(),
                Value<double> entryPrice = const Value.absent(),
                Value<double?> retT1 = const Value.absent(),
                Value<double?> retT3 = const Value.absent(),
                Value<double?> retT5 = const Value.absent(),
                Value<double?> currentPrice = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BacktestCacheTableCompanion(
                id: id,
                tradeDate: tradeDate,
                ticker: ticker,
                companyName: companyName,
                entryPrice: entryPrice,
                retT1: retT1,
                retT3: retT3,
                retT5: retT5,
                currentPrice: currentPrice,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String tradeDate,
                required String ticker,
                required String companyName,
                required double entryPrice,
                Value<double?> retT1 = const Value.absent(),
                Value<double?> retT3 = const Value.absent(),
                Value<double?> retT5 = const Value.absent(),
                Value<double?> currentPrice = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BacktestCacheTableCompanion.insert(
                id: id,
                tradeDate: tradeDate,
                ticker: ticker,
                companyName: companyName,
                entryPrice: entryPrice,
                retT1: retT1,
                retT3: retT3,
                retT5: retT5,
                currentPrice: currentPrice,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BacktestCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BacktestCacheTableTable,
      BacktestCacheRow,
      $$BacktestCacheTableTableFilterComposer,
      $$BacktestCacheTableTableOrderingComposer,
      $$BacktestCacheTableTableAnnotationComposer,
      $$BacktestCacheTableTableCreateCompanionBuilder,
      $$BacktestCacheTableTableUpdateCompanionBuilder,
      (
        BacktestCacheRow,
        BaseReferences<
          _$AppDatabase,
          $BacktestCacheTableTable,
          BacktestCacheRow
        >,
      ),
      BacktestCacheRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableTableCreateCompanionBuilder =
    AppSettingsTableCompanion Function({
      required String key,
      required String value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableTableUpdateCompanionBuilder =
    AppSettingsTableCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTableTable,
          SettingRow,
          $$AppSettingsTableTableFilterComposer,
          $$AppSettingsTableTableOrderingComposer,
          $$AppSettingsTableTableAnnotationComposer,
          $$AppSettingsTableTableCreateCompanionBuilder,
          $$AppSettingsTableTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTableTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableTableManager(
    _$AppDatabase db,
    $AppSettingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsTableCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsTableCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTableTable,
      SettingRow,
      $$AppSettingsTableTableFilterComposer,
      $$AppSettingsTableTableOrderingComposer,
      $$AppSettingsTableTableAnnotationComposer,
      $$AppSettingsTableTableCreateCompanionBuilder,
      $$AppSettingsTableTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTableTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WatchlistTableTableTableManager get watchlistTable =>
      $$WatchlistTableTableTableManager(_db, _db.watchlistTable);
  $$CacheBarsTableTableTableManager get cacheBarsTable =>
      $$CacheBarsTableTableTableManager(_db, _db.cacheBarsTable);
  $$CacheNewsTableTableTableManager get cacheNewsTable =>
      $$CacheNewsTableTableTableManager(_db, _db.cacheNewsTable);
  $$CacheAiTableTableTableManager get cacheAiTable =>
      $$CacheAiTableTableTableManager(_db, _db.cacheAiTable);
  $$ValidationCacheTableTableTableManager get validationCacheTable =>
      $$ValidationCacheTableTableTableManager(_db, _db.validationCacheTable);
  $$BacktestCacheTableTableTableManager get backtestCacheTable =>
      $$BacktestCacheTableTableTableManager(_db, _db.backtestCacheTable);
  $$AppSettingsTableTableTableManager get appSettingsTable =>
      $$AppSettingsTableTableTableManager(_db, _db.appSettingsTable);
}
