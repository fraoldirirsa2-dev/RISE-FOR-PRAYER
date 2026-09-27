import 'package:flutter/material.dart';
import 'package:rise_for_prayer/utils/colors.dart';

class GoldDivider extends StatelessWidget {
  const GoldDivider({super.key, this.height = 1});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.gold.withValues(alpha: 0.55),
            AppColors.goldLight.withValues(alpha: 0.8),
            AppColors.gold.withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class GoldDividerSmall extends StatelessWidget {
  const GoldDividerSmall({super.key, this.height = 1});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.gold.withValues(alpha: 0.3),
            AppColors.gold.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
