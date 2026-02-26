import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app_entire/features/history/presentation/history_controller.dart';
import 'package:mobile_app_entire/shared/utils/stock_localization.dart';
import 'package:mobile_app_entire/shared/widgets/error_banner.dart';
import 'package:mobile_app_entire/shared/widgets/loading_view.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: controller.reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '백테스트 히스토리',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            asyncState.when(
              data: (data) {
                final summary = data.summary;
                final page = data.page;
                final maxPage = (page.total / page.size).ceil().clamp(1, 9999);

                return Column(
                  children: [
                    _summary(
                      context,
                      '평균 T+1',
                      '${summary.avgRetT1.toStringAsFixed(2)}%',
                    ),
                    _summary(
                      context,
                      '평균 T+3',
                      '${summary.avgRetT3.toStringAsFixed(2)}%',
                    ),
                    _summary(
                      context,
                      '평균 T+5',
                      '${summary.avgRetT5.toStringAsFixed(2)}%',
                    ),
                    _summary(
                      context,
                      '승률 T+1',
                      '${summary.winRateT1.toStringAsFixed(2)}%',
                    ),
                    const SizedBox(height: 8),
                    if (page.items.isEmpty)
                      const Text('백테스트 행이 없습니다. 홈에서 데이터 새로고침 후 다시 확인하세요.')
                    else
                      ...page.items.map((item) {
                        final companyName = localizeCompanyName(
                          item.companyName,
                          item.ticker,
                        );
                        return Card(
                          child: ListTile(
                            title: Text('$companyName (${item.ticker})'),
                            subtitle: Text(item.tradeDate),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'T+1 ${item.retT1?.toStringAsFixed(2) ?? '-'}%',
                                ),
                                Text(
                                  'T+5 ${item.retT5?.toStringAsFixed(2) ?? '-'}%',
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: page.page > 1
                              ? () => controller.goToPage(page.page - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Text('${page.page} / $maxPage'),
                        IconButton(
                          onPressed: page.page < maxPage
                              ? () => controller.goToPage(page.page + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 260,
                child: LoadingView(message: '히스토리 로딩 중...'),
              ),
              error: (error, _) => ErrorBanner(message: error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
