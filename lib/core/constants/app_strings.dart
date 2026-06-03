class AppStrings {
  static const String appName = 'Caliora';
  static const String tagline = 'Your AI Nutrition Companion';

  // Onboarding
  static const String onboard1Title = 'Snap Your Meal';
  static const String onboard1Desc = 'Take a photo of any meal and let AI do the rest';
  static const String onboard2Title = 'AI Analyzes Macros';
  static const String onboard2Desc = 'Our AI instantly detects food items and calculates nutrition';
  static const String onboard3Title = 'Track Your Goals';
  static const String onboard3Desc = 'Monitor your progress and achieve your nutrition goals';

  // Meal types
  static const String breakfast = 'Breakfast';
  static const String lunch = 'Lunch';
  static const String dinner = 'Dinner';
  static const String snack = 'Snack';

  // Goals
  static const String lose = 'Lose Weight';
  static const String maintain = 'Maintain Weight';
  static const String gain = 'Gain Weight';

  // Gemini prompt — returns per-item nutrition breakdown
  static const String geminiPrompt = '''Analyze this food image. Identify every food item with portion size and calculate nutrition PER ITEM.

RULES:
1. Estimate portions using plate size (26cm standard dinner plate).
2. Reference USDA/IFCT databases. Be conservative — slightly overestimate calories.
3. For Indian food use familiar units (1 roti, 1 bowl dal, 1 cup rice).

Return ONLY a JSON object, no text, no markdown, no code blocks:
{
  "meal_name": "descriptive meal name",
  "items": [
    {
      "name": "food item name",
      "portion": "estimated portion e.g. 200g",
      "calories": number,
      "protein_g": number,
      "carbs_g": number,
      "fat_g": number,
      "fiber_g": number,
      "sugar_g": number,
      "saturated_fat_g": number,
      "sodium_mg": number,
      "potassium_mg": number,
      "calcium_mg": number,
      "iron_mg": number,
      "magnesium_mg": number,
      "vitamin_a_mcg": number,
      "vitamin_c_mg": number,
      "vitamin_d_mcg": number,
      "vitamin_b12_mcg": number
    }
  ],
  "confidence": "high/medium/low"
}''';
}
