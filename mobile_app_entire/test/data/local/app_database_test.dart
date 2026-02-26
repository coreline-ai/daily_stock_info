import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_entire/data/local/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('watchlist CRUD works', () async {
    await database.upsertTicker('005930');
    await database.upsertTicker('000660');

    final rows = await database.getWatchlist();
    expect(rows.length, 2);

    await database.deleteTicker('000660');
    final rowsAfterDelete = await database.getWatchlist();
    expect(rowsAfterDelete.length, 1);
    expect(rowsAfterDelete.first.ticker, '005930');
  });

  test('settings key-value works', () async {
    await database.putSetting('theme', 'dark');
    final value = await database.getSetting('theme');
    expect(value, 'dark');
  });
}
