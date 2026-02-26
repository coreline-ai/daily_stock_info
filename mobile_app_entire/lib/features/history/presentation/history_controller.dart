import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app_entire/app/bootstrap/providers.dart';
import 'package:mobile_app_entire/application/models/queries.dart';
import 'package:mobile_app_entire/domain/entities/backtest.dart';

class HistoryState {
  const HistoryState({required this.summary, required this.page});

  final BacktestSummary summary;
  final BacktestPage page;
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, HistoryState>(
      HistoryController.new,
    );

class HistoryController extends AsyncNotifier<HistoryState> {
  @override
  Future<HistoryState> build() async {
    return _load(page: 1);
  }

  Future<HistoryState> _load({required int page}) async {
    final summaryUsecase = ref.read(getBacktestSummaryUsecaseProvider);
    final historyUsecase = ref.read(getBacktestHistoryUsecaseProvider);

    final summaryResult = await summaryUsecase(
      const BacktestQuery(startDate: null, endDate: null),
    );
    final historyResult = await historyUsecase(
      BacktestHistoryQuery(
        startDate: null,
        endDate: null,
        page: page,
        size: 20,
      ),
    );

    final summary = summaryResult.when(
      success: (value) => value,
      failure: (failure) => throw Exception(failure.message),
    );
    final history = historyResult.when(
      success: (value) => value,
      failure: (failure) => throw Exception(failure.message),
    );

    return HistoryState(summary: summary, page: history);
  }

  Future<void> goToPage(int page) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(page: page));
  }

  Future<void> reload() async {
    final currentPage = state.valueOrNull?.page.page ?? 1;
    await goToPage(currentPage);
  }
}
