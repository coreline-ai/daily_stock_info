import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/domain/entities/ai_report.dart';

abstract interface class AiReportRepository {
  Future<Result<AiReport>> generate(AiReportQuery query);
}
