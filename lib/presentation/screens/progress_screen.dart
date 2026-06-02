import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/weight_log.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/progress_provider.dart';
import '../widgets/shimmer_loader.dart';

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
          decoration: const BoxDecoration(
            color: AppColors.background,
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
                    color: AppColors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Log Weight',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Track your weight regularly for better insights',
                style: TextStyle(fontSize: 13, color: AppColors.white30),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  prefixIcon: Icon(Icons.monitor_weight_outlined,
                      color: AppColors.white54),
                  suffixText: 'kg',
                  suffixStyle: TextStyle(color: AppColors.white30),
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
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
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

          // Insights card
          progressAsync.when(
            data: (summaries) {
              final activeDays =
                  summaries.where((s) => s.totalCalories > 0).length;
              final avgCal = activeDays > 0
                  ? summaries
                          .where((s) => s.totalCalories > 0)
                          .fold<int>(0, (s, e) => s + e.totalCalories) ~/
                      activeDays
                  : 0;
              if (avgCal == 0) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentGreen.withValues(alpha: 0.08),
                      AppColors.accentGreen.withValues(alpha: 0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.accentGreen.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            AppColors.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.insights,
                          color: AppColors.accentGreen, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Avg $avgCal kcal/day',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                          Text(
                            '$activeDays active days this ${isMonthly ? 'month' : 'week'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.1, end: 0);
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
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder),
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
                        getTooltipColor: (_) => AppColors.secondary,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toInt()} kcal',
                            const TextStyle(
                              color: AppColors.white,
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
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.white30,
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
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder),
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
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.white30),
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
                            strokeColor: AppColors.background,
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
                        getTooltipColor: (_) => AppColors.secondary,
                        getTooltipItems: (spots) {
                          return spots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(1)} kg',
                              const TextStyle(
                                color: AppColors.white,
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
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder),
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
                              titleStyle: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                            PieChartSectionData(
                              value: c,
                              color: AppColors.carbs,
                              radius: 38,
                              title: '${(c / total * 100).toInt()}%',
                              titleStyle: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                            PieChartSectionData(
                              value: f,
                              color: AppColors.fat,
                              radius: 38,
                              title: '${(f / total * 100).toInt()}%',
                              titleStyle: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.white,
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

  Widget _sectionHeader(String title, IconData icon) {
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

  Widget _emptyCard(String message) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.white30, fontSize: 14),
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
                style: const TextStyle(color: AppColors.white54)),
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
            color: isActive ? AppColors.background : AppColors.white54,
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
          style: const TextStyle(fontSize: 13, color: AppColors.white54),
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
