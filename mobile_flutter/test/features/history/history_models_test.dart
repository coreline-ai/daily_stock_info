import 'package:coreline_stock_ai/features/history/domain/entities/history_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BacktestHistoryItemModel parses open/close/current fields', () {
    final item = BacktestHistoryItemModel.fromJson({
      'tradeDate': '2026-02-25',
      'ticker': '003490',
      'companyName': '대한항공',
      'entryPrice': 25100,
      'dayOpen': 25100,
      'dayClose': 25150,
      'currentPrice': 25150,
      'currentPriceDate': '2026-02-25',
      'retT1': 5.17,
      'netRetT1': 4.87,
    });

    expect(item.dayOpen, 25100);
    expect(item.dayClose, 25150);
    expect(item.currentPrice, 25150);
    expect(item.currentPriceDate, '2026-02-25');
    expect(item.netRetT1, closeTo(4.87, 0.0001));
  });
}
