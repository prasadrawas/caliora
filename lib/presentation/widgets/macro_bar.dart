import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class MacroBar extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final Color color;
  final String unit;

  const MacroBar({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    required this.color,
    this.unit = 'g',
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final isOver = current > target;
    final displayColor = isOver ? AppColors.error : color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: displayColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: C.of(context).text70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '${current.toInt()}',
                  style: TextStyle(
                    fontSize: 13,
                    color: displayColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ' / ${target.toInt()}$unit',
                  style: TextStyle(
                    fontSize: 12,
                    color: C.of(context).text30,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isOver) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_upward,
                      size: 12, color: AppColors.error),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: displayColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          displayColor,
                          displayColor.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: displayColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .scaleX(
                      duration: 1000.ms,
                      curve: Curves.easeOutCubic,
                      begin: 0,
                      end: 1,
                      alignment: Alignment.centerLeft,
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
