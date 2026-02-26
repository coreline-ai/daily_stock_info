import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile_app_entire/data/gateways/naver_free_market_gateway.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio apiDio;
  late _MockDio financeDio;
  late NaverFreeMarketGateway gateway;

  setUp(() {
    apiDio = _MockDio();
    financeDio = _MockDio();
    gateway = NaverFreeMarketGateway(apiDio: apiDio, financeDio: financeDio);
  });

  test('fetchDailyBars parses api response', () async {
    final apiRows = List.generate(20, (index) {
      final day = (20 - index).toString().padLeft(2, '0');
      return {
        'localDate': '202602$day',
        'openPrice': 100 + index,
        'highPrice': 110 + index,
        'lowPrice': 90 + index,
        'closePrice': 105 + index,
        'accumulatedTradingVolume': 100000 + index,
      };
    });

    when(
      () => apiDio.get<List<dynamic>>(
        '/chart/domestic/item/005930/day',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/chart/domestic/item/005930/day'),
        data: apiRows,
      ),
    );

    final result = await gateway.fetchDailyBars('005930', days: 20);

    expect(result.length, 20);
    expect(result.first.datetime, '2026-02-01');
    expect(result.last.datetime, '2026-02-20');
  });

  test('fetchDailyBars falls back to html parser', () async {
    when(
      () => apiDio.get<List<dynamic>>(
        '/chart/domestic/item/005930/day',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/chart/domestic/item/005930/day'),
        data: const [],
      ),
    );

    const htmlPage1 = '''
<tr onMouseOver="mouseOver(this)" onMouseOut="mouseOut(this)">
<td align="center"><span class="tah p10 gray03">2026.02.26</span></td>
<td class="num"><span class="tah p11">214,500</span></td>
<td class="num"><span class="tah p11 red02">10,000</span></td>
<td class="num"><span class="tah p11">206,500</span></td>
<td class="num"><span class="tah p11">217,500</span></td>
<td class="num"><span class="tah p11">206,000</span></td>
<td class="num"><span class="tah p11">14,688,812</span></td>
</tr>
<tr onMouseOver="mouseOver(this)" onMouseOut="mouseOut(this)">
<td align="center"><span class="tah p10 gray03">2026.02.25</span></td>
<td class="num"><span class="tah p11">203,500</span></td>
<td class="num"><span class="tah p11 red02">3,500</span></td>
<td class="num"><span class="tah p11">202,500</span></td>
<td class="num"><span class="tah p11">206,000</span></td>
<td class="num"><span class="tah p11">201,000</span></td>
<td class="num"><span class="tah p11">26,987,996</span></td>
</tr>
''';

    when(
      () => financeDio.get<String>(
        '/item/sise_day.naver',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((invocation) async {
      final page = (invocation.namedArguments[#queryParameters] as Map)['page'];
      return Response<String>(
        requestOptions: RequestOptions(path: '/item/sise_day.naver'),
        data: page == 1 ? htmlPage1 : '<html></html>',
      );
    });

    final result = await gateway.fetchDailyBars('005930', days: 20);

    expect(result.length, 2);
    expect(result.first.datetime, '2026-02-25');
    expect(result.last.datetime, '2026-02-26');
    expect(result.last.close, 214500);
  });

  test('fetchStockNews parses naver stock news response', () async {
    when(
      () => apiDio.get<List<dynamic>>(
        '/news/stock/005930',
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/news/stock/005930'),
        data: const [
          {
            'total': 1,
            'items': [
              {
                'title': '삼성전자 실적 개선',
                'body': '요약',
                'link': 'https://example.com/news',
                'datetime': '202602261124',
              },
            ],
          },
        ],
      ),
    );

    final news = await gateway.fetchStockNews(ticker: '005930');

    expect(news.length, 1);
    expect(news.first.headline, '삼성전자 실적 개선');
    expect(news.first.summary, '요약');
  });
}
