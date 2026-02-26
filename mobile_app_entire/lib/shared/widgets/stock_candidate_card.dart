import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app_entire/domain/entities/market.dart';
import 'package:mobile_app_entire/shared/design_tokens/app_colors.dart';
import 'package:mobile_app_entire/shared/utils/stock_localization.dart';

class StockCandidateCard extends StatelessWidget {
  const StockCandidateCard({super.key, required this.candidate, this.onTap});

  final StockCandidate candidate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final positive = candidate.changeRate >= 0;
    final trendColor = positive ? AppColors.accentRed : const Color(0xFF60A5FA);
    final localizedName = localizeCompanyName(candidate.name, candidate.code);
    final localizedSector = localizeSectorName(candidate.sector);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.white12
                        : Colors.grey.shade100,
                    child: Text(
                      _initials(localizedName),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          candidate.code,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${candidate.changeRate >= 0 ? '+' : ''}${candidate.changeRate.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: trendColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: trendColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Text(
                          localizedSector,
                          style: TextStyle(
                            color: trendColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI 점수',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          candidate.score.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 48,
                    child: LineChart(
                      LineChartData(
                        minY:
                            candidate.sparkline60.reduce(
                              (a, b) => a < b ? a : b,
                            ) *
                            0.995,
                        maxY:
                            candidate.sparkline60.reduce(
                              (a, b) => a > b ? a : b,
                            ) *
                            1.005,
                        clipData: const FlClipData.all(),
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: candidate.sparkline60
                                .asMap()
                                .entries
                                .map(
                                  (entry) =>
                                      FlSpot(entry.key.toDouble(), entry.value),
                                )
                                .toList(growable: false),
                            isCurved: true,
                            barWidth: 2,
                            color: trendColor,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  trendColor.withValues(alpha: 0.25),
                                  trendColor.withValues(alpha: 0.02),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 250),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}
