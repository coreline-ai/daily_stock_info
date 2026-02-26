import 'package:mobile_app_entire/core/result/result.dart';

class ApiCredentials {
  const ApiCredentials({
    required this.twelveDataKey,
    required this.finnhubKey,
    required this.glmKey,
    required this.glmBaseUrl,
  });

  final String twelveDataKey;
  final String finnhubKey;
  final String glmKey;
  final String glmBaseUrl;

  bool get hasMarketKeys => twelveDataKey.isNotEmpty && finnhubKey.isNotEmpty;
  bool get hasGlmKey => glmKey.isNotEmpty;

  ApiCredentials copyWith({
    String? twelveDataKey,
    String? finnhubKey,
    String? glmKey,
    String? glmBaseUrl,
  }) {
    return ApiCredentials(
      twelveDataKey: twelveDataKey ?? this.twelveDataKey,
      finnhubKey: finnhubKey ?? this.finnhubKey,
      glmKey: glmKey ?? this.glmKey,
      glmBaseUrl: glmBaseUrl ?? this.glmBaseUrl,
    );
  }

  // Empty state for first-run key onboarding.
  static const empty = ApiCredentials(
    twelveDataKey: '',
    finnhubKey: '',
    glmKey: '',
    glmBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
  );
}

abstract interface class CredentialRepository {
  Future<Result<ApiCredentials>> load();
  Future<Result<void>> save(ApiCredentials credentials);
  Future<Result<void>> clear();
}
