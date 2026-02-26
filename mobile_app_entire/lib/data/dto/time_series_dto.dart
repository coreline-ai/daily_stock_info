class TimeSeriesEntryDto {
  const TimeSeriesEntryDto({
    required this.datetime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final String datetime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  factory TimeSeriesEntryDto.fromJson(Map<String, dynamic> json) {
    double parse(dynamic value) => double.tryParse(value.toString()) ?? 0;

    return TimeSeriesEntryDto(
      datetime: json['datetime']?.toString() ?? '',
      open: parse(json['open']),
      high: parse(json['high']),
      low: parse(json['low']),
      close: parse(json['close']),
      volume: parse(json['volume']),
    );
  }
}
