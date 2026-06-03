import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/config/app_config.dart';

class UserProfile {
  final String uid;
  final String name;
  final int age;
  final double weight;
  final double height;
  final String gender; // 'male', 'female'
  final String activityLevel; // 'sedentary', 'light', 'moderate', 'active', 'very_active'
  final String dietaryPreference; // 'none', 'vegetarian', 'vegan', 'keto', 'paleo'
  final String goal; // 'lose', 'maintain', 'gain'
  final int dailyCalorieTarget;
  final int proteinTarget;
  final int carbsTarget;
  final int fatTarget;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    this.gender = 'male',
    this.activityLevel = 'moderate',
    this.dietaryPreference = 'none',
    required this.goal,
    required this.dailyCalorieTarget,
    required this.proteinTarget,
    required this.carbsTarget,
    required this.fatTarget,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? '',
      age: data['age'] ?? 25,
      weight: (data['weight'] ?? 70).toDouble(),
      height: (data['height'] ?? 170).toDouble(),
      gender: data['gender'] ?? 'male',
      activityLevel: data['activityLevel'] ?? 'moderate',
      dietaryPreference: data['dietaryPreference'] ?? 'none',
      goal: data['goal'] ?? 'maintain',
      dailyCalorieTarget: data['dailyCalorieTarget'] ?? AppConfig.defaultCalorieTarget,
      proteinTarget: data['proteinTarget'] ?? AppConfig.defaultProteinTarget,
      carbsTarget: data['carbsTarget'] ?? AppConfig.defaultCarbsTarget,
      fatTarget: data['fatTarget'] ?? AppConfig.defaultFatTarget,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'age': age,
      'weight': weight,
      'height': height,
      'gender': gender,
      'activityLevel': activityLevel,
      'dietaryPreference': dietaryPreference,
      'goal': goal,
      'dailyCalorieTarget': dailyCalorieTarget,
      'proteinTarget': proteinTarget,
      'carbsTarget': carbsTarget,
      'fatTarget': fatTarget,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserProfile copyWith({
    String? name,
    int? age,
    double? weight,
    double? height,
    String? gender,
    String? activityLevel,
    String? dietaryPreference,
    String? goal,
    int? dailyCalorieTarget,
    int? proteinTarget,
    int? carbsTarget,
    int? fatTarget,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      goal: goal ?? this.goal,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      proteinTarget: proteinTarget ?? this.proteinTarget,
      carbsTarget: carbsTarget ?? this.carbsTarget,
      fatTarget: fatTarget ?? this.fatTarget,
      createdAt: createdAt,
    );
  }
}
