import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/meal_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/meals_provider.dart';
import '../widgets/meal_card.dart';
import '../widgets/shimmer_loader.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  late ScrollController _calendarController;

  @override
  void initState() {
    super.initState();
    _calendarController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  void _scrollToToday() {
    if (_calendarController.hasClients) {
      _calendarController.animateTo(
        _calendarController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  Future<void> _deleteMeal(MealEntry meal) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final firestoreService = ref.read(firestoreServiceProvider);

    await firestoreService.deleteMeal(user.uid, meal.id);

    final profile = await firestoreService.getProfile(user.uid);
    final selectedDate = ref.read(selectedDateProvider);
    await firestoreService.recalculateDailySummary(
      user.uid,
      selectedDate,
      profile?.dailyCalorieTarget ?? 2000,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${meal.mealName} deleted'),
        backgroundColor: AppColors.cardSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.accentGreen,
          onPressed: () async {
            await firestoreService.addMeal(user.uid, meal);
            await firestoreService.recalculateDailySummary(
              user.uid,
              selectedDate,
              profile?.dailyCalorieTarget ?? 2000,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final mealsAsync = ref.watch(mealsForDateProvider);

    return Column(
      children: [
        // Calendar strip
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(
              bottom: BorderSide(color: AppColors.glassBorder),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppDateUtils.formatDisplayDate(selectedDate),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        Text(
                          AppDateUtils.formatWeekday(selectedDate),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.white30,
                          ),
                        ),
                      ],
                    ),
                    if (!AppDateUtils.isSameDay(selectedDate, DateTime.now()))
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(selectedDateProvider.notifier).state =
                              DateTime.now();
                          _scrollToToday();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color:
                                AppColors.accentGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  AppColors.accentGreen.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'Today',
                            style: TextStyle(
                              color: AppColors.accentGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: ListView.builder(
                  controller: _calendarController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 15,
                  itemBuilder: (context, index) {
                    final date =
                        DateTime.now().subtract(Duration(days: 14 - index));
                    final isSelected =
                        AppDateUtils.isSameDay(date, selectedDate);
                    final isToday =
                        AppDateUtils.isSameDay(date, DateTime.now());

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedDateProvider.notifier).state = date;
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentGreen
                              : AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: isToday && !isSelected
                              ? Border.all(
                                  color: AppColors.accentGreen
                                      .withValues(alpha: 0.5))
                              : Border.all(color: Colors.transparent),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.accentGreen
                                        .withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppDateUtils.formatWeekday(date),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppColors.background
                                    : AppColors.white30,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.background
                                    : AppColors.white,
                              ),
                            ),
                            if (isToday && !isSelected) ...[
                              const SizedBox(height: 2),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Meals list
        Expanded(
          child: mealsAsync.when(
            data: (meals) {
              if (meals.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.no_meals_outlined,
                          size: 48,
                          color: AppColors.white30,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .scale(begin: const Offset(0.8, 0.8)),
                      const SizedBox(height: 20),
                      const Text(
                        'No meals logged',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppDateUtils.isSameDay(selectedDate, DateTime.now())
                            ? 'Snap a photo to log your first meal'
                            : 'Nothing recorded on this day',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.white30,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Group by meal type
              final grouped = <String, List<MealEntry>>{};
              for (final meal in meals) {
                grouped.putIfAbsent(meal.mealType, () => []).add(meal);
              }

              final sections = ['breakfast', 'lunch', 'snack', 'dinner'];
              final sectionIcons = {
                'breakfast': Icons.wb_sunny_outlined,
                'lunch': Icons.light_mode_outlined,
                'snack': Icons.coffee_outlined,
                'dinner': Icons.nightlight_outlined,
              };
              final sectionLabels = {
                'breakfast': 'Breakfast',
                'lunch': 'Lunch',
                'snack': 'Snack',
                'dinner': 'Dinner',
              };

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  for (final section in sections)
                    if (grouped.containsKey(section)) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              sectionIcons[section],
                              size: 16,
                              color: AppColors.white54,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sectionLabels[section] ?? section,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white54,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: AppColors.glassBorder,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${grouped[section]!.fold<int>(0, (s, m) => s + m.calories)} kcal',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.white30,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...grouped[section]!.map(
                        (meal) => MealCard(
                          meal: meal,
                          onDismissed: () => _deleteMeal(meal),
                        )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideX(begin: 0.05, end: 0),
                      ),
                    ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: ShimmerList(itemCount: 4),
            ),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'Couldn\'t load meals',
                    style: TextStyle(color: AppColors.white70),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => ref.invalidate(mealsForDateProvider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
              ),
            ),
          ),
        ),

        // Daily total bar
        mealsAsync.when(
          data: (meals) {
            if (meals.isEmpty) return const SizedBox.shrink();
            final totalCal =
                meals.fold<int>(0, (sum, m) => sum + m.calories);
            final totalP =
                meals.fold<double>(0, (sum, m) => sum + m.protein);
            final totalC =
                meals.fold<double>(0, (sum, m) => sum + m.carbs);
            final totalF =
                meals.fold<double>(0, (sum, m) => sum + m.fat);

            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                border: Border(
                  top: BorderSide(color: AppColors.glassBorder),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryItem('Calories', '$totalCal', AppColors.accentGreen),
                  _divider(),
                  _summaryItem(
                      'Protein', '${totalP.toInt()}g', AppColors.protein),
                  _divider(),
                  _summaryItem(
                      'Carbs', '${totalC.toInt()}g', AppColors.carbs),
                  _divider(),
                  _summaryItem('Fat', '${totalF.toInt()}g', AppColors.fat),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.white30,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.glassBorder,
    );
  }
}
