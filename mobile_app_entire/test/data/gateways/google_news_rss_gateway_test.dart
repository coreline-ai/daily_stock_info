import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile_app_entire/data/gateways/google_news_rss_gateway.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late GoogleNewsRssGateway gateway;

  setUp(() {
    dio = _MockDio();
    gateway = GoogleNewsRssGateway(dio: dio);
  });

  test('fetchNewsTitles parses rss titles', () async {
    const rss = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item><title>삼성전자 급등 - 매체A</title></item>
    <item><title>반도체 업황 개선 - 매체B</title></item>
  </channel>
</rss>
''';

    when(
      () => dio.get<String>(
        '/rss/search',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<String>(
        requestOptions: RequestOptions(path: '/rss/search'),
        data: rss,
      ),
    );

    final titles = await gateway.fetchNewsTitles(
      ticker: '005930',
      companyName: '삼성전자',
      limit: 10,
    );

    expect(titles.length, 2);
    expect(titles.first, '삼성전자 급등 - 매체A');
  });

  test('fetchNewsTitles returns empty on empty rss items', () async {
    const rss = '<rss><channel></channel></rss>';

    when(
      () => dio.get<String>(
        '/rss/search',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<String>(
        requestOptions: RequestOptions(path: '/rss/search'),
        data: rss,
      ),
    );

    final titles = await gateway.fetchNewsTitles(
      ticker: '005930',
      companyName: '삼성전자',
    );

    expect(titles, isEmpty);
  });
}
