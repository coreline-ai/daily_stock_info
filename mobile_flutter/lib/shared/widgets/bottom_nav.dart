import 'package:coreline_stock_ai/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items = const [
      (icon: Icons.dashboard_rounded, label: 'Home'),
      (icon: Icons.query_stats_rounded, label: 'Analysis'),
      (icon: Icons.favorite_border_rounded, label: 'Watchlist'),
      (icon: Icons.settings_rounded, label: 'Settings'),
    ];

    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark.withValues(alpha: 0.95) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      items[i].icon,
                      color: currentIndex == i ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: currentIndex == i ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: currentIndex == i ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
