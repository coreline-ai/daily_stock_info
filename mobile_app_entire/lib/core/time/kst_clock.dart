import 'package:intl/intl.dart';

class KstClock {
  DateTime nowUtc() => DateTime.now().toUtc();

  DateTime nowKst() => nowUtc().add(const Duration(hours: 9));

  String todayIsoKst() => DateFormat('yyyy-MM-dd').format(nowKst());

  DateTime parseIsoDate(String date) {
    return DateTime.parse('${date}T00:00:00');
  }
}
