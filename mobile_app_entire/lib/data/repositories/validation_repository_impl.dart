import 'dart:math' as math;

import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/core/failure/app_failure.dart';
import 'package:mobile_app_entire/core/result/result.dart';
import 'package:mobile_app_entire/data/local/app_database.dart';
import 'package:mobile_app_entire/domain/entities/validation.dart';
import 'package:mobile_app_entire/domain/repositories/validation_repository.dart';
import 'package:mobile_app_entire/domain/services/validation_math_service.dart';

class ValidationRepositoryImpl implements ValidationRepository {
  const ValidationRepositoryImpl({
    required AppDatabase database,
    required ValidationMathService validationMathService,
  }) : _database = database,
       _validationMathService = validationMathService;

  final AppDatabase _database;
  final ValidationMathService _validationMathService;

  @override
  Future<Result<StrategyValidation>> run(ValidationQuery query) async {
    try {
      final rows = await _database.listAllBacktestRows(
        startDate: null,
        endDate: query.asOfDate,
      );
      final returns = rows
          .map((row) => row.retT1)
          .whereType<double>()
          .toList(growable: false);

      final insufficient = returns.length < 60;
      final netSharpe = _sharpe(returns);
      final maxDrawdown = returns.isEmpty ? 0 : returns.reduce(math.min);
      final hitRate = returns.isEmpty
          ? 0
          : (returns.where((e) => e > 0).length / returns.length) * 100;

      final trainSharpes = <double>[];
      final testSharpes = <double>[];
      if (returns.length >= 20) {
        for (var i = 0; i < 4; i++) {
          final split = ((returns.length * (0.55 + i * 0.08))).floor().clamp(
            5,
            returns.length - 2,
          );
          final train = returns.take(split).toList(growable: false);
          final test = returns.skip(split).toList(growable: false);
          trainSharpes.add(_sharpe(train));
          testSharpes.add(_sharpe(test));
        }
      }
      final pbo = _validationMathService.computePbo(trainSharpes, testSharpes);
      final dsr = _validationMathService.computeDsr(returns, trials: 4);
      final gateStatus = _validationMathService.gateStatus(
        pbo: pbo,
        dsr: dsr,
        netSharpe: netSharpe,
        sampleSize: returns.length,
      );

      return Success(
        StrategyValidation(
          strategy: query.strategy.name,
          asOfDate: query.asOfDate,
          gateStatus: gateStatus,
          gatePassed: gateStatus == 'pass',
          insufficientData: insufficient,
          validationPenalty: gateStatus == 'fail'
              ? 0.35
              : (gateStatus == 'warn' ? 0.15 : 0),
          metrics: ValidationMetrics(
            netSharpe: double.parse(netSharpe.toStringAsFixed(4)),
            maxDrawdown: double.parse(maxDrawdown.toStringAsFixed(4)),
            hitRate: double.parse(hitRate.toStringAsFixed(2)),
            turnover: 0,
            pbo: double.parse(pbo.toStringAsFixed(4)),
            dsr: double.parse(dsr.toStringAsFixed(4)),
            sampleSize: returns.length,
          ),
        ),
      );
    } catch (error) {
      return Failure(ComputeFailure('전략 검증 계산에 실패했습니다: $error'));
    }
  }

  double _sharpe(List<double> returns) {
    if (returns.length < 2) {
      return 0;
    }
    final mean = returns.reduce((a, b) => a + b) / returns.length;
    final variance =
        returns
            .map((v) => math.pow(v - mean, 2))
            .fold<double>(0, (acc, v) => acc + v) /
        (returns.length - 1);
    final std = math.sqrt(variance);
    if (std == 0) {
      return 0;
    }
    return mean / std * math.sqrt(252);
  }
}
