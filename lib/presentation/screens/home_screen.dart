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
import '../widgets/macro_bar.dart';
import '../widgets/meal_card.dart';
import '../widgets/water_tracker.dart';
import '../widgets/shimmer_loader.dart';

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
          backgroundColor: AppColors.cardSurface,
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
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppDateUtils.formatFullDate(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.white30,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.05, end: 0);
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

                // Macro Bars
                profileAsync.when(
                  data: (profile) {
                    if (profile == null) return const SizedBox.shrink();
                    final summary = summaryAsync.valueOrNull;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Column(
                        children: [
                          _buildSectionHeader('Macros', Icons.pie_chart_outline),
                          const SizedBox(height: 14),
                          MacroBar(
                            label: 'Protein',
                            current: summary?.totalProtein ?? 0,
                            target: profile.proteinTarget.toDouble(),
                            color: AppColors.protein,
                          ),
                          const SizedBox(height: 14),
                          MacroBar(
                            label: 'Carbs',
                            current: summary?.totalCarbs ?? 0,
                            target: profile.carbsTarget.toDouble(),
                            color: AppColors.carbs,
                          ),
                          const SizedBox(height: 14),
                          MacroBar(
                            label: 'Fat',
                            current: summary?.totalFat ?? 0,
                            target: profile.fatTarget.toDouble(),
                            color: AppColors.fat,
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 200.ms)
                        .slideY(begin: 0.1, end: 0);
                  },
                  loading: () => const ShimmerLoader(height: 140),
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
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                ),
                              ),
                              const Text(
                                'Keep it up, you\'re doing great!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.white54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 300.ms)
                        .slideX(begin: -0.05, end: 0);
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Water Tracker
                summaryAsync.when(
                  data: (summary) {
                    return WaterTracker(
                      currentMl: summary?.waterIntake ?? 0,
                      onAdd: () async {
                        final user = ref.read(currentUserProvider);
                        if (user == null) return;
                        final current = summary?.waterIntake ?? 0;
                        final today = AppDateUtils.todayKey();
                        await ref
                            .read(firestoreServiceProvider)
                            .updateWaterIntake(
                              user.uid,
                              today,
                              current + 250,
                            );
                      },
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
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.glassBorder),
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
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 36,
                                  color: AppColors.white30,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No meals logged yet',
                                style: TextStyle(
                                  color: AppColors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Snap a photo of your meal to get started',
                                style: TextStyle(
                                    color: AppColors.white30, fontSize: 13),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.white54),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
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
            style: const TextStyle(color: AppColors.white70, fontSize: 14),
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
