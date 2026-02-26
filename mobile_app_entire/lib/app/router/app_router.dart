import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app_entire/features/analysis/presentation/analysis_page.dart';
import 'package:mobile_app_entire/features/dashboard/presentation/dashboard_page.dart';
import 'package:mobile_app_entire/features/history/presentation/history_page.dart';
import 'package:mobile_app_entire/features/settings/presentation/settings_page.dart';
import 'package:mobile_app_entire/features/watchlist/presentation/watchlist_page.dart';
import 'package:mobile_app_entire/shared/widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    errorPageBuilder: (context, state) => NoTransitionPage(
      child: _RouterErrorPage(error: state.error?.toString()),
    ),
    routes: [
      GoRoute(path: '/', redirect: (_, state) => '/home'),
      ShellRoute(
        builder: (context, state, child) {
          final index = _indexOf(state.uri.path);
          return AppShell(
            currentIndex: index,
            onTap: (next) {
              final target = _pathFromIndex(next);
              if (target != null && target != state.uri.path) {
                context.go(target);
              }
            },
            onFab: () => context.go('/history'),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardPage()),
          ),
          GoRoute(
            path: '/analysis',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AnalysisPage()),
          ),
          GoRoute(
            path: '/watchlist',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: WatchlistPage()),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HistoryPage()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsPage()),
          ),
        ],
      ),
    ],
  );
});

class _RouterErrorPage extends StatelessWidget {
  const _RouterErrorPage({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '화면 경로를 찾을 수 없습니다.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(error ?? '라우팅 오류가 발생했습니다.', textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('홈으로 이동'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int _indexOf(String path) {
  if (path.startsWith('/analysis')) {
    return 1;
  }
  if (path.startsWith('/watchlist')) {
    return 2;
  }
  if (path.startsWith('/settings')) {
    return 4;
  }
  return 0;
}

String? _pathFromIndex(int index) {
  switch (index) {
    case 0:
      return '/home';
    case 1:
      return '/analysis';
    case 2:
      return '/watchlist';
    case 4:
      return '/settings';
    default:
      return null;
  }
}
