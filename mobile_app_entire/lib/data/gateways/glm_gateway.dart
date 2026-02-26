import 'package:dio/dio.dart';

class GlmGateway {
  GlmGateway({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<String> summarize({
    required String apiKey,
    required String model,
    required String prompt,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a financial summarizer. Respond in concise JSON-like plain text.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.2,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
    );

    final body = response.data ?? const <String, dynamic>{};
    final choices = body['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final message = first['message'];
        if (message is Map) {
          final content = message['content']?.toString() ?? '';
          if (content.isNotEmpty) {
            return content;
          }
        }
      }
    }
    throw Exception('Invalid GLM response');
  }
}
