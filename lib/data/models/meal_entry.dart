import 'package:cloud_firestore/cloud_firestore.dart';

class MealEntry {
  final String id;
  final String mealName;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final String? imageUrl;
  final String mealType; // 'breakfast', 'lunch', 'dinner', 'snack'
  final DateTime timestamp;
  final String servingSize;
  final List<String> itemsDetected;

  MealEntry({
    required this.id,
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.imageUrl,
    required this.mealType,
    DateTime? timestamp,
    this.servingSize = '1 serving',
    this.itemsDetected = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  factory MealEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealEntry(
      id: doc.id,
      mealName: data['mealName'] ?? '',
      calories: data['calories'] ?? 0,
      protein: (data['protein'] ?? 0).toDouble(),
      carbs: (data['carbs'] ?? 0).toDouble(),
      fat: (data['fat'] ?? 0).toDouble(),
      fiber: (data['fiber'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'],
      mealType: data['mealType'] ?? 'snack',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      servingSize: data['servingSize'] ?? '1 serving',
      itemsDetected: List<String>.from(data['itemsDetected'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'mealName': mealName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'imageUrl': imageUrl,
      'mealType': mealType,
      'timestamp': Timestamp.fromDate(timestamp),
      'servingSize': servingSize,
      'itemsDetected': itemsDetected,
    };
  }

  MealEntry copyWith({
    String? mealName,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    String? imageUrl,
    String? mealType,
    DateTime? timestamp,
    String? servingSize,
    List<String>? itemsDetected,
  }) {
    return MealEntry(
      id: id,
      mealName: mealName ?? this.mealName,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      imageUrl: imageUrl ?? this.imageUrl,
      mealType: mealType ?? this.mealType,
      timestamp: timestamp ?? this.timestamp,
      servingSize: servingSize ?? this.servingSize,
      itemsDetected: itemsDetected ?? this.itemsDetected,
    );
  }

  /// Determine meal type based on time of day
  static String mealTypeFromTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11) return 'breakfast';
    if (hour >= 11 && hour < 15) return 'lunch';
    if (hour >= 15 && hour < 18) return 'snack';
    return 'dinner';
  }
}
