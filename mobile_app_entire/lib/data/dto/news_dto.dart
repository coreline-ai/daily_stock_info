class NewsDto {
  const NewsDto({
    required this.headline,
    required this.summary,
    required this.url,
    required this.datetime,
  });

  final String headline;
  final String summary;
  final String url;
  final int datetime;

  factory NewsDto.fromJson(Map<String, dynamic> json) {
    return NewsDto(
      headline: json['headline']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      datetime: int.tryParse(json['datetime']?.toString() ?? '') ?? 0,
    );
  }
}
