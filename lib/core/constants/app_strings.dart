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

  // Gemini prompt
  static const String geminiPrompt = '''Analyze this food image and return ONLY a JSON object with no extra text, no markdown, no code blocks. Format:
{
  "meal_name": "string",
  "calories": number,
  "protein_g": number,
  "carbs_g": number,
  "fat_g": number,
  "fiber_g": number,
  "serving_size": "string",
  "confidence": "high/medium/low",
  "items_detected": ["list of food items"]
}''';
}
