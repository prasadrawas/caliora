import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/app_logger.dart';
import '../models/user_profile.dart';
import '../models/meal_entry.dart';
import '../models/weight_log.dart';
import '../models/daily_summary.dart';
import '../models/scan_history.dart';
import '../../core/utils/date_utils.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- User Profile ----

  DocumentReference _profileDoc(String userId) =>
      _db.collection('users').doc(userId).collection('profile').doc('data');

  Future<void> saveProfile(String userId, UserProfile profile) async {
    log.i('[Firestore] Saving profile for user: $userId');
    log.d('[Firestore] Profile: ${profile.name}, goal: ${profile.goal}, calories: ${profile.dailyCalorieTarget}');
    await _profileDoc(userId).set(profile.toFirestore());
    log.i('[Firestore] Profile saved');
  }

  Future<void> updateProfile(
      String userId, Map<String, dynamic> updates) async {
    await _profileDoc(userId).update(updates);
  }

  Stream<UserProfile?> streamProfile(String userId) {
    return _profileDoc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    });
  }

  Future<UserProfile?> getProfile(String userId) async {
    final doc = await _profileDoc(userId).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  Future<bool> hasProfile(String userId) async {
    log.d('[Firestore] Checking profile exists for: $userId');
    final doc = await _profileDoc(userId).get();
    log.d('[Firestore] Profile exists: ${doc.exists}');
    return doc.exists;
  }

  // ---- Meals ----

  CollectionReference _mealsCollection(String userId) =>
      _db.collection('users').doc(userId).collection('meals');

  Future<String> addMeal(String userId, MealEntry meal) async {
    log.i('[Firestore] Adding meal: ${meal.mealName} (${meal.calories} kcal)');
    log.d('[Firestore] User: $userId, Type: ${meal.mealType}');
    final doc = await _mealsCollection(userId).add(meal.toFirestore());
    log.i('[Firestore] Meal added with ID: ${doc.id}');
    return doc.id;
  }

  Future<void> updateMeal(
      String userId, String mealId, Map<String, dynamic> updates) async {
    await _mealsCollection(userId).doc(mealId).update(updates);
  }

  Future<void> deleteMeal(String userId, String mealId) async {
    log.i('[Firestore] Deleting meal: $mealId');
    await _mealsCollection(userId).doc(mealId).delete();
    log.i('[Firestore] Meal deleted');
  }

  Stream<List<MealEntry>> streamMealsForDate(String userId, DateTime date) {
    final start = AppDateUtils.startOfDay(date);
    final end = AppDateUtils.endOfDay(date);
    return _mealsCollection(userId)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => MealEntry.fromFirestore(doc)).toList());
  }

  Future<List<MealEntry>> getMealsForRange(
      String userId, DateTime start, DateTime end) async {
    log.d('[Firestore] Fetching meals from $start to $end');
    final snapshot = await _mealsCollection(userId)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: false)
        .get();
    final meals =
        snapshot.docs.map((doc) => MealEntry.fromFirestore(doc)).toList();
    log.d('[Firestore] Fetched ${meals.length} meals');
    return meals;
  }

  Stream<List<MealEntry>> streamTodayMeals(String userId) {
    return streamMealsForDate(userId, DateTime.now());
  }

  // ---- Daily Summaries ----

  DocumentReference _summaryDoc(String userId, String date) =>
      _db.collection('users').doc(userId).collection('daily_summaries').doc(date);

  Future<void> updateDailySummary(String userId, String date,
      Map<String, dynamic> data) async {
    await _summaryDoc(userId, date).set(data, SetOptions(merge: true));
  }

  Stream<DailySummary?> streamDailySummary(String userId, String date) {
    return _summaryDoc(userId, date).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DailySummary.fromFirestore(doc);
    });
  }

  Future<DailySummary?> getDailySummary(String userId, String date) async {
    final doc = await _summaryDoc(userId, date).get();
    if (!doc.exists) return null;
    return DailySummary.fromFirestore(doc);
  }

  Future<List<DailySummary>> getSummariesForRange(
      String userId, List<DateTime> dates) async {
    final summaries = <DailySummary>[];
    for (final date in dates) {
      final key = AppDateUtils.formatDate(date);
      final summary = await getDailySummary(userId, key);
      summaries.add(summary ?? DailySummary(date: key));
    }
    return summaries;
  }

  /// Recalculate daily summary from meals
  Future<void> recalculateDailySummary(
      String userId, DateTime date, int calorieTarget) async {
    log.i('[Firestore] Recalculating daily summary for $date');
    final start = AppDateUtils.startOfDay(date);
    final end = AppDateUtils.endOfDay(date);
    final snapshot = await _mealsCollection(userId)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    int totalCal = 0;
    double totalP = 0, totalC = 0, totalF = 0, totalFiber = 0;
    double totalSugar = 0, totalSatFat = 0;
    double totalSodium = 0, totalPotassium = 0, totalCalcium = 0;
    double totalIron = 0, totalMagnesium = 0;
    double totalVitA = 0, totalVitC = 0, totalVitD = 0, totalVitB12 = 0;

    for (final doc in snapshot.docs) {
      final meal = MealEntry.fromFirestore(doc);
      totalCal += meal.calories;
      totalP += meal.protein;
      totalC += meal.carbs;
      totalF += meal.fat;
      totalFiber += meal.fiber;
      totalSugar += meal.sugar;
      totalSatFat += meal.saturatedFat;
      totalSodium += meal.sodium;
      totalPotassium += meal.potassium;
      totalCalcium += meal.calcium;
      totalIron += meal.iron;
      totalMagnesium += meal.magnesium;
      totalVitA += meal.vitaminA;
      totalVitC += meal.vitaminC;
      totalVitD += meal.vitaminD;
      totalVitB12 += meal.vitaminB12;
    }

    final dateKey = AppDateUtils.formatDate(date);
    // Get existing summary to preserve water intake and streak
    final existing = await getDailySummary(userId, dateKey);

    await updateDailySummary(userId, dateKey, {
      'totalCalories': totalCal,
      'totalProtein': totalP,
      'totalCarbs': totalC,
      'totalFat': totalF,
      'totalFiber': totalFiber,
      'totalSugar': totalSugar,
      'totalSaturatedFat': totalSatFat,
      'totalSodium': totalSodium,
      'totalPotassium': totalPotassium,
      'totalCalcium': totalCalcium,
      'totalIron': totalIron,
      'totalMagnesium': totalMagnesium,
      'totalVitaminA': totalVitA,
      'totalVitaminC': totalVitC,
      'totalVitaminD': totalVitD,
      'totalVitaminB12': totalVitB12,
      'waterIntake': existing?.waterIntake ?? 0,
      'streak': existing?.streak ?? 0,
      'goalMet': totalCal >= (calorieTarget * AppConfig.goalMetLower) && totalCal <= (calorieTarget * AppConfig.goalMetUpper),
    });
    log.i('[Firestore] Summary recalculated: $totalCal kcal, P:${totalP.toInt()}g C:${totalC.toInt()}g F:${totalF.toInt()}g');
  }

  // ---- Weight Logs ----

  CollectionReference _weightCollection(String userId) =>
      _db.collection('users').doc(userId).collection('weight_logs');

  Future<void> addWeightLog(String userId, WeightLog log) async {
    await _weightCollection(userId).doc(log.date).set(log.toFirestore());
  }

  Stream<List<WeightLog>> streamWeightLogs(String userId) {
    return _weightCollection(userId)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => WeightLog.fromFirestore(doc)).toList());
  }

  // ---- Water Intake ----

  Future<void> updateWaterIntake(String userId, String date, int ml) async {
    await updateDailySummary(userId, date, {'waterIntake': ml});
  }

  // ---- Scan History ----

  CollectionReference _scanHistoryCollection(String userId) =>
      _db.collection('users').doc(userId).collection('scan_history');

  Future<void> saveScanHistory(String userId, ScanHistory scan) async {
    log.i('[Firestore] Saving scan history: ${scan.mealName}');
    await _scanHistoryCollection(userId).add(scan.toFirestore());
  }

  Stream<List<ScanHistory>> streamScanHistory(String userId) {
    return _scanHistoryCollection(userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ScanHistory.fromFirestore(doc)).toList());
  }

  // ---- Account Deletion ----

  Future<void> deleteAllUserData(String userId) async {
    log.w('[Firestore] Deleting ALL data for user: $userId');
    final userDoc = _db.collection('users').doc(userId);

    // Delete meals
    final meals = await userDoc.collection('meals').get();
    for (final doc in meals.docs) {
      await doc.reference.delete();
    }

    // Delete weight logs
    final weights = await userDoc.collection('weight_logs').get();
    for (final doc in weights.docs) {
      await doc.reference.delete();
    }

    // Delete daily summaries
    final summaries = await userDoc.collection('daily_summaries').get();
    for (final doc in summaries.docs) {
      await doc.reference.delete();
    }

    // Delete scan history
    final scans = await userDoc.collection('scan_history').get();
    for (final doc in scans.docs) {
      await doc.reference.delete();
    }

    // Delete profile
    await userDoc.collection('profile').doc('data').delete();
  }
}
