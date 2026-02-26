import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app_entire/domain/entities/dashboard.dart';
import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/features/dashboard/presentation/dashboard_controller.dart';
import 'package:mobile_app_entire/shared/design_tokens/app_colors.dart';
import 'package:mobile_app_entire/shared/widgets/error_banner.dart';
import 'package:mobile_app_entire/shared/widgets/loading_view.dart';
import 'package:mobile_app_entire/shared/widgets/pro_banner.dart';
import 'package:mobile_app_entire/shared/widgets/stock_candidate_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final _searchController = TextEditingController();
  StrategyPreset _preset = StrategyPreset.balanced;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final query = ref.watch(dashboardQueryProvider);
    final snapshot = snapshotAsync.valueOrNull;

    return RefreshIndicator(
      onRefresh: () => controller.reload(forceRefresh: true),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            _header(context, query.date),
            const SizedBox(height: 18),
            _sectionTitle(context, '전략 가중치', trailing: '자동 리밸런스 사용'),
            const SizedBox(height: 8),
            _presetSegment(controller),
            const SizedBox(height: 10),
            if (snapshot != null)
              _snapshotContent(
                controller,
                snapshot,
                isRefreshing: snapshotAsync.isLoading,
              )
            else if (snapshotAsync.hasError)
              _loadErrorView(
                message: snapshotAsync.error.toString(),
                onRetry: () => controller.reload(forceRefresh: true),
              )
            else
              const SizedBox(
                height: 320,
                child: LoadingView(message: '대시보드 로딩 중...'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _snapshotContent(
    DashboardController controller,
    DashboardSnapshot snapshot, {
    required bool isRefreshing,
  }) {
    final candidates = snapshot.candidates
        .where(
          (c) =>
              c.name.toLowerCase().contains(_query) ||
              c.code.toLowerCase().contains(_query),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRefreshing)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        _strategySegment(controller, snapshot),
        const SizedBox(height: 8),
        Row(
          children: [
            _dataModeBadge(snapshot.dataMode),
            const SizedBox(width: 8),
            Text(
              '최근 갱신: ${DateFormat('HH:mm:ss').format(snapshot.lastUpdated)}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (snapshot.usedInformation.isNotEmpty) ...[
          _usedInformationCard(snapshot.usedInformation),
          const SizedBox(height: 12),
        ],
        if (snapshot.dataWarnings.isNotEmpty) ...[
          _dataWarningsCard(snapshot.dataWarnings),
          const SizedBox(height: 12),
        ],
        if (snapshot.warning != null && snapshot.warning!.isNotEmpty) ...[
          ErrorBanner(message: snapshot.warning!),
          const SizedBox(height: 12),
        ],
        _sectionTitle(context, '시장 개요'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _overviewCard(
                context,
                label: '하락',
                value: snapshot.overview.down.toString(),
                color: AppColors.accentRed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _overviewCard(
                context,
                label: '보합',
                value: snapshot.overview.steady.toString(),
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _overviewCard(
                context,
                label: '상승',
                value: snapshot.overview.up.toString(),
                color: AppColors.accentGreen,
              ),
            ),
          ],
        ),
        if (snapshot.overview.warnings.isNotEmpty) ...[
          const SizedBox(height: 10),
          ErrorBanner(message: snapshot.overview.warnings.first),
        ],
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle(context, '추천 종목', trailing: 'TOP5 전략'),
            TextButton(onPressed: () {}, child: const Text('전체 보기')),
          ],
        ),
        const SizedBox(height: 6),
        if (candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('추천 결과가 없습니다.'),
          )
        else
          ...candidates.take(6).map((candidate) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StockCandidateCard(candidate: candidate),
            );
          }),
        if (snapshot.intradayExtra.isNotEmpty) ...[
          const SizedBox(height: 4),
          _sectionTitle(context, '장중 추가 추천'),
          const SizedBox(height: 6),
          ...snapshot.intradayExtra.take(3).map((candidate) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StockCandidateCard(candidate: candidate),
            );
          }),
        ],
        const SizedBox(height: 10),
        const ProBanner(),
      ],
    );
  }

  Widget _header(BuildContext context, String selectedDateIso) {
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
                gradient: LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFFACC15)],
                ),
              ),
              child: const Icon(
                Icons.ssid_chart_rounded,
                color: Color(0xFF78350F),
              ),
            ),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(
                text: 'Coreline ',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                children: const [
                  TextSpan(
                    text: 'Stock AI',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const CircleAvatar(
              radius: 12,
              backgroundColor: Color(0xFFFDE68A),
              child: Icon(Icons.notifications_none_rounded, size: 14),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: '티커 또는 종목명 검색',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.surfaceDark
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => _pickDate(selectedDateIso),
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(_displayDate(selectedDateIso)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _presetSegment(DashboardController controller) {
    Widget button(StrategyPreset preset, String label) {
      final selected = _preset == preset;
      return Expanded(
        child: GestureDetector(
          onTap: () async {
            setState(() => _preset = preset);
            await controller.setPreset(preset);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : Colors.white,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          button(StrategyPreset.balanced, '균형형'),
          button(StrategyPreset.aggressive, '공격형'),
          button(StrategyPreset.defensive, '방어형'),
        ],
      ),
    );
  }

  Widget _strategySegment(
    DashboardController controller,
    DashboardSnapshot snapshot,
  ) {
    final available = snapshot.strategyStatus.availableStrategies;
    if (available.isEmpty) {
      return const ErrorBanner(message: '현재 시간에는 조회 가능한 전략이 없습니다.');
    }

    Widget button(StrategyKind kind) {
      final selected = snapshot.selectedStrategy == kind;
      final enabled = available.contains(kind);
      final message =
          snapshot.strategyStatus.messages[kind] ?? '현재는 선택할 수 없는 전략입니다.';
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (enabled) {
              controller.setStrategy(kind);
              return;
            }
            _showStrategyGuide(message);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : enabled
                  ? Colors.transparent
                  : Colors.grey.withValues(alpha: 0.08),
            ),
            alignment: Alignment.center,
            child: Text(
              kind.shortLabel,
              style: TextStyle(
                color: selected
                    ? AppColors.primary
                    : enabled
                    ? AppColors.textSecondary
                    : Colors.grey,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '전략 선택',
          trailing: '현재: ${snapshot.selectedStrategy.shortLabel}',
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.surfaceDark
                : Colors.white,
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              button(StrategyKind.premarket),
              button(StrategyKind.intraday),
              button(StrategyKind.close),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overviewCard(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _usedInformationCard(List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 전략에 사용한 정보',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '- $item',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataWarningsCard(List<String> warnings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '데이터 경고',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...warnings.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '- $item',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataModeBadge(String dataMode) {
    final (label, color) = switch (dataMode) {
      'premium' => ('프리미엄 데이터 모드', Colors.blue),
      'mixed' => ('혼합 데이터 모드', Colors.orange),
      _ => ('무료 데이터 모드', Colors.green),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _showStrategyGuide(String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  Widget _sectionTitle(BuildContext context, String title, {String? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }

  Widget _loadErrorView({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErrorBanner(message: message),
          const SizedBox(height: 10),
          Text(
            '데이터를 불러오지 못했습니다. 네트워크 상태를 확인하고 다시 시도하세요.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(String currentIso) async {
    final controller = ref.read(dashboardControllerProvider.notifier);
    final now = DateTime.now();
    final firstDate = DateTime(2020, 1, 1);
    final lastDate = now.add(const Duration(days: 2));
    final parsed = DateTime.tryParse(currentIso) ?? now;
    final initialDate = parsed.isBefore(firstDate) || parsed.isAfter(lastDate)
        ? now
        : parsed;
    final picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
    );
    if (picked != null) {
      final date = DateFormat('yyyy-MM-dd').format(picked);
      await controller.setDate(date);
    }
  }

  String _displayDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) {
      return iso;
    }
    return DateFormat('yyyy. MM. dd').format(parsed);
  }
}
