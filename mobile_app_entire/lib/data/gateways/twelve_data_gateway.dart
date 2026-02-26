import 'package:dio/dio.dart';
import 'package:mobile_app_entire/data/dto/time_series_dto.dart';

class TwelveDataGateway {
  TwelveDataGateway({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<TimeSeriesEntryDto>> fetchTimeSeries({
    required String symbol,
    required String apiKey,
    String interval = '1day',
    int outputSize = 120,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/time_series',
      queryParameters: {
        'symbol': symbol,
        'interval': interval,
        'outputsize': outputSize,
        'apikey': apiKey,
      },
    );

    final body = response.data ?? const <String, dynamic>{};
    final status = body['status']?.toString() ?? 'ok';
    if (status == 'error') {
      throw Exception(body['message']?.toString() ?? 'twelvedata error');
    }

    final values = body['values'];
    if (values is! List) {
      return const [];
    }

    return values
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .map(TimeSeriesEntryDto.fromJson)
        .toList(growable: false);
  }
}
