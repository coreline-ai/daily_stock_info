import 'package:coreline_stock_ai/core/util/date_kst.dart';
import 'package:coreline_stock_ai/features/history/domain/entities/history_models.dart';
import 'package:coreline_stock_ai/features/history/presentation/providers/history_providers.dart';
import 'package:coreline_stock_ai/shared/widgets/error_banner.dart';
import 'package:coreline_stock_ai/shared/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  late final TextEditingController _feeController;
  late final TextEditingController _slippageController;

  @override
  void initState() {
    super.initState();
    _feeController = TextEditingController(text: '10');
    _slippageController = TextEditingController(text: '5');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _feeController.dispose();
    _slippageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backtest History'),
        actions: [
          IconButton(onPressed: controller.load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(isStart: true),
                          icon: const Icon(Icons.date_range_rounded, size: 16),
                          label: Text(state.startDate == null ? '시작일' : DateKst.toDisplay(state.startDate!)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(isStart: false),
                          icon: const Icon(Icons.date_range_rounded, size: 16),
                          label: Text(state.endDate == null ? '종료일' : DateKst.toDisplay(state.endDate!)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _feeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Fee (bps)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _slippageController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Slippage (bps)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _applyCosts, child: const Text('적용')),
                    ],
                  ),
                ],
              ),
            ),
            if (state.error != null && state.error!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ErrorBanner(message: _normalizeError(state.error!)),
              ),
            Expanded(
              child: state.loading && state.history == null
                  ? const LoadingView(label: '히스토리 로딩 중...')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                      children: [
                        if (state.summary != null) _SummarySection(summary: state.summary!),
                        const SizedBox(height: 12),
                        _HistorySection(history: state.history),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton.icon(
                              onPressed: state.loading ? null : controller.prevPage,
                              icon: const Icon(Icons.chevron_left_rounded),
                              label: const Text('이전'),
                            ),
                            Text(
                              'Page ${state.history?.page ?? state.page}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            OutlinedButton.icon(
                              onPressed: state.loading ? null : controller.nextPage,
                              icon: const Icon(Icons.chevron_right_rounded),
                              label: const Text('다음'),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final state = ref.read(historyControllerProvider);
    final initial = DateTime.tryParse(isStart ? (state.startDate ?? DateKst.todayIso()) : (state.endDate ?? DateKst.todayIso())) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 2)),
      initialDate: initial,
    );
    if (picked == null) {
      return;
    }

    final iso = picked.toIso8601String().split('T').first;
    final controller = ref.read(historyControllerProvider.notifier);
    if (isStart) {
      await controller.setStartDate(iso);
    } else {
      await controller.setEndDate(iso);
    }
  }

  Future<void> _applyCosts() async {
    final fee = double.tryParse(_feeController.text.trim()) ?? 10;
    final slippage = double.tryParse(_slippageController.text.trim()) ?? 5;
    await ref.read(historyControllerProvider.notifier).setCosts(feeBps: fee, slippageBps: slippage);
  }

  String _normalizeError(String raw) {
    if (raw.contains('DATABASE_URL')) {
      return '데이터베이스가 설정되지 않아 백테스트 히스토리를 사용할 수 없습니다. 서버의 DATABASE_URL 설정 후 다시 시도하세요.';
    }
    return raw;
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});

  final BacktestSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final metric = summary.metrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Summary (${summary.count})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.45,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _metricCard(context, 'Avg Net T1', metric['avgNetRetT1'] ?? 0),
            _metricCard(context, 'Avg Net T3', metric['avgNetRetT3'] ?? 0),
            _metricCard(context, 'Avg Net T5', metric['avgNetRetT5'] ?? 0),
            _metricCard(context, 'Net Win T1', metric['netWinRateT1'] ?? 0),
          ],
        ),
      ],
    );
  }

  Widget _metricCard(BuildContext context, String label, double value) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text('${value.toStringAsFixed(2)}%', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.history});

  final BacktestHistoryPage? history;

  @override
  Widget build(BuildContext context) {
    if (history == null) {
      return const SizedBox.shrink();
    }
    if (history!.items.isEmpty) {
      return const Text('조건에 맞는 히스토리가 없습니다.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Records', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final item in history!.items) ...[
          _HistoryItemCard(item: item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({required this.item});

  final BacktestHistoryItemModel item;

  @override
  Widget build(BuildContext context) {
    final currentDisplay = item.currentPrice ?? item.dayClose ?? item.entryPrice;
    final currentDate = item.currentPriceDate ?? item.tradeDate;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.companyName} (${item.ticker})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(item.tradeDate, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                Text('시가 ${_fmt(item.dayOpen ?? item.entryPrice)}'),
                Text('종가 ${_fmt(item.dayClose ?? item.entryPrice)}'),
                Text('현재가 ${_fmt(currentDisplay)} ($currentDate)'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                Text('T1 ${_pct(item.retT1)} / net ${_pct(item.netRetT1)}'),
                Text('T3 ${_pct(item.retT3)} / net ${_pct(item.netRetT3)}'),
                Text('T5 ${_pct(item.retT5)} / net ${_pct(item.netRetT5)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  String _pct(double? value) {
    if (value == null) {
      return '-';
    }
    return '${value.toStringAsFixed(2)}%';
  }
}
