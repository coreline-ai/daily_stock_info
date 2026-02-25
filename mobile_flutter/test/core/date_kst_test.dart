import 'package:coreline_stock_ai/core/util/date_kst.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('todayIso returns yyyy-MM-dd format', () {
    final iso = DateKst.todayIso();
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(iso), isTrue);
  });

  test('toDisplay formats iso date', () {
    expect(DateKst.toDisplay('2026-02-25'), '2026. 02. 25.');
  });
}
