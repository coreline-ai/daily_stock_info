import 'package:coreline_stock_ai/core/util/date_kst.dart';
import 'package:coreline_stock_ai/features/analysis/presentation/providers/analysis_providers.dart';
import 'package:coreline_stock_ai/features/dashboard/domain/entities/dashboard_models.dart';
import 'package:coreline_stock_ai/shared/widgets/error_banner.dart';
import 'package:coreline_stock_ai/shared/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analysisControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisControllerProvider);
    final controller = ref.read(analysisControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Strategy Validation'),
        actions: [
          IconButton(
            onPressed: controller.load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final strategy in StrategyKind.values)
                          ChoiceChip(
                            label: Text(_strategyLabel(strategy)),
                            selected: state.strategy == strategy,
                            onSelected: (_) => controller.setStrategy(strategy),
                          ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(context, state.date),
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(DateKst.toDisplay(state.date)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.error != null && state.error!.isNotEmpty) ErrorBanner(message: state.error!),
              if (state.loading && state.validation == null)
                const SizedBox(height: 240, child: LoadingView(label: '검증 데이터 로딩 중...'))
              else if (state.validation != null)
                _ValidationView(validation: state.validation!),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, String date) async {
    final controller = ref.read(analysisControllerProvider.notifier);
    final selected = DateTime.tryParse(date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 2)),
      initialDate: selected,
    );
    if (picked != null) {
      await controller.setDate(picked);
    }
  }

  String _strategyLabel(StrategyKind strategy) {
    switch (strategy) {
      case StrategyKind.premarket:
        return '장전';
      case StrategyKind.intraday:
        return '장중';
      case StrategyKind.close:
        return '종가';
    }
  }
}

class _ValidationView extends StatelessWidget {
  const _ValidationView({required this.validation});

  final StrategyValidation validation;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (validation.gateStatus) {
      'pass' => Colors.green,
      'fail' => Colors.red,
      _ => Colors.orange,
    };

    Widget metricCard(String label, String value) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('게이트 상태', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(
                validation.gateStatus.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.55,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            metricCard('Net Sharpe', validation.netSharpe.toStringAsFixed(2)),
            metricCard('PBO', validation.pbo.toStringAsFixed(3)),
            metricCard('DSR', validation.dsr.toStringAsFixed(3)),
            metricCard('Sample Size', validation.sampleSize.toString()),
          ],
        ),
        if (validation.intradaySignalBranch != null && validation.intradaySignalBranch!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Intraday Branch: ${validation.intradaySignalBranch}'),
        ],
        if (validation.alerts.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            validation.alerts.join(' / '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange[700]),
          ),
        ],
      ],
    );
  }
}
