import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/meal_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/meals_provider.dart';
import '../widgets/meal_card.dart';
import '../widgets/shimmer_loader.dart';
import '../../core/theme/theme_colors.dart';

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

  Future<void> _confirmAndDeleteMeal(MealEntry meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: C.of(context).card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Meal',
            style: TextStyle(
                color: C.of(context).text, fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to delete "${meal.mealName}"?',
            style: TextStyle(color: C.of(context).text70, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: C.of(context).text30)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _deleteMeal(meal);
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
      profile?.dailyCalorieTarget ?? AppConfig.defaultCalorieTarget,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${meal.mealName} deleted'),
        backgroundColor: C.of(context).card,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.accentGreen,
          onPressed: () async {
            await firestoreService.addMeal(user.uid, meal);
            await firestoreService.recalculateDailySummary(
              user.uid,
              selectedDate,
              profile?.dailyCalorieTarget ?? AppConfig.defaultCalorieTarget,
            );
          },
        ),
      ),
    );
  }

  void _editMeal(MealEntry meal) {
    log.i('[Diary] Viewing meal: ${meal.mealName} (${meal.id})');

    int score = 70;
    final proteinPct = meal.calories > 0 ? (meal.protein * 4 / meal.calories * 100) : 0;
    if (proteinPct >= 20 && proteinPct <= 35) score += 10;
    if (proteinPct < 10) score -= 15;
    if (meal.fiber >= 5) score += 10;
    if (meal.fiber < 2) score -= 10;
    if (meal.sugar <= 15) score += 5;
    if (meal.sugar > 30) score -= 15;
    if (meal.saturatedFat <= 7) score += 5;
    if (meal.saturatedFat > 15) score -= 15;
    if (meal.sodium <= 800) score += 5;
    if (meal.sodium > 1500) score -= 10;
    if (meal.calories >= 300 && meal.calories <= 700) score += 5;
    if (meal.calories > 1000) score -= 10;
    score = score.clamp(0, 100);

    final scoreLabel = score >= 80 ? 'Excellent' : score >= 60 ? 'Good' : score >= 40 ? 'Fair' : 'Poor';
    final scoreColor = score >= 80 ? AppColors.accentGreen : score >= 60 ? AppColors.carbs : score >= 40 ? AppColors.warning : AppColors.error;

    final microPills = <MapEntry<String, String>>[
      if (meal.fiber > 0) MapEntry('Fiber', '${meal.fiber.toStringAsFixed(1)}g'),
      if (meal.sugar > 0) MapEntry('Sugar', '${meal.sugar.toStringAsFixed(1)}g'),
      if (meal.saturatedFat > 0) MapEntry('Sat Fat', '${meal.saturatedFat.toStringAsFixed(1)}g'),
      if (meal.sodium > 0) MapEntry('Sodium', '${meal.sodium.toStringAsFixed(1)}mg'),
      if (meal.potassium > 0) MapEntry('Potassium', '${meal.potassium.toStringAsFixed(1)}mg'),
      if (meal.calcium > 0) MapEntry('Calcium', '${meal.calcium.toStringAsFixed(1)}mg'),
      if (meal.iron > 0) MapEntry('Iron', '${meal.iron.toStringAsFixed(1)}mg'),
      if (meal.magnesium > 0) MapEntry('Magnesium', '${meal.magnesium.toStringAsFixed(1)}mg'),
      if (meal.vitaminA > 0) MapEntry('Vit A', '${meal.vitaminA.toStringAsFixed(1)}mcg'),
      if (meal.vitaminC > 0) MapEntry('Vit C', '${meal.vitaminC.toStringAsFixed(1)}mg'),
      if (meal.vitaminD > 0) MapEntry('Vit D', '${meal.vitaminD.toStringAsFixed(1)}mcg'),
      if (meal.vitaminB12 > 0) MapEntry('Vit B12', '${meal.vitaminB12.toStringAsFixed(1)}mcg'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: C.of(context).bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: C.of(context).text30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Meal Score
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: C.of(context).card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: C.of(context).glassBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: scoreColor, width: 3),
                            ),
                            child: Center(
                              child: Text('$score', style: TextStyle(
                                color: scoreColor, fontSize: 18, fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Meal Score', style: TextStyle(
                                color: C.of(context).text54, fontSize: 12)),
                              Text(scoreLabel, style: TextStyle(
                                color: scoreColor, fontSize: 18, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Meal Name
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: C.of(context).card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.of(context).glassBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.restaurant, color: AppColors.accentGreen, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(meal.mealName, style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700, color: C.of(context).text)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Items
                    Text('Items', style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: C.of(context).text54)),
                    const SizedBox(height: 8),
                    if (meal.items.isNotEmpty)
                      ...meal.items.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: C.of(context).card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: C.of(context).glassBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: C.of(context).text)),
                            const SizedBox(height: 2),
                            Text(item.portion, style: const TextStyle(
                              fontSize: 12, color: AppColors.accentGreen, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(
                              '${item.calories} kcal  •  P ${item.protein.toStringAsFixed(1)}g  •  C ${item.carbs.toStringAsFixed(1)}g  •  F ${item.fat.toStringAsFixed(1)}g',
                              style: TextStyle(fontSize: 11, color: C.of(context).text54)),
                          ],
                        ),
                      ))
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: C.of(context).card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: C.of(context).glassBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(meal.mealName, style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: C.of(context).text)),
                            const SizedBox(height: 2),
                            Text(meal.servingSize, style: const TextStyle(
                              fontSize: 12, color: AppColors.accentGreen, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(
                              '${meal.calories} kcal  •  P ${meal.protein.toStringAsFixed(1)}g  •  C ${meal.carbs.toStringAsFixed(1)}g  •  F ${meal.fat.toStringAsFixed(1)}g',
                              style: TextStyle(fontSize: 11, color: C.of(context).text54)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Macro Summary
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: C.of(context).card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.of(context).glassBorder),
                      ),
                      child: Row(
                        children: [
                          _macroCol('${meal.calories}', 'kcal', AppColors.accentGreen),
                          _macroDivider(),
                          _macroCol('${meal.protein.toStringAsFixed(1)}g', 'Protein', AppColors.protein),
                          _macroDivider(),
                          _macroCol('${meal.carbs.toStringAsFixed(1)}g', 'Carbs', AppColors.carbs),
                          _macroDivider(),
                          _macroCol('${meal.fat.toStringAsFixed(1)}g', 'Fat', AppColors.fat),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Vitamins & Minerals
                    if (microPills.isNotEmpty) ...[
                      Text('Vitamins & Minerals', style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: C.of(context).text54)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: microPills.map((e) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: C.of(context).card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: C.of(context).glassBorder),
                          ),
                          child: Text('${e.key} ${e.value}', style: TextStyle(
                            fontSize: 12, color: C.of(context).text70, fontWeight: FontWeight.w500)),
                        )).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _macroCol(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(
            color: color, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            color: C.of(context).text30, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _macroDivider() {
    return Container(width: 1, height: 30, color: C.of(context).glassBorder);
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
            color: C.of(context).bg,
            border: Border(
              bottom: BorderSide(color: C.of(context).glassBorder),
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
                          style: TextStyle(
                            fontSize: 13,
                            color: C.of(context).text30,
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
                              : C.of(context).card,
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
                                    ? C.of(context).bg
                                    : C.of(context).text30,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? C.of(context).bg
                                    : C.of(context).text,
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
                          color: C.of(context).card,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.no_meals_outlined,
                          size: 48,
                          color: C.of(context).text30,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .scale(begin: const Offset(0.8, 0.8)),
                      const SizedBox(height: 20),
                      Text(
                        'No meals logged',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: C.of(context).text70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppDateUtils.isSameDay(selectedDate, DateTime.now())
                            ? 'Snap a photo to log your first meal'
                            : 'Nothing recorded on this day',
                        style: TextStyle(
                          fontSize: 13,
                          color: C.of(context).text30,
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
                              color: C.of(context).text54,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sectionLabels[section] ?? section,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: C.of(context).text54,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: C.of(context).glassBorder,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${grouped[section]!.fold<int>(0, (s, m) => s + m.calories)} kcal',
                              style: TextStyle(
                                fontSize: 12,
                                color: C.of(context).text30,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...grouped[section]!.map(
                        (meal) => MealCard(
                          meal: meal,
                          onTap: () => _editMeal(meal),
                          onDelete: () => _confirmAndDeleteMeal(meal),
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
                  Text(
                    'Couldn\'t load meals',
                    style: TextStyle(color: C.of(context).text70),
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
                color: C.of(context).card,
                border: Border(
                  top: BorderSide(color: C.of(context).glassBorder),
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
          style: TextStyle(
            fontSize: 11,
            color: C.of(context).text30,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: C.of(context).glassBorder,
    );
  }
}
