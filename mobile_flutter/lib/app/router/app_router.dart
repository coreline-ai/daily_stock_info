import 'package:coreline_stock_ai/features/analysis/presentation/analysis_page.dart';
import 'package:coreline_stock_ai/features/dashboard/presentation/home_page.dart';
import 'package:coreline_stock_ai/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:coreline_stock_ai/features/history/presentation/history_page.dart';
import 'package:coreline_stock_ai/features/settings/presentation/settings_page.dart';
import 'package:coreline_stock_ai/features/watchlist/presentation/watchlist_page.dart';
import 'package:coreline_stock_ai/shared/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      ShellRoute(
        builder: (context, state, child) {
          final index = _indexOfLocation(state.uri.path);
          return AppShell(
            currentIndex: index,
            onTap: (next) {
              final target = _locationFromIndex(next);
              if (target != null && target != state.uri.path) {
                context.go(target);
              }
            },
            onQuickAction: () => _openQuickActions(
              context,
              onRefresh: () => ref.read(dashboardControllerProvider.notifier).manualRefresh(),
            ),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: '/analysis',
            pageBuilder: (context, state) => const NoTransitionPage(child: AnalysisPage()),
          ),
          GoRoute(
            path: '/watchlist',
            pageBuilder: (context, state) => const NoTransitionPage(child: WatchlistPage()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(child: SettingsPage()),
          ),
        ],
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryPage(),
      ),
    ],
  );
});

int _indexOfLocation(String location) {
  if (location.startsWith('/analysis')) {
    return 1;
  }
  if (location.startsWith('/watchlist')) {
    return 2;
  }
  if (location.startsWith('/settings')) {
    return 3;
  }
  return 0;
}

String? _locationFromIndex(int index) {
  switch (index) {
    case 0:
      return '/home';
    case 1:
      return '/analysis';
    case 2:
      return '/watchlist';
    case 3:
      return '/settings';
    default:
      return null;
  }
}

Future<void> _openQuickActions(
  BuildContext context, {
  required Future<void> Function() onRefresh,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final actions = [
        ('refresh', '데이터 새로고침', Icons.refresh_rounded, '/home'),
        ('analysis', '전략 검증 보기', Icons.fact_check_rounded, '/analysis'),
        ('history', '백테스트 히스토리', Icons.history_rounded, '/history'),
        ('watchlist', '워치리스트 추가', Icons.playlist_add_rounded, '/watchlist'),
      ];
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              ListTile(
                leading: Icon(action.$3),
                title: Text(action.$2),
                onTap: () async {
                  Navigator.of(context).pop();
                  if (action.$1 == 'refresh') {
                    context.go('/home');
                    await onRefresh();
                    return;
                  }
                  context.go(action.$4);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
