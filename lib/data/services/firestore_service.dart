import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../models/meal_entry.dart';
import '../models/weight_log.dart';
import '../models/daily_summary.dart';
import '../../core/utils/date_utils.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- User Profile ----

  DocumentReference _profileDoc(String userId) =>
      _db.collection('users').doc(userId).collection('profile').doc('data');

  Future<void> saveProfile(String userId, UserProfile profile) async {
    await _profileDoc(userId).set(profile.toFirestore());
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
    final doc = await _profileDoc(userId).get();
    return doc.exists;
  }

  // ---- Meals ----

  CollectionReference _mealsCollection(String userId) =>
      _db.collection('users').doc(userId).collection('meals');

  Future<String> addMeal(String userId, MealEntry meal) async {
    final doc = await _mealsCollection(userId).add(meal.toFirestore());
    return doc.id;
  }

  Future<void> updateMeal(
      String userId, String mealId, Map<String, dynamic> updates) async {
    await _mealsCollection(userId).doc(mealId).update(updates);
  }

  Future<void> deleteMeal(String userId, String mealId) async {
    await _mealsCollection(userId).doc(mealId).delete();
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
    final start = AppDateUtils.startOfDay(date);
    final end = AppDateUtils.endOfDay(date);
    final snapshot = await _mealsCollection(userId)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    int totalCal = 0;
    double totalP = 0, totalC = 0, totalF = 0;
    for (final doc in snapshot.docs) {
      final meal = MealEntry.fromFirestore(doc);
      totalCal += meal.calories;
      totalP += meal.protein;
      totalC += meal.carbs;
      totalF += meal.fat;
    }

    final dateKey = AppDateUtils.formatDate(date);
    // Get existing summary to preserve water intake and streak
    final existing = await getDailySummary(userId, dateKey);

    await updateDailySummary(userId, dateKey, {
      'totalCalories': totalCal,
      'totalProtein': totalP,
      'totalCarbs': totalC,
      'totalFat': totalF,
      'waterIntake': existing?.waterIntake ?? 0,
      'streak': existing?.streak ?? 0,
      'goalMet': totalCal >= (calorieTarget * 0.9) && totalCal <= (calorieTarget * 1.1),
    });
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

  // ---- Account Deletion ----

  Future<void> deleteAllUserData(String userId) async {
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

    // Delete profile
    await userDoc.collection('profile').doc('data').delete();
  }
}
