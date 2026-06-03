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

  // Gemini prompt — returns nutrition + detected items in a single call
  static const String geminiPrompt = '''You are an expert nutritionist AI. Analyze this food image, identify every food item with portions, and calculate complete nutritional content.

INSTRUCTIONS:
1. Identify every distinct food item visible in the image.
2. Estimate portion size of each item in grams or common units. A typical dinner plate is 26cm diameter.
3. If Indian cuisine, use familiar terms (1 roti, 1 bowl dal, 1 cup rice).
4. Reference USDA FoodData Central or IFCT (Indian foods) for nutrition values.
5. Consider cooking method impact: fried adds 30-50% more calories than steamed/boiled.
6. Be conservative — slightly overestimate rather than underestimate calories.
7. Sum all items for total meal nutrition.

Return ONLY a JSON object with no extra text, no markdown, no code blocks:
{
  "meal_name": "descriptive name of the complete meal",
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
  "vitamin_b12_mcg": number,
  "serving_size": "estimated total weight e.g. 350g",
  "confidence": "high/medium/low",
  "items_detected": ["item1 (estimated_grams)", "item2 (estimated_grams)"],
  "portion_notes": "brief explanation of how portions were estimated"
}''';
}
