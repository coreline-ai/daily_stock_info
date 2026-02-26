import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app_entire/app/bootstrap/providers.dart';
import 'package:mobile_app_entire/domain/repositories/credential_repository.dart';

class SettingsState {
  const SettingsState({
    required this.credentials,
    required this.loading,
    this.message,
    this.error,
  });

  final ApiCredentials credentials;
  final bool loading;
  final String? message;
  final String? error;

  factory SettingsState.initial() =>
      const SettingsState(credentials: ApiCredentials.empty, loading: false);

  SettingsState copyWith({
    ApiCredentials? credentials,
    bool? loading,
    String? message,
    String? error,
  }) {
    return SettingsState(
      credentials: credentials ?? this.credentials,
      loading: loading ?? this.loading,
      message: message,
      error: error,
    );
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>(
      SettingsController.new,
    );

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._ref) : super(SettingsState.initial()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, message: null, error: null);
    final repo = _ref.read(credentialRepositoryProvider);
    final result = await repo.load();
    state = result.when(
      success: (credentials) =>
          state.copyWith(credentials: credentials, loading: false),
      failure: (failure) =>
          state.copyWith(loading: false, error: failure.message),
    );
  }

  Future<void> save(ApiCredentials credentials) async {
    state = state.copyWith(loading: true, message: null, error: null);
    final repo = _ref.read(credentialRepositoryProvider);
    final result = await repo.save(credentials);
    state = result.when(
      success: (_) => state.copyWith(
        credentials: credentials,
        loading: false,
        message: '저장되었습니다.',
      ),
      failure: (failure) =>
          state.copyWith(loading: false, error: failure.message),
    );
  }

  Future<void> clear() async {
    state = state.copyWith(loading: true, message: null, error: null);
    final repo = _ref.read(credentialRepositoryProvider);
    final result = await repo.clear();
    state = result.when(
      success: (_) => state.copyWith(
        loading: false,
        credentials: ApiCredentials.empty,
        message: '초기화되었습니다.',
      ),
      failure: (failure) =>
          state.copyWith(loading: false, error: failure.message),
    );
  }

  void setThemeMode(ThemeMode mode) {
    _ref.read(themeModeProvider.notifier).state = mode;
  }
}
