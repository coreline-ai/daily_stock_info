import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/features/analysis/presentation/analysis_controller.dart';
import 'package:mobile_app_entire/shared/widgets/error_banner.dart';
import 'package:mobile_app_entire/shared/widgets/loading_view.dart';

class AnalysisPage extends ConsumerWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValidation = ref.watch(analysisControllerProvider);
    final controller = ref.read(analysisControllerProvider.notifier);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: controller.reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text(
                  '전략 검증',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<StrategyKind>(
                  icon: const Icon(Icons.tune_rounded),
                  onSelected: controller.setStrategy,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: StrategyKind.premarket,
                      child: Text('장전 전략'),
                    ),
                    const PopupMenuItem(
                      value: StrategyKind.intraday,
                      child: Text('장중 전략'),
                    ),
                    const PopupMenuItem(
                      value: StrategyKind.close,
                      child: Text('종가 전략'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            asyncValidation.when(
              data: (validation) {
                return Column(
                  children: [
                    _metricCard(
                      context,
                      '게이트 상태',
                      _gateLabel(validation.gateStatus),
                    ),
                    _metricCard(
                      context,
                      '순 샤프지수',
                      validation.metrics.netSharpe.toStringAsFixed(3),
                    ),
                    _metricCard(
                      context,
                      'PBO',
                      validation.metrics.pbo.toStringAsFixed(3),
                    ),
                    _metricCard(
                      context,
                      'DSR',
                      validation.metrics.dsr.toStringAsFixed(3),
                    ),
                    _metricCard(
                      context,
                      '샘플 수',
                      validation.metrics.sampleSize.toString(),
                    ),
                    if (validation.insufficientData)
                      const ErrorBanner(
                        message: '데이터가 부족합니다. 샘플을 더 쌓은 뒤 다시 확인하세요.',
                      ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 280,
                child: LoadingView(message: '검증 데이터 로딩 중...'),
              ),
              error: (error, _) => ErrorBanner(message: error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  String _gateLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pass':
        return '통과';
      case 'warn':
        return '주의';
      case 'fail':
        return '실패';
      default:
        return status.toUpperCase();
    }
  }

  Widget _metricCard(BuildContext context, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
