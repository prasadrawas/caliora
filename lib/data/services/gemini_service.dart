import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants/app_strings.dart';
import '../models/meal_entry.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService({required String apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );
  }

  Future<MealEntry?> analyzeFood(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final imagePart = DataPart('image/jpeg', imageBytes);

    final prompt = TextPart(AppStrings.geminiPrompt);

    try {
      final response = await _model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      final text = response.text;
      if (text == null) return null;

      // Clean up response - remove markdown code blocks if present
      String cleanJson = text.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.replaceAll(RegExp(r'^```\w*\n?'), '');
        cleanJson = cleanJson.replaceAll(RegExp(r'\n?```$'), '');
      }

      final json = jsonDecode(cleanJson) as Map<String, dynamic>;

      return MealEntry(
        id: '',
        mealName: json['meal_name'] ?? 'Unknown Food',
        calories: (json['calories'] ?? 0).toInt(),
        protein: (json['protein_g'] ?? 0).toDouble(),
        carbs: (json['carbs_g'] ?? 0).toDouble(),
        fat: (json['fat_g'] ?? 0).toDouble(),
        fiber: (json['fiber_g'] ?? 0).toDouble(),
        servingSize: json['serving_size'] ?? '1 serving',
        mealType: MealEntry.mealTypeFromTime(DateTime.now()),
        itemsDetected: List<String>.from(json['items_detected'] ?? []),
      );
    } catch (e) {
      throw GeminiAnalysisException('Failed to analyze food image: $e');
    }
  }
}

class GeminiAnalysisException implements Exception {
  final String message;
  GeminiAnalysisException(this.message);

  @override
  String toString() => message;
}
