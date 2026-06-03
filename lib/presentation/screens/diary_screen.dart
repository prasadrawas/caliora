import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
              profile?.dailyCalorieTarget ?? 2000,
            );
          },
        ),
      ),
    );
  }

  void _editMeal(MealEntry meal) {
    log.i('[Diary] Editing meal: ${meal.mealName} (${meal.id})');

    final nameCtrl = TextEditingController(text: meal.mealName);
    final caloriesCtrl = TextEditingController(text: '${meal.calories}');
    final proteinCtrl = TextEditingController(text: meal.protein.toStringAsFixed(1));
    final carbsCtrl = TextEditingController(text: meal.carbs.toStringAsFixed(1));
    final fatCtrl = TextEditingController(text: meal.fat.toStringAsFixed(1));
    final fiberCtrl = TextEditingController(text: meal.fiber.toStringAsFixed(1));
    final sugarCtrl = TextEditingController(text: meal.sugar.toStringAsFixed(1));
    final satFatCtrl = TextEditingController(text: meal.saturatedFat.toStringAsFixed(1));
    final sodiumCtrl = TextEditingController(text: meal.sodium.toStringAsFixed(1));
    final potassiumCtrl = TextEditingController(text: meal.potassium.toStringAsFixed(1));
    final calciumCtrl = TextEditingController(text: meal.calcium.toStringAsFixed(1));
    final ironCtrl = TextEditingController(text: meal.iron.toStringAsFixed(1));
    final magnesiumCtrl = TextEditingController(text: meal.magnesium.toStringAsFixed(1));
    final vitACtrl = TextEditingController(text: meal.vitaminA.toStringAsFixed(1));
    final vitCCtrl = TextEditingController(text: meal.vitaminC.toStringAsFixed(1));
    final vitDCtrl = TextEditingController(text: meal.vitaminD.toStringAsFixed(1));
    final vitB12Ctrl = TextEditingController(text: meal.vitaminB12.toStringAsFixed(1));
    final servingCtrl = TextEditingController(text: meal.servingSize);

    bool isSaving = false;

    double parsePositive(String text) {
      final val = double.tryParse(text) ?? 0;
      return val < 0 ? 0 : val;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: C.of(context).bg,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.carbs
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.edit,
                                      color: AppColors.carbs, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Edit Meal',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: C.of(context).text,
                                      ),
                                    ),
                                    Text(
                                      'Update nutrition details',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: C.of(context).text30),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _editField('Meal Name', nameCtrl,
                                Icons.restaurant),
                            _editField('Serving Size', servingCtrl,
                                Icons.straighten),
                            _editField('Calories', caloriesCtrl,
                                Icons.local_fire_department,
                                isNumber: true),
                            const SizedBox(height: 8),
                            _editSectionLabel('Macronutrients'),
                            _editField('Protein (g)', proteinCtrl,
                                Icons.fitness_center,
                                isNumber: true),
                            _editField(
                                'Carbs (g)', carbsCtrl, Icons.grain,
                                isNumber: true),
                            _editField(
                                'Fat (g)', fatCtrl, Icons.opacity,
                                isNumber: true),
                            _editField(
                                'Fiber (g)', fiberCtrl, Icons.eco,
                                isNumber: true),
                            _editField('Sugar (g)', sugarCtrl,
                                Icons.cookie_outlined,
                                isNumber: true),
                            _editField('Saturated Fat (g)', satFatCtrl,
                                Icons.water_drop_outlined,
                                isNumber: true),
                            const SizedBox(height: 8),
                            _editSectionLabel('Minerals'),
                            _editField('Sodium (mg)', sodiumCtrl,
                                Icons.science_outlined,
                                isNumber: true),
                            _editField('Potassium (mg)', potassiumCtrl,
                                Icons.bolt_outlined,
                                isNumber: true),
                            _editField('Calcium (mg)', calciumCtrl,
                                Icons.shield_outlined,
                                isNumber: true),
                            _editField('Iron (mg)', ironCtrl,
                                Icons.bloodtype_outlined,
                                isNumber: true),
                            _editField('Magnesium (mg)', magnesiumCtrl,
                                Icons.spa_outlined,
                                isNumber: true),
                            const SizedBox(height: 8),
                            _editSectionLabel('Vitamins'),
                            _editField('Vitamin A (mcg)', vitACtrl,
                                Icons.visibility_outlined,
                                isNumber: true),
                            _editField('Vitamin C (mg)', vitCCtrl,
                                Icons.local_pharmacy_outlined,
                                isNumber: true),
                            _editField('Vitamin D (mcg)', vitDCtrl,
                                Icons.wb_sunny_outlined,
                                isNumber: true),
                            _editField('Vitamin B12 (mcg)', vitB12Ctrl,
                                Icons.psychology_outlined,
                                isNumber: true),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        if (nameCtrl.text.trim().isEmpty) return;

                                        setSheetState(
                                            () => isSaving = true);

                                        try {
                                          final user = ref.read(
                                              currentUserProvider);
                                          if (user == null) return;

                                          final updates = {
                                            'mealName':
                                                nameCtrl.text.trim(),
                                            'calories': parsePositive(
                                                    caloriesCtrl.text)
                                                .toInt(),
                                            'protein': parsePositive(
                                                proteinCtrl.text),
                                            'carbs': parsePositive(
                                                carbsCtrl.text),
                                            'fat': parsePositive(
                                                fatCtrl.text),
                                            'fiber': parsePositive(
                                                fiberCtrl.text),
                                            'sugar': parsePositive(
                                                sugarCtrl.text),
                                            'saturatedFat':
                                                parsePositive(
                                                    satFatCtrl.text),
                                            'sodium': parsePositive(
                                                sodiumCtrl.text),
                                            'potassium': parsePositive(
                                                potassiumCtrl.text),
                                            'calcium': parsePositive(
                                                calciumCtrl.text),
                                            'iron': parsePositive(
                                                ironCtrl.text),
                                            'magnesium': parsePositive(
                                                magnesiumCtrl.text),
                                            'vitaminA': parsePositive(
                                                vitACtrl.text),
                                            'vitaminC': parsePositive(
                                                vitCCtrl.text),
                                            'vitaminD': parsePositive(
                                                vitDCtrl.text),
                                            'vitaminB12': parsePositive(
                                                vitB12Ctrl.text),
                                            'servingSize':
                                                servingCtrl.text,
                                          };

                                          final firestoreService = ref
                                              .read(
                                                  firestoreServiceProvider);
                                          await firestoreService
                                              .updateMeal(user.uid,
                                                  meal.id, updates);

                                          final profile =
                                              await firestoreService
                                                  .getProfile(user.uid);
                                          final selectedDate = ref.read(
                                              selectedDateProvider);
                                          await firestoreService
                                              .recalculateDailySummary(
                                            user.uid,
                                            selectedDate,
                                            profile?.dailyCalorieTarget ??
                                                2000,
                                          );

                                          log.i(
                                              '[Diary] Meal updated: ${nameCtrl.text}');

                                          if (!context.mounted) return;
                                          HapticFeedback.mediumImpact();
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(this
                                                  .context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                  'Meal updated'),
                                              backgroundColor:
                                                  AppColors.accentGreen,
                                              behavior: SnackBarBehavior
                                                  .floating,
                                              duration:
                                                  const Duration(
                                                      seconds: 2),
                                              shape:
                                                  RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(12),
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          log.e(
                                              '[Diary] Edit failed: $e');
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Error: $e'),
                                              backgroundColor:
                                                  AppColors.error,
                                              behavior: SnackBarBehavior
                                                  .floating,
                                              shape:
                                                  RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(12),
                                              ),
                                            ),
                                          );
                                        } finally {
                                          if (context.mounted) {
                                            setSheetState(
                                                () => isSaving = false);
                                          }
                                        }
                                      },
                                child: isSaving
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: C.of(context).bg,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_outline,
                                              size: 20),
                                          SizedBox(width: 8),
                                          Text('Save Changes'),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isSaving)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: AppColors.accentGreen,
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Saving changes...',
                                style: TextStyle(
                                  color: C.of(context).text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _editField(String label, TextEditingController controller,
      IconData icon,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: C.of(context).text),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: C.of(context).text54, size: 20),
        ),
      ),
    );
  }

  Widget _editSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: C.of(context).text54,
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
