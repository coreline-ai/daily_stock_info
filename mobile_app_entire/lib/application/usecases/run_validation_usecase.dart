import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/domain/entities/validation.dart';
import 'package:mobile_app_entire/domain/repositories/validation_repository.dart';

class RunValidationUsecase {
  const RunValidationUsecase(this._repository);

  final ValidationRepository _repository;

  Future<Result<StrategyValidation>> call(ValidationQuery query) {
    return _repository.run(query);
  }
}
