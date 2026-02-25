import 'package:intl/intl.dart';

class DateKst {
  const DateKst._();

  static DateTime nowKst() {
    final nowUtc = DateTime.now().toUtc();
    return nowUtc.add(const Duration(hours: 9));
  }

  static String todayIso() {
    return DateFormat('yyyy-MM-dd').format(nowKst());
  }

  static String toDisplay(String isoDate) {
    try {
      final parsed = DateTime.parse(isoDate);
      return DateFormat('yyyy. MM. dd.').format(parsed);
    } catch (_) {
      return isoDate;
    }
  }
}
