import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/scan_history.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

final scanHistoryProvider = StreamProvider<List<ScanHistory>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).streamScanHistory(user.uid);
});

class ScanHistoryScreen extends ConsumerWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(scanHistoryProvider);

    return Scaffold(
      backgroundColor: C.of(context).bg,
      appBar: AppBar(
        title: const Text('Scan History'),
      ),
      body: historyAsync.when(
        data: (scans) {
          if (scans.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: C.of(context).card,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.history,
                        size: 48, color: C.of(context).text30),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No scans yet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: C.of(context).text70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your meal scan history will appear here',
                    style: TextStyle(
                      fontSize: 13,
                      color: C.of(context).text30,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: scans.length,
            itemBuilder: (context, index) {
              final scan = scans[index];
              return _ScanCard(scan: scan)
                  .animate()
                  .fadeIn(
                    duration: 300.ms,
                    delay: Duration(milliseconds: index * 50),
                  )
                  .slideX(begin: 0.03, end: 0);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentGreen),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: TextStyle(color: C.of(context).text54)),
        ),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  final ScanHistory scan;

  const _ScanCard({required this.scan});

  @override
  Widget build(BuildContext context) {
    final scoreColor = scan.score >= 80
        ? AppColors.accentGreen
        : scan.score >= 60
            ? AppColors.carbs
            : scan.score >= 40
                ? AppColors.warning
                : AppColors.error;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.of(context).card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.of(context).glassBorder),
        ),
        child: Row(
          children: [
            // Score circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scoreColor.withValues(alpha: 0.12),
                border: Border.all(color: scoreColor, width: 2),
              ),
              child: Center(
                child: Text(
                  '${scan.score}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scoreColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Meal info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.mealName,
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
                    '${scan.totalCalories} kcal  •  P ${scan.totalProtein.toInt()}g  •  C ${scan.totalCarbs.toInt()}g  •  F ${scan.totalFat.toInt()}g',
                    style: TextStyle(
                      fontSize: 11,
                      color: C.of(context).text54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppDateUtils.formatDisplayDate(scan.timestamp)}  •  ${AppDateUtils.formatTime(scan.timestamp)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: C.of(context).text30,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: C.of(context).text30, size: 20),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          final scoreColor = scan.score >= 80
              ? AppColors.accentGreen
              : scan.score >= 60
                  ? AppColors.carbs
                  : scan.score >= 40
                      ? AppColors.warning
                      : AppColors.error;

          final label = scan.score >= 80
              ? 'Excellent'
              : scan.score >= 60
                  ? 'Good'
                  : scan.score >= 40
                      ? 'Needs Improvement'
                      : 'Poor';

          return Container(
            decoration: BoxDecoration(
              color: C.of(context).bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: C.of(context).text30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Meal name + date
                  Text(
                    scan.mealName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: C.of(context).text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppDateUtils.formatDisplayDate(scan.timestamp)}  •  ${AppDateUtils.formatTime(scan.timestamp)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: C.of(context).text30,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Score
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: scoreColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scoreColor.withValues(alpha: 0.12),
                            border:
                                Border.all(color: scoreColor, width: 2.5),
                          ),
                          child: Center(
                            child: Text(
                              '${scan.score}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: scoreColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Meal Score',
                              style: TextStyle(
                                fontSize: 12,
                                color: C.of(context).text30,
                              ),
                            ),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: scoreColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Items
                  Text(
                    'Items',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: C.of(context).text54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...scan.items.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: C.of(context).card,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: C.of(context).glassBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: C.of(context).text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.portion,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.accentGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${item.calories} kcal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: C.of(context).text54,
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),

                  // Nutrition summary
                  Text(
                    'Nutrition',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: C.of(context).text54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill('${scan.totalCalories} kcal',
                          AppColors.accentGreen, context),
                      _pill('P ${scan.totalProtein.toInt()}g',
                          AppColors.protein, context),
                      _pill('C ${scan.totalCarbs.toInt()}g',
                          AppColors.carbs, context),
                      _pill('F ${scan.totalFat.toInt()}g', AppColors.fat,
                          context),
                      _pill('Fiber ${scan.totalFiber.toInt()}g',
                          AppColors.fiber, context),
                      _pill('Sugar ${scan.totalSugar.toInt()}g',
                          AppColors.warning, context),
                      _pill('Sat Fat ${scan.totalSaturatedFat.toInt()}g',
                          AppColors.error, context),
                      _pill('Sodium ${scan.totalSodium.toInt()}mg',
                          AppColors.water, context),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pill(String text, Color color, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
