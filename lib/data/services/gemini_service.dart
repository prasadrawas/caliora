import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import '../../core/config/app_config.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_logger.dart';

class GeminiService {
  final String _apiKey;
  final Dio _dio = Dio();

  GeminiService({required String apiKey}) : _apiKey = apiKey;

  /// Step 1: Analyze food image — identifies items, portions, AND nutrition.
  /// Step 2 (optional): calculateNutrition() recalculates after user edits items.
  Future<GeminiResult?> analyzeFood(File imageFile, {String notes = ''}) async {
    log.i('[Gemini] Starting food analysis');
    log.d('[Gemini] Image path: ${imageFile.path}');
    final originalSize = await imageFile.length();
    log.d('[Gemini] Original image size: $originalSize bytes');
    log.d('[Gemini] User notes: ${notes.isEmpty ? "(none)" : notes}');

    final compressedBytes = await _compressImage(imageFile);
    final base64Image = base64Encode(compressedBytes);
    log.d('[Gemini] Compressed size: ${compressedBytes.length} bytes (${(compressedBytes.length / originalSize * 100).toInt()}% of original)');

    var promptText = AppStrings.geminiPrompt;
    if (notes.isNotEmpty) {
      promptText += '\n\nUser notes about this meal: $notes';
    }

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/${AppConfig.geminiModel}:generateContent?key=$_apiKey';

    log.i('[Gemini] Sending request to ${AppConfig.geminiModel}');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await _dio.post(
        url,
        data: {
          'contents': [
            {
              'parts': [
                {'text': promptText},
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  }
                },
              ]
            }
          ],
          'generationConfig': {
            'temperature': AppConfig.geminiTemperature,
            'maxOutputTokens': AppConfig.geminiMaxTokens,
          },
        },
      );
      stopwatch.stop();

      log.i('[Gemini] Response received in ${stopwatch.elapsedMilliseconds}ms');
      log.d('[Gemini] Status code: ${response.statusCode}');

      final text = response.data['candidates']?[0]?['content']?['parts']?[0]
          ?['text'] as String?;

      if (text == null) {
        log.w('[Gemini] Response text is null');
        return null;
      }

      log.d('[Gemini] Raw response:\n$text');

      String cleanJson = text.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.replaceAll(RegExp(r'^```\w*\n?'), '');
        cleanJson = cleanJson.replaceAll(RegExp(r'\n?```$'), '');
      }

      final decoded = jsonDecode(cleanJson);
      if (decoded is! Map<String, dynamic>) {
        log.e('[Gemini] Response is not a JSON object');
        return null;
      }
      final json = decoded;

      final itemsRaw = List<String>.from(json['items_detected'] ?? []);
      final items = itemsRaw.map((s) => DetectedItem.fromString(s)).toList();
      final portionNotes = json['portion_notes'] as String? ?? '';

      final nutrition = NutritionResult(
        mealName: json['meal_name'] ?? 'Unknown Meal',
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
        servingSize: json['serving_size'] ?? '1 serving',
      );

      log.i('[Gemini] ${nutrition.mealName}: ${nutrition.calories} kcal, ${items.length} items');

      return GeminiResult(
        nutrition: nutrition,
        items: items,
        confidence: json['confidence'] as String? ?? 'medium',
        portionNotes: portionNotes,
      );
    } on DioException catch (e) {
      log.e('[Gemini] DioException: ${e.type}');
      log.e('[Gemini] Status: ${e.response?.statusCode}');
      log.e('[Gemini] Body: ${e.response?.data}');
      final errorMsg = e.response?.data?['error']?['message'] ??
          e.message ??
          'Unknown error';
      throw GeminiAnalysisException('Failed to analyze food: $errorMsg');
    } catch (e, stackTrace) {
      log.e('[Gemini] Error: $e');
      log.e('[Gemini] Stack: $stackTrace');
      throw GeminiAnalysisException('Failed to analyze food: $e');
    }
  }

  Future<Uint8List> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      log.w('[Gemini] Could not decode image, using original');
      return bytes;
    }

    log.d('[Gemini] Original dimensions: ${image.width}x${image.height}');

    img.Image resized;
    final maxW = AppConfig.imageMaxWidth;
    if (image.width > maxW || image.height > maxW) {
      resized = img.copyResize(
        image,
        width: image.width > image.height ? maxW : null,
        height: image.height >= image.width ? maxW : null,
        interpolation: img.Interpolation.linear,
      );
      log.d('[Gemini] Resized to: ${resized.width}x${resized.height}');
    } else {
      resized = image;
    }

    final compressed = Uint8List.fromList(
        img.encodeJpg(resized, quality: AppConfig.imageCompressionQuality));
    return compressed;
  }

  /// Calculate all 16 nutrients from a list of items (text-only, no image).
  /// Used after user reviews/edits the detected items.
  Future<NutritionResult?> calculateNutrition(List<DetectedItem> items) async {
    log.i('[Gemini] Calculating nutrition for ${items.length} items');

    final itemsList = items.map((i) => '- ${i.name}: ${i.quantity}').join('\n');

    final prompt = '''You are an expert nutritionist. Calculate the complete nutritional content for this meal based on the following items and quantities.

Use standard nutritional databases (USDA FoodData Central, IFCT for Indian foods). Consider typical cooking methods. Be conservative — slightly overestimate rather than underestimate.

Items:
$itemsList

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
  "serving_size": "total weight in grams",
  "confidence": "high/medium/low",
  "items_detected": ["item1 (quantity)", "item2 (quantity)"]
}''';

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/${AppConfig.geminiModel}:generateContent?key=$_apiKey';

    try {
      final stopwatch = Stopwatch()..start();
      final response = await _dio.post(
        url,
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ]
            }
          ],
          'generationConfig': {
            'temperature': AppConfig.geminiTemperature,
            'maxOutputTokens': AppConfig.geminiMaxTokens,
          },
        },
      );
      stopwatch.stop();
      log.i('[Gemini] Nutrition calculated in ${stopwatch.elapsedMilliseconds}ms');

      final text = response.data['candidates']?[0]?['content']?['parts']?[0]
          ?['text'] as String?;
      if (text == null) return null;

      log.d('[Gemini] Raw response:\n$text');

      String cleanJson = text.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.replaceAll(RegExp(r'^```\w*\n?'), '');
        cleanJson = cleanJson.replaceAll(RegExp(r'\n?```$'), '');
      }

      final decoded = jsonDecode(cleanJson);
      if (decoded is! Map<String, dynamic>) return null;
      final json = decoded;

      final result = NutritionResult(
        mealName: json['meal_name'] ?? 'Meal',
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
        servingSize: json['serving_size'] ?? '1 serving',
      );

      log.i('[Gemini] Result: ${result.mealName} — ${result.calories} kcal');
      return result;
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error']?['message'] ?? e.message ?? 'Unknown error';
      throw GeminiAnalysisException('Nutrition calculation failed: $errorMsg');
    } catch (e) {
      throw GeminiAnalysisException('Nutrition calculation failed: $e');
    }
  }
}

class NutritionResult {
  final String mealName;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double saturatedFat;
  final double sodium;
  final double potassium;
  final double calcium;
  final double iron;
  final double magnesium;
  final double vitaminA;
  final double vitaminC;
  final double vitaminD;
  final double vitaminB12;
  final String servingSize;

  NutritionResult({
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.saturatedFat,
    required this.sodium,
    required this.potassium,
    required this.calcium,
    required this.iron,
    required this.magnesium,
    required this.vitaminA,
    required this.vitaminC,
    required this.vitaminD,
    required this.vitaminB12,
    required this.servingSize,
  });
}

class DetectedItem {
  String name;
  String quantity;

  DetectedItem({required this.name, required this.quantity});

  factory DetectedItem.fromString(String s) {
    final match = RegExp(r'^(.+?)\s*\((.+?)\)\s*$').firstMatch(s);
    if (match != null) {
      return DetectedItem(
          name: match.group(1)!.trim(), quantity: match.group(2)!.trim());
    }
    return DetectedItem(name: s.trim(), quantity: '1 serving');
  }

  @override
  String toString() => '$name ($quantity)';
}

class GeminiResult {
  final NutritionResult nutrition;
  final List<DetectedItem> items;
  final String confidence;
  final String portionNotes;

  GeminiResult({
    required this.nutrition,
    required this.items,
    this.confidence = 'medium',
    this.portionNotes = '',
  });
}

class GeminiAnalysisException implements Exception {
  final String message;
  GeminiAnalysisException(this.message);

  @override
  String toString() => message;
}
