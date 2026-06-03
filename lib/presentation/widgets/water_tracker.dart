import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class WaterTracker extends StatelessWidget {
  final int currentMl;
  final int targetMl;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  const WaterTracker({
    super.key,
    required this.currentMl,
    this.targetMl = 2500,
    required this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        targetMl > 0 ? (currentMl / targetMl).clamp(0.0, 1.0) : 0.0;
    final increment = AppConfig.waterIncrement;
    final glasses = (currentMl / increment).floor();
    final percentage = (progress * 100).round();
    final isComplete = currentMl >= targetMl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.of(context).card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.of(context).glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.water.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.water_drop,
                        color: AppColors.water, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Water Intake',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: C.of(context).text,
                        ),
                      ),
                      Text(
                        '${currentMl}ml / ${targetMl}ml',
                        style: TextStyle(
                          fontSize: 11,
                          color: C.of(context).text30,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isComplete
                      ? AppColors.accentGreen.withValues(alpha: 0.12)
                      : AppColors.water.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isComplete ? 'Done!' : '$percentage%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        isComplete ? AppColors.accentGreen : AppColors.water,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Glass indicators
          Row(
            children: List.generate(10, (i) {
              final isFilled = i < glasses;
              return Expanded(
                child: Container(
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: isFilled
                        ? AppColors.water.withValues(alpha: 0.7)
                        : AppColors.water.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Remove button
              GestureDetector(
                onTap: currentMl > 0 && onRemove != null
                    ? () {
                        HapticFeedback.lightImpact();
                        onRemove!();
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: currentMl > 0
                        ? AppColors.water.withValues(alpha: 0.1)
                        : C.of(context).text12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.remove,
                    color: currentMl > 0
                        ? AppColors.water
                        : C.of(context).text30,
                    size: 18,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$glasses glasses',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: C.of(context).text54,
                ),
              ),
              const Spacer(),
              // Add button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAdd();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.water.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.water.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: AppColors.water, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${increment}ml',
                        style: const TextStyle(
                          color: AppColors.water,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
