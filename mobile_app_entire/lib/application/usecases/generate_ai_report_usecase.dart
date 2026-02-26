import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/domain/entities/ai_report.dart';
import 'package:mobile_app_entire/domain/repositories/ai_report_repository.dart';

class GenerateAiReportUsecase {
  const GenerateAiReportUsecase(this._repository);

  final AiReportRepository _repository;

  Future<Result<AiReport>> call(AiReportQuery query) {
    return _repository.generate(query);
  }
}
