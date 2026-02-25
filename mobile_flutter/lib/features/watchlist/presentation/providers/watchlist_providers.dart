import 'package:coreline_stock_ai/core/network/dio_client.dart';
import 'package:coreline_stock_ai/features/watchlist/data/repository_impl/watchlist_repository_impl.dart';
import 'package:coreline_stock_ai/features/watchlist/domain/repository/watchlist_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WatchlistState {
  const WatchlistState({
    required this.loading,
    required this.tickers,
    required this.error,
    required this.notice,
    required this.replaceMode,
  });

  factory WatchlistState.initial() => const WatchlistState(
        loading: false,
        tickers: [],
        error: null,
        notice: null,
        replaceMode: false,
      );

  final bool loading;
  final List<String> tickers;
  final String? error;
  final String? notice;
  final bool replaceMode;

  static const _sentinel = Object();

  WatchlistState copyWith({
    bool? loading,
    List<String>? tickers,
    Object? error = _sentinel,
    Object? notice = _sentinel,
    bool? replaceMode,
  }) {
    return WatchlistState(
      loading: loading ?? this.loading,
      tickers: tickers ?? this.tickers,
      error: error == _sentinel ? this.error : error as String?,
      notice: notice == _sentinel ? this.notice : notice as String?,
      replaceMode: replaceMode ?? this.replaceMode,
    );
  }
}

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return WatchlistRepositoryImpl(dio: dio);
});

final watchlistControllerProvider = StateNotifierProvider<WatchlistController, WatchlistState>((ref) {
  final repository = ref.watch(watchlistRepositoryProvider);
  return WatchlistController(repository);
});

class WatchlistController extends StateNotifier<WatchlistState> {
  WatchlistController(this._repository) : super(WatchlistState.initial());

  final WatchlistRepository _repository;
  CancelToken? _token;

  Future<void> load() async {
    _token?.cancel();
    final token = CancelToken();
    _token = token;
    state = state.copyWith(loading: true, error: null, notice: null);

    try {
      final tickers = await _repository.getWatchlist(cancelToken: token);
      state = state.copyWith(loading: false, tickers: tickers, error: null);
    } catch (error) {
      if (error is DioException && (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel)) {
        return;
      }
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> addTicker(String ticker) async {
    final normalized = ticker.trim().toUpperCase();
    if (normalized.isEmpty) {
      return;
    }
    state = state.copyWith(loading: true, error: null, notice: null);
    try {
      final tickers = await _repository.addTickers(tickers: [normalized]);
      state = state.copyWith(
        loading: false,
        tickers: tickers,
        notice: '$normalized 추가 완료',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> deleteTicker(String ticker) async {
    state = state.copyWith(loading: true, error: null, notice: null);
    try {
      final tickers = await _repository.removeTicker(ticker: ticker);
      state = state.copyWith(
        loading: false,
        tickers: tickers,
        notice: '$ticker 삭제 완료',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  void setReplaceMode(bool value) {
    state = state.copyWith(replaceMode: value);
  }

  Future<void> uploadCsv({
    required List<int> bytes,
    required String filename,
  }) async {
    state = state.copyWith(loading: true, error: null, notice: null);
    try {
      final result = await _repository.uploadCsv(
        bytes: bytes,
        filename: filename,
        replace: state.replaceMode,
      );
      state = state.copyWith(
        loading: false,
        tickers: result.tickers,
        notice:
            'CSV 업로드 완료 (${result.uploadedCount}개, invalid ${result.invalidRows.length}개, mode: ${result.mode})',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  @override
  void dispose() {
    _token?.cancel();
    super.dispose();
  }
}
