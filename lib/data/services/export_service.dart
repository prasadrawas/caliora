import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/app_logger.dart';
import '../models/meal_entry.dart';
import '../models/user_profile.dart';

class ExportService {
  Future<void> exportAsCSV({
    required List<MealEntry> meals,
    required UserProfile profile,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    log.i('[Export] Generating CSV for ${meals.length} meals');

    final headers = [
      'Date',
      'Time',
      'Meal Name',
      'Meal Type',
      'Serving Size',
      'Calories',
      'Protein (g)',
      'Carbs (g)',
      'Fat (g)',
      'Fiber (g)',
      'Sugar (g)',
      'Saturated Fat (g)',
      'Sodium (mg)',
      'Potassium (mg)',
      'Calcium (mg)',
      'Iron (mg)',
      'Magnesium (mg)',
      'Vitamin A (mcg)',
      'Vitamin C (mg)',
      'Vitamin D (mcg)',
      'Vitamin B12 (mcg)',
      'Items Detected',
    ];

    final rows = <List<dynamic>>[headers];

    for (final meal in meals) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(meal.timestamp),
        DateFormat('HH:mm').format(meal.timestamp),
        meal.mealName,
        meal.mealType,
        meal.servingSize,
        meal.calories,
        meal.protein.toStringAsFixed(1),
        meal.carbs.toStringAsFixed(1),
        meal.fat.toStringAsFixed(1),
        meal.fiber.toStringAsFixed(1),
        meal.sugar.toStringAsFixed(1),
        meal.saturatedFat.toStringAsFixed(1),
        meal.sodium.toStringAsFixed(1),
        meal.potassium.toStringAsFixed(1),
        meal.calcium.toStringAsFixed(1),
        meal.iron.toStringAsFixed(1),
        meal.magnesium.toStringAsFixed(1),
        meal.vitaminA.toStringAsFixed(1),
        meal.vitaminC.toStringAsFixed(1),
        meal.vitaminD.toStringAsFixed(1),
        meal.vitaminB12.toStringAsFixed(1),
        meal.itemsDetected.join('; '),
      ]);
    }

    // Add summary rows
    if (meals.isNotEmpty) {
      final totalCal = meals.fold<int>(0, (s, m) => s + m.calories);
      final totalP = meals.fold<double>(0, (s, m) => s + m.protein);
      final totalC = meals.fold<double>(0, (s, m) => s + m.carbs);
      final totalF = meals.fold<double>(0, (s, m) => s + m.fat);
      final days = endDate.difference(startDate).inDays + 1;
      final activeDays = meals.map((m) => DateFormat('yyyy-MM-dd').format(m.timestamp)).toSet().length;

      rows.add([]); // empty row
      rows.add(['--- SUMMARY ---']);
      rows.add(['User', profile.name]);
      rows.add(['Period', '${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}']);
      rows.add(['Total Days', days]);
      rows.add(['Days with Meals', activeDays]);
      rows.add(['Total Meals', meals.length]);
      rows.add(['Total Calories', totalCal]);
      rows.add(['Avg Calories/Day', activeDays > 0 ? (totalCal ~/ activeDays) : 0]);
      rows.add(['Avg Protein/Day', activeDays > 0 ? '${(totalP / activeDays).toStringAsFixed(1)}g' : '0g']);
      rows.add(['Avg Carbs/Day', activeDays > 0 ? '${(totalC / activeDays).toStringAsFixed(1)}g' : '0g']);
      rows.add(['Avg Fat/Day', activeDays > 0 ? '${(totalF / activeDays).toStringAsFixed(1)}g' : '0g']);
      rows.add(['Calorie Target', '${profile.dailyCalorieTarget} kcal/day']);
      rows.add(['Protein Target', '${profile.proteinTarget}g/day']);
      rows.add(['Carbs Target', '${profile.carbsTarget}g/day']);
      rows.add(['Fat Target', '${profile.fatTarget}g/day']);
    }

    final csvData = rows.map((row) => row.map((cell) {
      final s = cell.toString();
      if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\t') || s.contains(';')) {
        return '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }).join(',')).join('\n');

    try {
      final dir = await getTemporaryDirectory();
      final fileName =
          'bitebloom_meals_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csvData);

      log.i('[Export] CSV saved: ${file.path} (${file.lengthSync()} bytes)');

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'BiteBloom Meal Report',
          text: 'My meal history from ${DateFormat('MMM d').format(startDate)} to ${DateFormat('MMM d').format(endDate)}',
        ),
      );

      // Cleanup temp file
      try {
        await file.delete();
      } catch (_) {}
    } catch (e) {
      log.e('[Export] Export failed: $e');
      throw Exception('Failed to export data. Please try again.');
    }
  }
}
