import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

class GoogleNewsRssGateway {
  GoogleNewsRssGateway({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<String>> fetchNewsTitles({
    required String ticker,
    required String companyName,
    int limit = 20,
  }) async {
    final response = await _dio.get<String>(
      '/rss/search',
      queryParameters: {
        'q': '$ticker $companyName 주식',
        'hl': 'ko',
        'gl': 'KR',
        'ceid': 'KR:ko',
      },
      options: Options(responseType: ResponseType.plain),
    );

    final raw = response.data ?? '';
    if (raw.trim().isEmpty) {
      return const [];
    }

    final document = XmlDocument.parse(raw);
    final titles = <String>[];

    for (final item in document.findAllElements('item')) {
      final title = item.getElement('title')?.innerText.trim() ?? '';
      if (title.isEmpty) {
        continue;
      }
      titles.add(_sanitizeTitle(title));
      if (titles.length >= limit) {
        break;
      }
    }

    return titles;
  }

  String _sanitizeTitle(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
