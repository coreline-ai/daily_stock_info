class QuoteDto {
  const QuoteDto({
    required this.current,
    required this.change,
    required this.percentChange,
  });

  final double current;
  final double change;
  final double percentChange;

  factory QuoteDto.fromJson(Map<String, dynamic> json) {
    double parse(dynamic value) => double.tryParse(value.toString()) ?? 0;

    return QuoteDto(
      current: parse(json['c']),
      change: parse(json['d']),
      percentChange: parse(json['dp']),
    );
  }
}
