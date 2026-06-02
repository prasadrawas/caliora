import 'package:cloud_firestore/cloud_firestore.dart';

class DailySummary {
  final String date;
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final int waterIntake; // in ml
  final int streak;
  final bool goalMet;

  DailySummary({
    required this.date,
    this.totalCalories = 0,
    this.totalProtein = 0,
    this.totalCarbs = 0,
    this.totalFat = 0,
    this.waterIntake = 0,
    this.streak = 0,
    this.goalMet = false,
  });

  factory DailySummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailySummary(
      date: doc.id,
      totalCalories: data['totalCalories'] ?? 0,
      totalProtein: (data['totalProtein'] ?? 0).toDouble(),
      totalCarbs: (data['totalCarbs'] ?? 0).toDouble(),
      totalFat: (data['totalFat'] ?? 0).toDouble(),
      waterIntake: data['waterIntake'] ?? 0,
      streak: data['streak'] ?? 0,
      goalMet: data['goalMet'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
      'waterIntake': waterIntake,
      'streak': streak,
      'goalMet': goalMet,
    };
  }

  DailySummary copyWith({
    int? totalCalories,
    double? totalProtein,
    double? totalCarbs,
    double? totalFat,
    int? waterIntake,
    int? streak,
    bool? goalMet,
  }) {
    return DailySummary(
      date: date,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProtein: totalProtein ?? this.totalProtein,
      totalCarbs: totalCarbs ?? this.totalCarbs,
      totalFat: totalFat ?? this.totalFat,
      waterIntake: waterIntake ?? this.waterIntake,
      streak: streak ?? this.streak,
      goalMet: goalMet ?? this.goalMet,
    );
  }
}
