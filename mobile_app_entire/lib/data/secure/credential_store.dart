import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app_entire/domain/repositories/credential_repository.dart';

class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _twelveDataKey = 'credential.twelvedata.key';
  static const _finnhubKey = 'credential.finnhub.key';
  static const _glmKey = 'credential.glm.key';
  static const _glmBaseUrl = 'credential.glm.baseurl';

  Future<ApiCredentials> load() async {
    final twelve =
        await _storage.read(key: _twelveDataKey) ??
        ApiCredentials.empty.twelveDataKey;
    final finnhub =
        await _storage.read(key: _finnhubKey) ??
        ApiCredentials.empty.finnhubKey;
    final glm =
        await _storage.read(key: _glmKey) ?? ApiCredentials.empty.glmKey;
    final baseUrl =
        await _storage.read(key: _glmBaseUrl) ??
        ApiCredentials.empty.glmBaseUrl;

    return ApiCredentials(
      twelveDataKey: twelve,
      finnhubKey: finnhub,
      glmKey: glm,
      glmBaseUrl: baseUrl,
    );
  }

  Future<void> save(ApiCredentials credentials) async {
    await _storage.write(key: _twelveDataKey, value: credentials.twelveDataKey);
    await _storage.write(key: _finnhubKey, value: credentials.finnhubKey);
    await _storage.write(key: _glmKey, value: credentials.glmKey);
    await _storage.write(key: _glmBaseUrl, value: credentials.glmBaseUrl);
  }

  Future<void> clear() async {
    await _storage.delete(key: _twelveDataKey);
    await _storage.delete(key: _finnhubKey);
    await _storage.delete(key: _glmKey);
    await _storage.delete(key: _glmBaseUrl);
  }
}
