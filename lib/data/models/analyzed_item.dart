/// Represents a single food item with its own nutrition values.
/// Used during meal analysis flow — each item is independently editable.
class AnalyzedItem {
  String name;
  String portion;
  int calories;
  double protein;
  double carbs;
  double fat;
  double fiber;
  double sugar;
  double saturatedFat;
  double sodium;
  double potassium;
  double calcium;
  double iron;
  double magnesium;
  double vitaminA;
  double vitaminC;
  double vitaminD;
  double vitaminB12;
  bool isUserEdited;

  AnalyzedItem({
    required this.name,
    required this.portion,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
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
    this.isUserEdited = false,
  });

  factory AnalyzedItem.fromJson(Map<String, dynamic> json) {
    return AnalyzedItem(
      name: json['name'] ?? 'Unknown',
      portion: json['portion'] ?? '1 serving',
      calories: (json['calories'] ?? 0).toInt(),
      protein: (json['protein_g'] ?? 0).toDouble(),
      carbs: (json['carbs_g'] ?? 0).toDouble(),
      fat: (json['fat_g'] ?? 0).toDouble(),
      fiber: (json['fiber_g'] ?? 0).toDouble(),
      sugar: (json['sugar_g'] ?? 0).toDouble(),
      saturatedFat: (json['saturated_fat_g'] ?? 0).toDouble(),
      sodium: (json['sodium_mg'] ?? 0).toDouble(),
      potassium: (json['potassium_mg'] ?? 0).toDouble(),
      calcium: (json['calcium_mg'] ?? 0).toDouble(),
      iron: (json['iron_mg'] ?? 0).toDouble(),
      magnesium: (json['magnesium_mg'] ?? 0).toDouble(),
      vitaminA: (json['vitamin_a_mcg'] ?? 0).toDouble(),
      vitaminC: (json['vitamin_c_mg'] ?? 0).toDouble(),
      vitaminD: (json['vitamin_d_mcg'] ?? 0).toDouble(),
      vitaminB12: (json['vitamin_b12_mcg'] ?? 0).toDouble(),
    );
  }

  AnalyzedItem copy() {
    return AnalyzedItem(
      name: name,
      portion: portion,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      saturatedFat: saturatedFat,
      sodium: sodium,
      potassium: potassium,
      calcium: calcium,
      iron: iron,
      magnesium: magnesium,
      vitaminA: vitaminA,
      vitaminC: vitaminC,
      vitaminD: vitaminD,
      vitaminB12: vitaminB12,
      isUserEdited: isUserEdited,
    );
  }

  @override
  String toString() => '$name ($portion)';
}
