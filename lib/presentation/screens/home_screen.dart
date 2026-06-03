import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/meals_provider.dart';
import '../../providers/summary_provider.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/meal_card.dart';
import '../widgets/water_tracker.dart';
import '../widgets/shimmer_loader.dart';
import '../../core/theme/theme_colors.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _checkGoalMet(int consumed, int target) {
    if (consumed >= (target * 0.9) && consumed <= (target * 1.1)) {
      HapticFeedback.mediumImpact();
      _confettiController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final mealsAsync = ref.watch(todayMealsProvider);
    final summaryAsync = ref.watch(dailySummaryProvider);

    ref.listen(dailySummaryProvider, (prev, next) {
      final summary = next.valueOrNull;
      final profile = profileAsync.valueOrNull;
      if (summary != null && profile != null) {
        _checkGoalMet(summary.totalCalories, profile.dailyCalorieTarget);
      }
    });

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.accentGreen,
          backgroundColor: C.of(context).card,
          onRefresh: () async {
            ref.invalidate(todayMealsProvider);
            ref.invalidate(dailySummaryProvider);
            ref.invalidate(userProfileProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting with date
                profileAsync.when(
                  data: (profile) {
                    final name = profile?.name.split(' ').first ?? 'there';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${AppDateUtils.getGreeting()}, $name \u{1F44B}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppDateUtils.formatFullDate(DateTime.now()),
                          style: TextStyle(
                            fontSize: 13,
                            color: C.of(context).text30,
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideX(begin: -0.05, end: 0);
                  },
                  loading: () => const ShimmerLoader(height: 48, width: 200),
                  error: (_, _) => const Text('Hello there \u{1F44B}'),
                ),
                const SizedBox(height: 24),

                // Calorie Ring
                Center(
                  child: summaryAsync.when(
                    data: (summary) {
                      final profile = profileAsync.valueOrNull;
                      final consumed = summary?.totalCalories ?? 0;
                      final target = profile?.dailyCalorieTarget ?? 2000;
                      return CalorieRing(consumed: consumed, target: target);
                    },
                    loading: () => const ShimmerLoader(
                      width: 200,
                      height: 200,
                      borderRadius: 100,
                    ),
                    error: (_, _) =>
                        const CalorieRing(consumed: 0, target: 2000),
                  ),
                ),
                const SizedBox(height: 24),

                // Macro Targets
                profileAsync.when(
                  data: (profile) {
                    if (profile == null) return const SizedBox.shrink();
                    final summary = summaryAsync.valueOrNull;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: C.of(context).card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: C.of(context).glassBorder),
                      ),
                      child: Column(
                        children: [
                          _buildSectionHeader(
                              'Macro Targets', Icons.track_changes),
                          const SizedBox(height: 14),
                          _mineralRow('Protein', summary?.totalProtein ?? 0,
                              profile.proteinTarget.toDouble(), 'g',
                              Icons.fitness_center, AppColors.protein),
                          const SizedBox(height: 14),
                          _mineralRow('Carbs', summary?.totalCarbs ?? 0,
                              profile.carbsTarget.toDouble(), 'g',
                              Icons.grain, AppColors.carbs),
                          const SizedBox(height: 14),
                          _mineralRow('Fat', summary?.totalFat ?? 0,
                              profile.fatTarget.toDouble(), 'g',
                              Icons.opacity, AppColors.fat),
                          const SizedBox(height: 14),
                          _mineralRow('Fiber', summary?.totalFiber ?? 0,
                              25, 'g',
                              Icons.eco, AppColors.fiber),
                          const SizedBox(height: 14),
                          _mineralRow('Sugar', summary?.totalSugar ?? 0,
                              50, 'g',
                              Icons.cookie_outlined, AppColors.warning),
                          const SizedBox(height: 14),
                          _mineralRow('Saturated Fat', summary?.totalSaturatedFat ?? 0,
                              20, 'g',
                              Icons.water_drop_outlined, AppColors.error),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 200.ms)
                        .slideY(begin: 0.1, end: 0);
                  },
                  loading: () => const ShimmerLoader(height: 180),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Minerals & Vitamins Dashboard
                summaryAsync.when(
                  data: (summary) {
                    return Column(
                      children: [
                        // Minerals Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: C.of(context).card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: C.of(context).glassBorder),
                          ),
                          child: Column(
                            children: [
                              _buildSectionHeader(
                                  'Minerals', Icons.science_outlined),
                              const SizedBox(height: 14),
                              _mineralRow(
                                'Sodium',
                                summary?.totalSodium ?? 0,
                                2300,
                                'mg',
                                Icons.water_drop,
                                AppColors.warning,
                              ),
                              const SizedBox(height: 14),
                              _mineralRow(
                                'Potassium',
                                summary?.totalPotassium ?? 0,
                                3500,
                                'mg',
                                Icons.bolt,
                                AppColors.accentGreen,
                              ),
                              const SizedBox(height: 14),
                              _mineralRow(
                                'Calcium',
                                summary?.totalCalcium ?? 0,
                                1000,
                                'mg',
                                Icons.shield_outlined,
                                C.of(context).text70,
                              ),
                              const SizedBox(height: 14),
                              _mineralRow(
                                'Iron',
                                summary?.totalIron ?? 0,
                                18,
                                'mg',
                                Icons.bloodtype_outlined,
                                AppColors.error,
                              ),
                              const SizedBox(height: 14),
                              _mineralRow(
                                'Magnesium',
                                summary?.totalMagnesium ?? 0,
                                400,
                                'mg',
                                Icons.spa_outlined,
                                AppColors.protein,
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 400.ms)
                            .slideY(begin: 0.1, end: 0),
                        const SizedBox(height: 16),

                        // Vitamins Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: C.of(context).card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: C.of(context).glassBorder),
                          ),
                          child: Column(
                            children: [
                              _buildSectionHeader(
                                  'Vitamins', Icons.local_pharmacy_outlined),
                              const SizedBox(height: 14),
                              _mineralRow(
                                'Vitamin A',
                                summary?.totalVitaminA ?? 0,
                                900,
                                'mcg',
                                Icons.visibility_outlined,
                                AppColors.carbs,
                              ),
                              const SizedBox(height: 14),
                              _mineralRow(
                                'Vitamin C',
                                summary?.totalVitaminC ?? 0,
                                90,
                                'mg',
                                Icons.local_pharmacy_outlined,
                                AppColors.accentGreen,
                              ),
                              const SizedBox(height: 14),
                              _mineralRow(
                                'Vitamin D',
                                summary?.totalVitaminD ?? 0,
                                20,
                                'mcg',
                                Icons.wb_sunny_outlined,
                                AppColors.warning,
                              ),
                              const SizedBox(height: 14),
                              _mineralRow(
                                'Vitamin B12',
                                summary?.totalVitaminB12 ?? 0,
                                2.4,
                                'mcg',
                                Icons.psychology_outlined,
                                AppColors.protein,
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 500.ms)
                            .slideY(begin: 0.1, end: 0),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Streak
                summaryAsync.when(
                  data: (summary) {
                    final streak = summary?.streak ?? 0;
                    if (streak <= 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.warning.withValues(alpha: 0.08),
                            AppColors.warning.withValues(alpha: 0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Text('\u{1F525}',
                              style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$streak day streak!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: C.of(context).text,
                                ),
                              ),
                              Text(
                                'Keep it up, you\'re doing great!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: C.of(context).text54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 350.ms)
                        .slideX(begin: -0.05, end: 0);
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Water Tracker
                summaryAsync.when(
                  data: (summary) {
                    final currentWater = summary?.waterIntake ?? 0;
                    return WaterTracker(
                      currentMl: currentWater,
                      onAdd: () async {
                        final user = ref.read(currentUserProvider);
                        if (user == null) return;
                        final today = AppDateUtils.todayKey();
                        await ref
                            .read(firestoreServiceProvider)
                            .updateWaterIntake(
                              user.uid,
                              today,
                              currentWater + 250,
                            );
                      },
                      onRemove: currentWater > 0
                          ? () async {
                              final user = ref.read(currentUserProvider);
                              if (user == null) return;
                              final today = AppDateUtils.todayKey();
                              await ref
                                  .read(firestoreServiceProvider)
                                  .updateWaterIntake(
                                    user.uid,
                                    today,
                                    (currentWater - 250).clamp(0, 99999),
                                  );
                            }
                          : null,
                    ).animate().fadeIn(duration: 500.ms, delay: 400.ms);
                  },
                  loading: () => const ShimmerLoader(height: 120),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),

                // Today's Meals
                _buildSectionHeader("Today's Meals", Icons.restaurant_menu)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 500.ms),
                const SizedBox(height: 12),

                mealsAsync.when(
                  data: (meals) {
                    if (meals.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 40, horizontal: 24),
                        decoration: BoxDecoration(
                          color: C.of(context).card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: C.of(context).glassBorder),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.accentGreen
                                      .withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  size: 36,
                                  color: C.of(context).text30,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No meals logged yet',
                                style: TextStyle(
                                  color: C.of(context).text70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Snap a photo of your meal to get started',
                                style: TextStyle(
                                    color: C.of(context).text30, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms);
                    }
                    return Column(
                      children: meals.asMap().entries.map((entry) {
                        return MealCard(meal: entry.value)
                            .animate()
                            .fadeIn(
                              duration: 400.ms,
                              delay: Duration(
                                  milliseconds: 600 + entry.key * 100),
                            )
                            .slideX(begin: 0.05, end: 0);
                      }).toList(),
                    );
                  },
                  loading: () => const ShimmerList(itemCount: 3),
                  error: (e, _) => _buildErrorState(
                    'Couldn\'t load meals',
                    onRetry: () => ref.invalidate(todayMealsProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              AppColors.accentGreen,
              AppColors.protein,
              AppColors.carbs,
              AppColors.fat,
            ],
          ),
        ),
      ],
    );
  }

  Widget _mineralRow(String label, double current, double dailyTarget,
      String unit, IconData icon, Color color) {
    final pct = dailyTarget > 0 ? (current / dailyTarget).clamp(0.0, 1.0) : 0.0;
    final pctDisplay = (pct * 100).round();
    final isOver = current > dailyTarget;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: C.of(context).text70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${current.toStringAsFixed(current < 10 ? 1 : 0)} / ${dailyTarget.toStringAsFixed(dailyTarget < 10 ? 1 : 0)} $unit',
                      style: TextStyle(
                        fontSize: 12,
                        color: C.of(context).text30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: pct,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isOver ? AppColors.error : color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (pctDisplay >= 80 ? AppColors.accentGreen : color)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$pctDisplay%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: pctDisplay >= 80 ? AppColors.accentGreen : color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: C.of(context).text54),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: C.of(context).text,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message, {VoidCallback? onRetry}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: C.of(context).text70, fontSize: 14),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
