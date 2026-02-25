import 'package:coreline_stock_ai/app/theme/app_colors.dart';
import 'package:coreline_stock_ai/shared/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onQuickAction,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onQuickAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        height: 56,
        width: 56,
        child: FloatingActionButton(
          onPressed: onQuickAction,
          shape: const CircleBorder(),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add_rounded),
        ),
      ),
      bottomNavigationBar: BottomNav(currentIndex: currentIndex, onTap: onTap),
    );
  }
}
