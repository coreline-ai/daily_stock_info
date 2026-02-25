import 'package:coreline_stock_ai/app/theme/app_colors.dart';
import 'package:coreline_stock_ai/core/util/date_kst.dart';
import 'package:coreline_stock_ai/features/dashboard/domain/entities/dashboard_models.dart';
import 'package:coreline_stock_ai/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:coreline_stock_ai/features/dashboard/presentation/widgets/candidate_card.dart';
import 'package:coreline_stock_ai/shared/widgets/error_banner.dart';
import 'package:coreline_stock_ai/shared/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final TextEditingController _searchController;
  late final TextEditingController _customTickerController;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _customTickerController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardControllerProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customTickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final candidates = state.filteredCandidates();
    final visibleCandidates = _showAll ? candidates : candidates.take(5).toList(growable: false);

    return RefreshIndicator(
      onRefresh: controller.manualRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              selectedDateIso: state.selectedDateIso,
              onDatePressed: () => _pickDate(context, state.selectedDateIso),
              searchController: _searchController,
              onSearchChanged: controller.setSearchQuery,
            ),
            const SizedBox(height: 16),
            _StrategySection(
              state: state,
              onPresetChanged: controller.setPreset,
              onStrategyChanged: controller.setStrategy,
              onIntradayExtraChanged: controller.setShowIntradayExtra,
            ),
            const SizedBox(height: 12),
            _CustomTickerSection(
              controller: _customTickerController,
              onApply: () {
                controller.setCustomTickerInput(_customTickerController.text);
                controller.applyCustomTickers();
              },
              onManualRefresh: controller.manualRefresh,
            ),
            if (state.lastTriggerIso != null) ...[
              const SizedBox(height: 12),
              Text(
                '마지막 입력 트리거: ${_formatTrigger(state.lastTriggerIso!)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (state.isFromCache) ...[
              const SizedBox(height: 8),
              const ErrorBanner(message: '네트워크 오류로 캐시 데이터를 표시 중입니다.'),
            ],
            if (state.warning != null && state.warning!.isNotEmpty) ...[
              const SizedBox(height: 8),
              ErrorBanner(message: state.warning!),
            ],
            if (state.error != null && state.error!.isNotEmpty) ...[
              const SizedBox(height: 8),
              ErrorBanner(message: state.error!),
            ],
            const SizedBox(height: 20),
            _OverviewSection(overview: state.marketOverview),
            const SizedBox(height: 20),
            _TopPicksHeader(
              count: candidates.length,
              showAll: _showAll,
              onToggle: () => setState(() => _showAll = !_showAll),
            ),
            const SizedBox(height: 10),
            if (state.isLoading && candidates.isEmpty)
              const SizedBox(height: 220, child: LoadingView())
            else if (visibleCandidates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Text('추천 결과가 없습니다. 전략/날짜/티커 조건을 확인해주세요.'),
              )
            else
              Column(
                children: [
                  for (final candidate in visibleCandidates) ...[
                    CandidateCard(
                      candidate: candidate,
                      expanded: state.expandedTickers.contains(candidate.code),
                      detail: state.stockDetails[candidate.code],
                      loadingDetail: state.detailLoadingTickers.contains(candidate.code),
                      onToggle: () => controller.toggleExpanded(candidate.code),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            if (state.showIntradayExtra && state.intradayExtraCandidates.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                '장중 단타 추가 추천',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final candidate in state.intradayExtraCandidates.take(5)) ...[
                CandidateCard(
                  candidate: candidate,
                  expanded: state.expandedTickers.contains(candidate.code),
                  detail: state.stockDetails[candidate.code],
                  loadingDetail: state.detailLoadingTickers.contains(candidate.code),
                  onToggle: () => controller.toggleExpanded(candidate.code),
                ),
                const SizedBox(height: 12),
              ],
            ],
            if (state.validation != null) ...[
              const SizedBox(height: 12),
              _ValidationSection(validation: state.validation!),
            ],
            if (state.marketInsight != null) ...[
              const SizedBox(height: 12),
              _InsightSection(insight: state.marketInsight!),
            ],
            const SizedBox(height: 16),
            _ProBanner(onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, String selectedIso) async {
    final controller = ref.read(dashboardControllerProvider.notifier);
    final parsed = DateTime.tryParse(selectedIso) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 2)),
      initialDate: parsed,
    );
    if (picked != null) {
      await controller.setDate(picked);
    }
  }

  String _formatTrigger(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('yyyy.MM.dd HH:mm:ss').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.selectedDateIso,
    required this.onDatePressed,
    required this.searchController,
    required this.onSearchChanged,
  });

  final String selectedDateIso;
  final VoidCallback onDatePressed;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)]),
              ),
              child: const Icon(Icons.ssid_chart_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Coreline ',
                  children: [
                    TextSpan(
                      text: 'Stock AI',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
            const CircleAvatar(radius: 15, child: Icon(Icons.person_outline_rounded, size: 16)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search ticker or company...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onDatePressed,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(DateKst.toDisplay(selectedDateIso)),
            ),
          ],
        ),
      ],
    );
  }
}

class _StrategySection extends StatelessWidget {
  const _StrategySection({
    required this.state,
    required this.onPresetChanged,
    required this.onStrategyChanged,
    required this.onIntradayExtraChanged,
  });

  final DashboardState state;
  final ValueChanged<StrategyPreset> onPresetChanged;
  final ValueChanged<StrategyKind> onStrategyChanged;
  final ValueChanged<bool> onIntradayExtraChanged;

  @override
  Widget build(BuildContext context) {
    final presetLabels = {
      StrategyPreset.balanced: 'Balanced',
      StrategyPreset.aggressive: 'Aggressive',
      StrategyPreset.defensive: 'Defensive',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Strategy Weighting', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('Auto-rebalance enabled', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<StrategyPreset>(
          showSelectedIcon: false,
          segments: presetLabels.entries
              .map((entry) => ButtonSegment<StrategyPreset>(value: entry.key, label: Text(entry.value)))
              .toList(growable: false),
          selected: {state.preset},
          onSelectionChanged: (selected) {
            if (selected.isNotEmpty) {
              onPresetChanged(selected.first);
            }
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Text('Profit ${state.weights.returnWeight.toStringAsFixed(2)}', style: Theme.of(context).textTheme.labelSmall)),
            Expanded(child: Text('Stable ${state.weights.stabilityWeight.toStringAsFixed(2)}', style: Theme.of(context).textTheme.labelSmall)),
            Expanded(child: Text('Growth ${state.weights.marketWeight.toStringAsFixed(2)}', style: Theme.of(context).textTheme.labelSmall)),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 8,
          child: Row(
            children: [
              Expanded(flex: (state.weights.returnWeight * 100).round(), child: Container(color: Colors.blue)),
              Expanded(flex: (state.weights.stabilityWeight * 100).round(), child: Container(color: Colors.indigo)),
              Expanded(flex: (state.weights.marketWeight * 100).round(), child: Container(color: Colors.purple)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in StrategyKind.values)
              FilledButton.tonal(
                onPressed: () => onStrategyChanged(item),
                style: FilledButton.styleFrom(
                  backgroundColor: state.selectedStrategy == item ? AppColors.primary.withValues(alpha: 0.15) : null,
                ),
                child: Text(_strategyLabel(item)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('장중 단타 추가 추천 표시'),
          value: state.showIntradayExtra,
          onChanged: onIntradayExtraChanged,
        ),
      ],
    );
  }

  String _strategyLabel(StrategyKind kind) {
    switch (kind) {
      case StrategyKind.premarket:
        return '장전 전략';
      case StrategyKind.intraday:
        return '장중 단타';
      case StrategyKind.close:
        return '종가 전략';
    }
  }
}

class _CustomTickerSection extends StatelessWidget {
  const _CustomTickerSection({
    required this.controller,
    required this.onApply,
    required this.onManualRefresh,
  });

  final TextEditingController controller;
  final VoidCallback onApply;
  final VoidCallback onManualRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '커스텀 티커 입력 (예: 005930,000660)',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: onApply, child: const Text('적용')),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          onPressed: onManualRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('새로고침'),
        ),
      ],
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.overview});

  final MarketOverview? overview;

  @override
  Widget build(BuildContext context) {
    if (overview == null) {
      return const SizedBox(height: 120, child: LoadingView(label: '시장 개요 로딩 중...'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Market Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _OverviewCell(label: 'Decline', value: overview!.down, color: AppColors.accentRed)),
            const SizedBox(width: 8),
            Expanded(child: _OverviewCell(label: 'Neutral', value: overview!.steady, color: Colors.grey)),
            const SizedBox(width: 8),
            Expanded(child: _OverviewCell(label: 'Growth', value: overview!.up, color: AppColors.accentGreen)),
          ],
        ),
      ],
    );
  }
}

class _OverviewCell extends StatelessWidget {
  const _OverviewCell({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _TopPicksHeader extends StatelessWidget {
  const _TopPicksHeader({
    required this.count,
    required this.showAll,
    required this.onToggle,
  });

  final int count;
  final bool showAll;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Top Picks',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 6),
        Text('TOP5 Strategy', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary)),
        const Spacer(),
        TextButton(
          onPressed: onToggle,
          child: Text(showAll ? '상위만 보기' : '전체 $count개'),
        ),
      ],
    );
  }
}

class _ValidationSection extends StatelessWidget {
  const _ValidationSection({required this.validation});

  final StrategyValidation validation;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('전략 검증 요약', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Gate ${validation.gateStatus.toUpperCase()} | Sharpe ${validation.netSharpe.toStringAsFixed(2)} | PBO ${validation.pbo.toStringAsFixed(2)} | DSR ${validation.dsr.toStringAsFixed(2)}'),
            if (validation.alerts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(validation.alerts.join(' / '), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({required this.insight});

  final MarketInsight insight;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Market Insight', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(insight.conclusion, style: Theme.of(context).textTheme.bodyMedium),
            if (insight.riskFactors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('리스크: ${insight.riskFactors.join(' / ')}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProBanner extends StatelessWidget {
  const _ProBanner({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF2563EB)]),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upgrade to Pro', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Unlock advanced AI predictions and unlimited backtests.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }
}
