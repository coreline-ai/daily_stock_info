import 'package:dio/dio.dart';
import 'package:mobile_app_entire/data/dto/news_dto.dart';
import 'package:mobile_app_entire/data/dto/time_series_dto.dart';

class NaverFreeMarketGateway {
  NaverFreeMarketGateway({required Dio apiDio, required Dio financeDio})
    : _apiDio = apiDio,
      _financeDio = financeDio;

  final Dio _apiDio;
  final Dio _financeDio;

  Future<List<TimeSeriesEntryDto>> fetchDailyBars(
    String ticker, {
    int days = 120,
  }) async {
    List<TimeSeriesEntryDto> fromApi = const [];
    try {
      fromApi = await _fetchDailyBarsFromApi(ticker, days: days);
    } catch (_) {
      fromApi = const [];
    }
    if (fromApi.length >= 20) {
      return fromApi;
    }

    // The public day endpoint may return too few rows depending on market state,
    // so parse Naver daily table pages as a free fallback.
    final fromHtml = await _fetchDailyBarsFromHtml(ticker, days: days);
    if (fromHtml.isNotEmpty) {
      return fromHtml;
    }

    return fromApi;
  }

  Future<List<NewsDto>> fetchStockNews({
    required String ticker,
    int limit = 20,
  }) async {
    final response = await _apiDio.get<List<dynamic>>(
      '/news/stock/$ticker',
      options: Options(
        headers: const {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://finance.naver.com/',
        },
      ),
    );
    final root = response.data ?? const <dynamic>[];
    if (root.isEmpty || root.first is! Map) {
      return const [];
    }

    final first = (root.first as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final items = first['items'];
    if (items is! List) {
      return const [];
    }

    final rows = <NewsDto>[];
    for (final raw in items.whereType<Map>()) {
      final item = raw.map((k, v) => MapEntry(k.toString(), v));
      rows.add(
        NewsDto(
          headline: item['title']?.toString() ?? '',
          summary: item['body']?.toString() ?? '',
          url: item['link']?.toString() ?? '',
          datetime: int.tryParse(item['datetime']?.toString() ?? '') ?? 0,
        ),
      );
      if (rows.length >= limit) {
        break;
      }
    }
    return rows;
  }

  Future<List<TimeSeriesEntryDto>> _fetchDailyBarsFromApi(
    String ticker, {
    int days = 120,
  }) async {
    final response = await _apiDio.get<List<dynamic>>(
      '/chart/domestic/item/$ticker/day',
      queryParameters: {'count': days},
      options: Options(
        headers: const {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://finance.naver.com/',
        },
      ),
    );

    final body = response.data ?? const <dynamic>[];
    final rows = body
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .map((item) {
          final localDate = item['localDate']?.toString() ?? '';
          final normalizedDate = localDate.length == 8
              ? '${localDate.substring(0, 4)}-${localDate.substring(4, 6)}-${localDate.substring(6, 8)}'
              : localDate;
          return TimeSeriesEntryDto(
            datetime: normalizedDate,
            open: _parseDouble(item['openPrice']),
            high: _parseDouble(item['highPrice']),
            low: _parseDouble(item['lowPrice']),
            close: _parseDouble(item['closePrice']),
            volume: _parseDouble(item['accumulatedTradingVolume']),
          );
        })
        .toList(growable: false);

    // API returns latest-first in observed responses.
    final ascending = rows.reversed.toList(growable: false);
    return _trimSeries(ascending, max: days);
  }

  Future<List<TimeSeriesEntryDto>> _fetchDailyBarsFromHtml(
    String ticker, {
    int days = 120,
  }) async {
    final parsed = <TimeSeriesEntryDto>[];
    final seenDates = <String>{};
    final maxPages = ((days + 9) ~/ 10).clamp(1, 20);

    for (var page = 1; page <= maxPages && parsed.length < days; page++) {
      final response = await _financeDio.get<String>(
        '/item/sise_day.naver',
        queryParameters: {'code': ticker, 'page': page},
        options: Options(
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)',
            'Referer': 'https://finance.naver.com/',
            'Accept': 'text/html',
          },
          responseType: ResponseType.plain,
        ),
      );

      final html = response.data ?? '';
      if (html.isEmpty) {
        continue;
      }

      final rows = RegExp(
        r'<tr[^>]*>(.*?)</tr>',
        dotAll: true,
      ).allMatches(html);
      var anyParsed = false;

      for (final row in rows) {
        final content = row.group(1) ?? '';
        final dateMatch = RegExp(
          r'<span class="tah p10 gray03">([0-9]{4}\.[0-9]{2}\.[0-9]{2})</span>',
        ).firstMatch(content);
        if (dateMatch == null) {
          continue;
        }

        final date = dateMatch.group(1)!.replaceAll('.', '-');
        if (seenDates.contains(date)) {
          continue;
        }

        final nums =
            RegExp(
                  r'<span class="tah p11(?: [^"]*)?">\s*([0-9,]+)\s*</span>',
                  dotAll: true,
                )
                .allMatches(content)
                .map((m) => _parseDouble(m.group(1)))
                .where((v) => v > 0)
                .toList(growable: false);

        // close, diff, open, high, low, volume
        if (nums.length < 6) {
          continue;
        }

        parsed.add(
          TimeSeriesEntryDto(
            datetime: date,
            open: nums[2],
            high: nums[3],
            low: nums[4],
            close: nums[0],
            volume: nums[5],
          ),
        );
        seenDates.add(date);
        anyParsed = true;

        if (parsed.length >= days) {
          break;
        }
      }

      if (!anyParsed) {
        break;
      }
    }

    // Parsed rows are latest-first by page order.
    final ascending = parsed.reversed.toList(growable: false);
    return _trimSeries(ascending, max: days);
  }

  List<TimeSeriesEntryDto> _trimSeries(
    List<TimeSeriesEntryDto> input, {
    required int max,
  }) {
    if (input.length <= max) {
      return input;
    }
    return input.sublist(input.length - max);
  }

  double _parseDouble(dynamic value) {
    final raw = value?.toString() ?? '';
    return double.tryParse(raw.replaceAll(',', '')) ?? 0;
  }
}
