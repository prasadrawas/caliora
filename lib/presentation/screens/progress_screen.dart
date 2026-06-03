import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/daily_summary.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/weight_log.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/progress_provider.dart';
import '../widgets/shimmer_loader.dart';
import '../../core/theme/theme_colors.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _logWeight() async {
    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight < 20 || weight > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter a valid weight'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final today = AppDateUtils.todayKey();
    final log = WeightLog(id: today, weight: weight, date: today);
    await ref.read(firestoreServiceProvider).addWeightLog(user.uid, log);

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _weightController.clear();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Weight logged!'),
        backgroundColor: AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showWeightDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: C.of(context).bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text(
                'Log Weight',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: C.of(context).text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track your weight regularly for better insights',
                style: TextStyle(fontSize: 13, color: C.of(context).text30),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(
                    color: C.of(context).text,
                    fontSize: 24,
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  prefixIcon: Icon(Icons.monitor_weight_outlined,
                      color: C.of(context).text54),
                  suffixText: 'kg',
                  suffixStyle: TextStyle(color: C.of(context).text30),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _logWeight,
                  child: const Text('Save Weight'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final isMonthly = ref.watch(isMonthlyViewProvider);
    final progressAsync = isMonthly
        ? ref.watch(monthlyProgressProvider)
        : ref.watch(weeklyProgressProvider);
    final weightAsync = ref.watch(weightLogsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: C.of(context).card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.of(context).glassBorder),
                ),
                child: Row(
                  children: [
                    _toggleButton('Week', !isMonthly, () {
                      HapticFeedback.selectionClick();
                      ref.read(isMonthlyViewProvider.notifier).state = false;
                    }),
                    _toggleButton('Month', isMonthly, () {
                      HapticFeedback.selectionClick();
                      ref.read(isMonthlyViewProvider.notifier).state = true;
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Nutrition Report Card
          profileAsync.when(
            data: (profile) {
              if (profile == null) return const SizedBox.shrink();
              return progressAsync.when(
                data: (summaries) {
                  return _buildNutritionReport(
                    summaries, profile, isMonthly);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          // Calorie bar chart
          _sectionHeader('Calories', Icons.local_fire_department_outlined),
          const SizedBox(height: 12),
          progressAsync.when(
            data: (summaries) {
              if (summaries.isEmpty) {
                return _emptyCard('No calorie data yet');
              }
              return Container(
                height: 200,
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                decoration: BoxDecoration(
                  color: C.of(context).card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: C.of(context).glassBorder),
                ),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: summaries
                            .map((s) => s.totalCalories.toDouble())
                            .fold<double>(0, (a, b) => a > b ? a : b) *
                        1.2,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => C.of(context).secondary,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toInt()} kcal',
                            TextStyle(
                              color: C.of(context).text,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= summaries.length) {
                              return const SizedBox.shrink();
                            }
                            final date =
                                DateTime.tryParse(summaries[index].date);
                            if (date == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                isMonthly
                                    ? '${date.day}'
                                    : AppDateUtils.formatWeekday(date),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: C.of(context).text30,
                                ),
                              ),
                            );
                          },
                          reservedSize: 28,
                        ),
                      ),
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: summaries.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.totalCalories.toDouble(),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppColors.accentGreen.withValues(alpha: 0.6),
                                AppColors.accentGreen,
                              ],
                            ),
                            width: isMonthly ? 6 : 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.1, end: 0);
            },
            loading: () => const ShimmerLoader(height: 200),
            error: (e, _) =>
                _errorCard('Error loading chart', () => ref.invalidate(weeklyProgressProvider)),
          ),
          const SizedBox(height: 24),

          // Weight trend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader('Weight Trend', Icons.show_chart),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showWeightDialog();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.accentGreen.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: AppColors.accentGreen),
                      SizedBox(width: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          weightAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return _emptyCard(
                    'No weight data yet\nTap + Add to start tracking');
              }

              final reversed = logs.reversed.toList();
              final minW = reversed
                      .map((l) => l.weight)
                      .fold<double>(double.infinity, (a, b) => a < b ? a : b) -
                  2;
              final maxW = reversed
                      .map((l) => l.weight)
                      .fold<double>(0, (a, b) => a > b ? a : b) +
                  2;

              return Container(
                height: 200,
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                decoration: BoxDecoration(
                  color: C.of(context).card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: C.of(context).glassBorder),
                ),
                child: LineChart(
                  LineChartData(
                    minY: minW,
                    maxY: maxW,
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= reversed.length) {
                              return const SizedBox.shrink();
                            }
                            final date =
                                DateTime.tryParse(reversed[index].date);
                            if (date == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                AppDateUtils.formatDayMonth(date),
                                style: TextStyle(
                                    fontSize: 10, color: C.of(context).text30),
                              ),
                            );
                          },
                          reservedSize: 28,
                        ),
                      ),
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: reversed.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value.weight);
                        }).toList(),
                        isCurved: true,
                        color: AppColors.accentGreen,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.accentGreen,
                            strokeWidth: 2,
                            strokeColor: C.of(context).bg,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.accentGreen.withValues(alpha: 0.15),
                              AppColors.accentGreen.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => C.of(context).secondary,
                        getTooltipItems: (spots) {
                          return spots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(1)} kg',
                              TextStyle(
                                color: C.of(context).text,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 200.ms)
                  .slideY(begin: 0.1, end: 0);
            },
            loading: () => const ShimmerLoader(height: 200),
            error: (e, _) =>
                _errorCard('Error loading weight data', () => ref.invalidate(weightLogsProvider)),
          ),

          // Macro donut
          const SizedBox(height: 24),
          _sectionHeader("Today's Macro Split", Icons.pie_chart_outline),
          const SizedBox(height: 12),
          progressAsync.when(
            data: (summaries) {
              final today = summaries.isNotEmpty ? summaries.last : null;
              final p = today?.totalProtein ?? 0;
              final c = today?.totalCarbs ?? 0;
              final f = today?.totalFat ?? 0;
              final total = p + c + f;

              if (total == 0) {
                return _emptyCard('No macro data for today');
              }

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: C.of(context).card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: C.of(context).glassBorder),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 30,
                          sectionsSpace: 3,
                          sections: [
                            PieChartSectionData(
                              value: p,
                              color: AppColors.protein,
                              radius: 38,
                              title: '${(p / total * 100).toInt()}%',
                              titleStyle: TextStyle(
                                  fontSize: 11,
                                  color: C.of(context).text,
                                  fontWeight: FontWeight.w700),
                            ),
                            PieChartSectionData(
                              value: c,
                              color: AppColors.carbs,
                              radius: 38,
                              title: '${(c / total * 100).toInt()}%',
                              titleStyle: TextStyle(
                                  fontSize: 11,
                                  color: C.of(context).text,
                                  fontWeight: FontWeight.w700),
                            ),
                            PieChartSectionData(
                              value: f,
                              color: AppColors.fat,
                              radius: 38,
                              title: '${(f / total * 100).toInt()}%',
                              titleStyle: TextStyle(
                                  fontSize: 11,
                                  color: C.of(context).text,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _legendItem(
                              'Protein', '${p.toInt()}g', AppColors.protein),
                          const SizedBox(height: 12),
                          _legendItem(
                              'Carbs', '${c.toInt()}g', AppColors.carbs),
                          const SizedBox(height: 12),
                          _legendItem('Fat', '${f.toInt()}g', AppColors.fat),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 400.ms);
            },
            loading: () => const ShimmerLoader(height: 200),
            error: (e, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionReport(
      List<DailySummary> summaries, UserProfile profile, bool isMonthly) {
    final active = summaries.where((s) => s.totalCalories > 0).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final period = isMonthly ? 'month' : 'week';
    final totalDays = isMonthly ? 30 : 7;

    // Averages
    final avgCal = active.fold<int>(0, (s, e) => s + e.totalCalories) ~/ active.length;
    final avgProtein = active.fold<double>(0, (s, e) => s + e.totalProtein) / active.length;
    final avgCarbs = active.fold<double>(0, (s, e) => s + e.totalCarbs) / active.length;
    final avgFat = active.fold<double>(0, (s, e) => s + e.totalFat) / active.length;
    final avgFiber = active.fold<double>(0, (s, e) => s + e.totalFiber) / active.length;
    final avgSugar = active.fold<double>(0, (s, e) => s + e.totalSugar) / active.length;

    // Days below target
    final lowProteinDays = active.where((s) => s.totalProtein < profile.proteinTarget * 0.8).length;
    final lowFiberDays = active.where((s) => s.totalFiber < 20).length;
    final highSugarDays = active.where((s) => s.totalSugar > 50).length;
    final goalMetDays = active.where((s) => s.goalMet).length;

    // Calorie trend (compare first half vs second half)
    String calorieTrend = '';
    if (active.length >= 4) {
      final mid = active.length ~/ 2;
      final firstHalfAvg = active.sublist(0, mid).fold<int>(0, (s, e) => s + e.totalCalories) ~/ mid;
      final secondHalfAvg = active.sublist(mid).fold<int>(0, (s, e) => s + e.totalCalories) ~/ (active.length - mid);
      final diff = secondHalfAvg - firstHalfAvg;
      if (diff.abs() > 100) {
        calorieTrend = diff > 0
            ? 'Calories trending up (+${diff} kcal/day)'
            : 'Calories trending down (${diff} kcal/day)';
      }
    }

    // Build insights list
    final insights = <_Insight>[];

    insights.add(_Insight(
      icon: Icons.local_fire_department,
      text: 'Avg $avgCal kcal/day across ${active.length} active days',
      color: AppColors.accentGreen,
    ));

    if (goalMetDays > 0) {
      insights.add(_Insight(
        icon: Icons.check_circle,
        text: 'Hit calorie goal on $goalMetDays of ${active.length} days',
        color: AppColors.accentGreen,
      ));
    }

    if (calorieTrend.isNotEmpty) {
      insights.add(_Insight(
        icon: Icons.trending_up,
        text: calorieTrend,
        color: AppColors.warning,
      ));
    }

    if (lowProteinDays > 0) {
      insights.add(_Insight(
        icon: Icons.fitness_center,
        text: 'Protein was low on $lowProteinDays days (avg ${avgProtein.toInt()}g, target ${profile.proteinTarget}g)',
        color: AppColors.protein,
      ));
    }

    if (lowFiberDays > 0) {
      insights.add(_Insight(
        icon: Icons.eco,
        text: 'Fiber below 20g on $lowFiberDays days (avg ${avgFiber.toInt()}g)',
        color: AppColors.fiber,
      ));
    }

    if (highSugarDays > 0) {
      insights.add(_Insight(
        icon: Icons.cookie_outlined,
        text: 'Sugar exceeded 50g on $highSugarDays days (avg ${avgSugar.toInt()}g)',
        color: AppColors.error,
      ));
    }

    if (active.length < totalDays * 0.5) {
      insights.add(_Insight(
        icon: Icons.calendar_today,
        text: 'Only logged ${active.length} of $totalDays days — try logging more consistently',
        color: AppColors.warning,
      ));
    }

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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assessment,
                    color: AppColors.accentGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                '${isMonthly ? 'Monthly' : 'Weekly'} Report',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: C.of(context).text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Macro averages row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.of(context).bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _avgStat('Calories', '$avgCal', 'kcal/day', AppColors.accentGreen),
                _avgDivider(),
                _avgStat('Protein', '${avgProtein.toInt()}g', '/day', AppColors.protein),
                _avgDivider(),
                _avgStat('Carbs', '${avgCarbs.toInt()}g', '/day', AppColors.carbs),
                _avgDivider(),
                _avgStat('Fat', '${avgFat.toInt()}g', '/day', AppColors.fat),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Insights
          ...insights.map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: insight.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(insight.icon, color: insight.color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        insight.text,
                        style: TextStyle(
                          fontSize: 13,
                          color: C.of(context).text70,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _avgStat(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(fontSize: 10, color: C.of(context).text30),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: C.of(context).text54),
        ),
      ],
    );
  }

  Widget _avgDivider() {
    return Container(width: 1, height: 32, color: C.of(context).glassBorder);
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: C.of(context).text54),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: C.of(context).text,
          ),
        ),
      ],
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: C.of(context).card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.of(context).glassBorder),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: C.of(context).text30, fontSize: 14),
        ),
      ),
    );
  }

  Widget _errorCard(String message, VoidCallback onRetry) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                style: TextStyle(color: C.of(context).text54)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onRetry,
              child: const Text('Retry',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? C.of(context).bg : C.of(context).text54,
          ),
        ),
      ),
    );
  }

  Widget _legendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: C.of(context).text54),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Insight {
  final IconData icon;
  final String text;
  final Color color;

  const _Insight({
    required this.icon,
    required this.text,
    required this.color,
  });
}
