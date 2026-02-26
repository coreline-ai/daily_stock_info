import 'package:dio/dio.dart';
import 'package:mobile_app_entire/data/dto/news_dto.dart';
import 'package:mobile_app_entire/data/dto/quote_dto.dart';

class FinnhubGateway {
  FinnhubGateway({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<QuoteDto> fetchQuote({
    required String symbol,
    required String apiKey,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/quote',
      queryParameters: {'symbol': symbol, 'token': apiKey},
    );
    return QuoteDto.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<List<NewsDto>> fetchCompanyNews({
    required String symbol,
    required String apiKey,
    required String from,
    required String to,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/company-news',
      queryParameters: {
        'symbol': symbol,
        'from': from,
        'to': to,
        'token': apiKey,
      },
    );
    final body = response.data ?? const <dynamic>[];
    return body
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .map(NewsDto.fromJson)
        .toList(growable: false);
  }
}
