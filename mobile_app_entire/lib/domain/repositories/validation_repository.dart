import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/domain/entities/validation.dart';

abstract interface class ValidationRepository {
  Future<Result<StrategyValidation>> run(ValidationQuery query);
}
