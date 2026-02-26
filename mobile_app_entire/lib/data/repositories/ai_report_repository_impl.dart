import 'dart:convert';

import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/failure/app_failure.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/data/gateways/glm_gateway.dart';
import 'package:mobile_app_entire/data/local/app_database.dart';
import 'package:mobile_app_entire/domain/entities/ai_report.dart';
import 'package:mobile_app_entire/domain/repositories/ai_report_repository.dart';
import 'package:mobile_app_entire/domain/repositories/credential_repository.dart';

class AiReportRepositoryImpl implements AiReportRepository {
  const AiReportRepositoryImpl({
    required GlmGateway gateway,
    required CredentialRepository credentialRepository,
    required AppDatabase database,
  }) : _gateway = gateway,
       _credentialRepository = credentialRepository,
       _database = database;

  final GlmGateway _gateway;
  final CredentialRepository _credentialRepository;
  final AppDatabase _database;

  @override
  Future<Result<AiReport>> generate(AiReportQuery query) async {
    try {
      final cacheKey = _cacheKey(query);
      final cached = await _database.getAiCache(cacheKey: cacheKey);
      if (cached != null) {
        final parsed = _decodeCached(cached.payload);
        if (parsed != null) {
          return Success(parsed);
        }
      }

      final credentialsResult = await _credentialRepository.load();
      final credentials = credentialsResult.when(
        success: (value) => value,
        failure: (_) => ApiCredentials.empty,
      );
      final glmKey = credentials.glmKey.trim();

      if (glmKey.isEmpty) {
        return const Failure(AuthFailure('실데이터 강제 모드에서는 GLM API 키를 입력해야 합니다.'));
      }

      if (_isDemoKey(glmKey)) {
        return const Failure(
          AuthFailure('실데이터 강제 모드에서는 demo GLM 키를 사용할 수 없습니다.'),
        );
      }

      final prompt = _prompt(query);
      try {
        final text = await _gateway.summarize(
          apiKey: glmKey,
          model: 'glm-4.5',
          prompt: prompt,
        );
        final report = AiReport(
          provider: 'glm',
          model: 'glm-4.5',
          generatedAt: DateTime.now(),
          summary: text.length > 300 ? '${text.substring(0, 300)}...' : text,
          conclusion: _extractConclusion(text),
          riskFactors: _extractRisks(text),
          confidenceScore: 78,
          confidenceLevel: 'high',
          warnings: const [],
        );
        await _database.putAiCache(
          cacheKey: cacheKey,
          payload: jsonEncode(_encode(report)),
        );
        return Success(report);
      } catch (error) {
        return Failure(NetworkFailure('GLM 요청에 실패했습니다: $error'));
      }
    } catch (error) {
      return Failure(UnknownFailure('AI 리포트 생성에 실패했습니다: $error'));
    }
  }

  String _cacheKey(AiReportQuery query) {
    return '${query.ticker}|${query.newsSummary.join('|')}|${query.themes.join('|')}';
  }

  String _prompt(AiReportQuery query) {
    return '''
Ticker: ${query.ticker}
Company: ${query.companyName}
Summary: ${query.summary}
News:
- ${query.newsSummary.join('\n- ')}
Themes: ${query.themes.join(', ')}
Please answer in Korean with concise analysis, conclusion, and key risks.
''';
  }

  String _extractConclusion(String text) {
    final sentences = text
        .replaceAll('\n', ' ')
        .split('.')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (sentences.isEmpty) {
      return '분할 진입과 손절 기준을 함께 설정해 추세 지속 여부를 확인하세요.';
    }
    return sentences.first;
  }

  List<String> _extractRisks(String text) {
    final tokens = text
        .split(RegExp(r'[\n\.]'))
        .map((line) => line.trim())
        .where(
          (line) =>
              line.toLowerCase().contains('risk') ||
              line.contains('리스크') ||
              line.contains('주의'),
        )
        .toList(growable: false);
    if (tokens.isEmpty) {
      return const [
        '시장 변동성이 단기간에 급격히 확대될 수 있습니다.',
        '손절 기준을 사전에 정하고 기계적으로 집행하세요.',
      ];
    }
    return tokens.take(3).toList(growable: false);
  }

  bool _isDemoKey(String key) {
    return key.trim().toLowerCase() == 'demo';
  }

  Map<String, dynamic> _encode(AiReport report) {
    return {
      'provider': report.provider,
      'model': report.model,
      'generatedAt': report.generatedAt.toIso8601String(),
      'summary': report.summary,
      'conclusion': report.conclusion,
      'riskFactors': report.riskFactors,
      'confidenceScore': report.confidenceScore,
      'confidenceLevel': report.confidenceLevel,
      'warnings': report.warnings,
    };
  }

  AiReport? _decodeCached(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) {
        return null;
      }
      final map = json.map((k, v) => MapEntry(k.toString(), v));
      return AiReport(
        provider: map['provider']?.toString() ?? 'cache',
        model: map['model']?.toString() ?? 'cache',
        generatedAt:
            DateTime.tryParse(map['generatedAt']?.toString() ?? '') ??
            DateTime.now(),
        summary: map['summary']?.toString() ?? '',
        conclusion: map['conclusion']?.toString() ?? '',
        riskFactors: (map['riskFactors'] is List)
            ? (map['riskFactors'] as List)
                  .map((e) => e.toString())
                  .toList(growable: false)
            : const [],
        confidenceScore:
            int.tryParse(map['confidenceScore']?.toString() ?? '') ?? 0,
        confidenceLevel: map['confidenceLevel']?.toString() ?? 'low',
        warnings: (map['warnings'] is List)
            ? (map['warnings'] as List)
                  .map((e) => e.toString())
                  .toList(growable: false)
            : const [],
      );
    } catch (_) {
      return null;
    }
  }
}
