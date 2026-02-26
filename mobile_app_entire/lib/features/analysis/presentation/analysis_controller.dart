import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app_entire/app/bootstrap/providers.dart';
import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/domain/entities/validation.dart';
import 'package:mobile_app_entire/features/dashboard/presentation/dashboard_controller.dart';

final analysisControllerProvider =
    AsyncNotifierProvider<AnalysisController, StrategyValidation>(
      AnalysisController.new,
    );

class AnalysisController extends AsyncNotifier<StrategyValidation> {
  @override
  Future<StrategyValidation> build() async {
    return _load();
  }

  Future<StrategyValidation> _load() async {
    final query = ref.read(dashboardQueryProvider);
    final usecase = ref.read(runValidationUsecaseProvider);
    final result = await usecase(
      ValidationQuery(
        strategy: query.strategy,
        asOfDate: query.date,
        weights: query.weights,
        customTickers: query.customTickers,
      ),
    );

    return result.when(
      success: (data) => data,
      failure: (failure) => throw Exception(failure.message),
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> setStrategy(StrategyKind strategy) async {
    await ref.read(dashboardControllerProvider.notifier).setStrategy(strategy);
    await reload();
  }
}
