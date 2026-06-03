import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/meal_entry.dart';
import '../../core/theme/theme_colors.dart';

class MealCard extends StatelessWidget {
  final MealEntry meal;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;

  const MealCard({
    super.key,
    required this.meal,
    this.onTap,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.of(context).card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.of(context).glassBorder),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: meal.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => _buildPlaceholder(context),
                            errorWidget: (_, _, _) => _buildPlaceholder(context),
                          )
                        : _buildPlaceholder(context),
                  ),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.mealName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: C.of(context).text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${meal.servingSize} • ${AppDateUtils.formatTime(meal.timestamp)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: C.of(context).text54,
                        ),
                      ),
                    ],
                  ),
                ),
                // Calories
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${meal.calories} kcal',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Mini macro row
            Row(
              children: [
                _buildMiniMacro('P', meal.protein, AppColors.protein),
                const SizedBox(width: 8),
                _buildMiniMacro('C', meal.carbs, AppColors.carbs),
                const SizedBox(width: 8),
                _buildMiniMacro('F', meal.fat, AppColors.fat),
              ],
            ),
          ],
        ),
      ),
    );

    if (onDismissed != null) {
      return Dismissible(
        key: Key(meal.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              SizedBox(width: 4),
              Text('Delete',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        onDismissed: (_) => onDismissed?.call(),
        child: card,
      );
    }

    return card;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: C.of(context).secondary,
      child:
          Icon(Icons.restaurant, color: C.of(context).text30, size: 22),
    );
  }

  Widget _buildMiniMacro(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$label ${value.toStringAsFixed(0)}g',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
