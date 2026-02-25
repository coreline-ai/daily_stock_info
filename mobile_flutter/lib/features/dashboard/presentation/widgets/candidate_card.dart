import 'package:coreline_stock_ai/app/theme/app_colors.dart';
import 'package:coreline_stock_ai/features/dashboard/domain/entities/dashboard_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CandidateCard extends StatelessWidget {
  const CandidateCard({
    super.key,
    required this.candidate,
    required this.expanded,
    required this.detail,
    required this.loadingDetail,
    required this.onToggle,
  });

  final StockCandidate candidate;
  final bool expanded;
  final StockDetail? detail;
  final bool loadingDetail;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = candidate.changeRate >= 0;
    final changeColor = positive ? AppColors.accentRed : Colors.lightBlue;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.brightness == Brightness.dark
                        ? AppColors.surfaceHighlight
                        : const Color(0xFFF1F5F9),
                    child: Text(
                      _avatarText(candidate.name),
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                candidate.name,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (candidate.strongRecommendation)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'TOP5',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.amber[800],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          candidate.code,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          candidate.summary,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${positive ? '+' : ''}${candidate.changeRate.toStringAsFixed(2)}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: changeColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if ((candidate.sector ?? '').isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            candidate.sector!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricLine(
                    label: 'AI Score',
                    value: '${candidate.score.toStringAsFixed(1)} / 10',
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 44,
                  width: 110,
                  child: _Sparkline(values: candidate.sparkline60, color: changeColor),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (loadingDetail)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                _DetailSection(candidate: candidate, detail: detail),
            ],
          ],
        ),
      ),
    );
  }

  String _avatarText(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '--';
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    final spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (values.length - 1).toDouble(),
        minY: minY,
        maxY: maxY == minY ? minY + 1 : maxY,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: color,
            barWidth: 2,
            isCurved: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.15)),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.candidate, required this.detail});

  final StockCandidate candidate;
  final StockDetail? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final metricItems = [
      ('현재가', candidate.price),
      ('목표가', candidate.targetPrice),
      ('손절가', candidate.stopLoss),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: metricItems
              .map(
                (item) => Text(
                  '${item.$1} ${_fmt(item.$2)}',
                  style: textTheme.bodySmall,
                ),
              )
              .toList(growable: false),
        ),
        if (candidate.validationGate != null) ...[
          const SizedBox(height: 8),
          Text(
            '검증 게이트: ${candidate.validationGate}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (candidate.intradaySignals != null) ...[
          const SizedBox(height: 8),
          Text(
            '장중신호 ORB ${candidate.intradaySignals!.orbScore.toStringAsFixed(1)} | '
            'VWAP ${candidate.intradaySignals!.vwapScore.toStringAsFixed(1)} | '
            'RVOL ${candidate.intradaySignals!.rvolScore.toStringAsFixed(1)}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (detail != null) ...[
          const SizedBox(height: 8),
          Text(
            detail!.aiSummary.isNotEmpty ? detail!.aiSummary : detail!.newsSummary3.join(' / '),
            style: textTheme.bodySmall,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  String _fmt(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}
