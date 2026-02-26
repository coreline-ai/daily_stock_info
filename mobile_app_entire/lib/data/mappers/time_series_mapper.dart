import 'package:mobile_app_entire/data/dto/time_series_dto.dart';
import 'package:mobile_app_entire/domain/entities/market.dart';

class TimeSeriesMapper {
  const TimeSeriesMapper();

  List<PriceBar> toPriceBars(List<TimeSeriesEntryDto> values) {
    return values
        .map((entry) {
          final parsed = DateTime.tryParse(entry.datetime) ?? DateTime.now();
          return PriceBar(
            time: parsed,
            open: entry.open,
            high: entry.high,
            low: entry.low,
            close: entry.close,
            volume: entry.volume,
          );
        })
        .toList(growable: false);
  }
}
