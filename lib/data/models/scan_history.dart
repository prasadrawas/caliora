import 'package:cloud_firestore/cloud_firestore.dart';

class ScanHistory {
  final String id;
  final String mealName;
  final int score;
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFiber;
  final double totalSugar;
  final double totalSaturatedFat;
  final double totalSodium;
  final List<ScanHistoryItem> items;
  final String? imageUrl;
  final DateTime timestamp;

  ScanHistory({
    required this.id,
    required this.mealName,
    required this.score,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFiber,
    required this.totalSugar,
    required this.totalSaturatedFat,
    required this.totalSodium,
    required this.items,
    this.imageUrl,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ScanHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScanHistory(
      id: doc.id,
      mealName: data['mealName'] ?? '',
      score: data['score'] ?? 0,
      totalCalories: data['totalCalories'] ?? 0,
      totalProtein: (data['totalProtein'] ?? 0).toDouble(),
      totalCarbs: (data['totalCarbs'] ?? 0).toDouble(),
      totalFat: (data['totalFat'] ?? 0).toDouble(),
      totalFiber: (data['totalFiber'] ?? 0).toDouble(),
      totalSugar: (data['totalSugar'] ?? 0).toDouble(),
      totalSaturatedFat: (data['totalSaturatedFat'] ?? 0).toDouble(),
      totalSodium: (data['totalSodium'] ?? 0).toDouble(),
      items: (data['items'] as List? ?? [])
          .map((i) => ScanHistoryItem.fromMap(i as Map<String, dynamic>))
          .toList(),
      imageUrl: data['imageUrl'],
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'mealName': mealName,
      'score': score,
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
      'totalFiber': totalFiber,
      'totalSugar': totalSugar,
      'totalSaturatedFat': totalSaturatedFat,
      'totalSodium': totalSodium,
      'items': items.map((i) => i.toMap()).toList(),
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class ScanHistoryItem {
  final String name;
  final String portion;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  ScanHistoryItem({
    required this.name,
    required this.portion,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory ScanHistoryItem.fromMap(Map<String, dynamic> data) {
    return ScanHistoryItem(
      name: data['name'] ?? '',
      portion: data['portion'] ?? '',
      calories: (data['calories'] ?? 0).toInt(),
      protein: (data['protein'] ?? 0).toDouble(),
      carbs: (data['carbs'] ?? 0).toDouble(),
      fat: (data['fat'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'portion': portion,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }
}
