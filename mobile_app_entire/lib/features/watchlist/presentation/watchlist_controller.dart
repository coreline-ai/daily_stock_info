import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app_entire/app/bootstrap/providers.dart';
import 'package:mobile_app_entire/domain/entities/watchlist.dart';

class WatchlistState {
  const WatchlistState({
    required this.items,
    required this.loading,
    this.error,
  });

  final List<WatchlistEntry> items;
  final bool loading;
  final String? error;

  factory WatchlistState.initial() =>
      const WatchlistState(items: [], loading: false);

  WatchlistState copyWith({
    List<WatchlistEntry>? items,
    bool? loading,
    String? error,
  }) {
    return WatchlistState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

final watchlistControllerProvider =
    StateNotifierProvider<WatchlistController, WatchlistState>(
      WatchlistController.new,
    );

class WatchlistController extends StateNotifier<WatchlistState> {
  WatchlistController(this._ref) : super(WatchlistState.initial()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    final repo = _ref.read(watchlistRepositoryProvider);
    final result = await repo.getAll();
    state = result.when(
      success: (items) => state.copyWith(items: items, loading: false),
      failure: (failure) =>
          state.copyWith(loading: false, error: failure.message),
    );
  }

  Future<void> add(String ticker) async {
    state = state.copyWith(loading: true, error: null);
    final repo = _ref.read(watchlistRepositoryProvider);
    final result = await repo.addTicker(ticker);
    state = result.when(
      success: (items) => state.copyWith(items: items, loading: false),
      failure: (failure) =>
          state.copyWith(loading: false, error: failure.message),
    );
  }

  Future<void> remove(String ticker) async {
    state = state.copyWith(loading: true, error: null);
    final repo = _ref.read(watchlistRepositoryProvider);
    final result = await repo.removeTicker(ticker);
    state = result.when(
      success: (items) => state.copyWith(items: items, loading: false),
      failure: (failure) =>
          state.copyWith(loading: false, error: failure.message),
    );
  }

  Future<void> importCsv(String csvRaw) async {
    state = state.copyWith(loading: true, error: null);
    final repo = _ref.read(watchlistRepositoryProvider);
    final result = await repo.replaceFromCsv(csvRaw);
    state = result.when(
      success: (items) => state.copyWith(items: items, loading: false),
      failure: (failure) =>
          state.copyWith(loading: false, error: failure.message),
    );
  }
}
