import 'package:cloud_firestore/cloud_firestore.dart';
import 'analyzed_item.dart';

class MealEntry {
  final String id;
  final String mealName;
  final int calories;
  // Macronutrients
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double saturatedFat;
  // Minerals
  final double sodium; // mg
  final double potassium; // mg
  final double calcium; // mg
  final double iron; // mg
  final double magnesium; // mg
  // Vitamins
  final double vitaminA; // mcg
  final double vitaminC; // mg
  final double vitaminD; // mcg
  final double vitaminB12; // mcg

  final String? imageUrl;
  final String mealType; // 'breakfast', 'lunch', 'dinner', 'snack'
  final DateTime timestamp;
  final String servingSize;
  final List<String> itemsDetected;
  final List<AnalyzedItem> items;

  MealEntry({
    required this.id,
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.sugar = 0,
    this.saturatedFat = 0,
    this.sodium = 0,
    this.potassium = 0,
    this.calcium = 0,
    this.iron = 0,
    this.magnesium = 0,
    this.vitaminA = 0,
    this.vitaminC = 0,
    this.vitaminD = 0,
    this.vitaminB12 = 0,
    this.imageUrl,
    required this.mealType,
    DateTime? timestamp,
    this.servingSize = '1 serving',
    this.itemsDetected = const [],
    this.items = const [],
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
      sugar: (data['sugar'] ?? 0).toDouble(),
      saturatedFat: (data['saturatedFat'] ?? 0).toDouble(),
      sodium: (data['sodium'] ?? 0).toDouble(),
      potassium: (data['potassium'] ?? 0).toDouble(),
      calcium: (data['calcium'] ?? 0).toDouble(),
      iron: (data['iron'] ?? 0).toDouble(),
      magnesium: (data['magnesium'] ?? 0).toDouble(),
      vitaminA: (data['vitaminA'] ?? 0).toDouble(),
      vitaminC: (data['vitaminC'] ?? 0).toDouble(),
      vitaminD: (data['vitaminD'] ?? 0).toDouble(),
      vitaminB12: (data['vitaminB12'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'],
      mealType: data['mealType'] ?? 'snack',
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      servingSize: data['servingSize'] ?? '1 serving',
      itemsDetected: List<String>.from(data['itemsDetected'] ?? []),
      items: (data['items'] as List<dynamic>?)
              ?.map((i) => AnalyzedItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
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
      'sugar': sugar,
      'saturatedFat': saturatedFat,
      'sodium': sodium,
      'potassium': potassium,
      'calcium': calcium,
      'iron': iron,
      'magnesium': magnesium,
      'vitaminA': vitaminA,
      'vitaminC': vitaminC,
      'vitaminD': vitaminD,
      'vitaminB12': vitaminB12,
      'imageUrl': imageUrl,
      'mealType': mealType,
      'timestamp': Timestamp.fromDate(timestamp),
      'servingSize': servingSize,
      'itemsDetected': itemsDetected,
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  MealEntry copyWith({
    String? mealName,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    double? saturatedFat,
    double? sodium,
    double? potassium,
    double? calcium,
    double? iron,
    double? magnesium,
    double? vitaminA,
    double? vitaminC,
    double? vitaminD,
    double? vitaminB12,
    String? imageUrl,
    String? mealType,
    DateTime? timestamp,
    String? servingSize,
    List<String>? itemsDetected,
    List<AnalyzedItem>? items,
  }) {
    return MealEntry(
      id: id,
      mealName: mealName ?? this.mealName,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      saturatedFat: saturatedFat ?? this.saturatedFat,
      sodium: sodium ?? this.sodium,
      potassium: potassium ?? this.potassium,
      calcium: calcium ?? this.calcium,
      iron: iron ?? this.iron,
      magnesium: magnesium ?? this.magnesium,
      vitaminA: vitaminA ?? this.vitaminA,
      vitaminC: vitaminC ?? this.vitaminC,
      vitaminD: vitaminD ?? this.vitaminD,
      vitaminB12: vitaminB12 ?? this.vitaminB12,
      imageUrl: imageUrl ?? this.imageUrl,
      mealType: mealType ?? this.mealType,
      timestamp: timestamp ?? this.timestamp,
      servingSize: servingSize ?? this.servingSize,
      itemsDetected: itemsDetected ?? this.itemsDetected,
      items: items ?? this.items,
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
