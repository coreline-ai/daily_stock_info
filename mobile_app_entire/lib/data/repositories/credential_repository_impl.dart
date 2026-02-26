import 'package:mobile_app_entire/core/failure/app_failure.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/data/secure/credential_store.dart';
import 'package:mobile_app_entire/domain/repositories/credential_repository.dart';

class CredentialRepositoryImpl implements CredentialRepository {
  const CredentialRepositoryImpl(this._store);

  final CredentialStore _store;

  @override
  Future<Result<void>> clear() async {
    try {
      await _store.clear();
      return const Success(null);
    } catch (error) {
      return Failure(StorageFailure('API 키 초기화에 실패했습니다: $error'));
    }
  }

  @override
  Future<Result<ApiCredentials>> load() async {
    try {
      final credentials = await _store.load();
      return Success(credentials);
    } catch (error) {
      return Failure(StorageFailure('API 키 로드에 실패했습니다: $error'));
    }
  }

  @override
  Future<Result<void>> save(ApiCredentials credentials) async {
    try {
      await _store.save(credentials);
      return const Success(null);
    } catch (error) {
      return Failure(StorageFailure('API 키 저장에 실패했습니다: $error'));
    }
  }
}
