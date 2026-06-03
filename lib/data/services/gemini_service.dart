import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import '../../core/config/app_config.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_logger.dart';
import '../models/analyzed_item.dart';

class GeminiService {
  final String _apiKey;
  final Dio _dio = Dio();

  GeminiService({required String apiKey}) : _apiKey = apiKey;

  /// Analyze food image — returns per-item nutrition breakdown.
  Future<GeminiResult?> analyzeFood(File imageFile, {String notes = ''}) async {
    log.i('[Gemini] Starting food analysis');
    final originalSize = await imageFile.length();
    log.d('[Gemini] Image size: $originalSize bytes');

    final compressedBytes = await _compressImage(imageFile);
    final base64Image = base64Encode(compressedBytes);
    log.d('[Gemini] Compressed: ${compressedBytes.length} bytes');

    var promptText = AppStrings.geminiPrompt;
    if (notes.isNotEmpty) {
      promptText += '\n\nUser notes: $notes';
    }

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/${AppConfig.geminiModel}:generateContent?key=$_apiKey';

    try {
      final stopwatch = Stopwatch()..start();
      final response = await _dio.post(url, data: {
        'contents': [
          {
            'parts': [
              {'text': promptText},
              {'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image}},
            ]
          }
        ],
        'generationConfig': {
          'temperature': AppConfig.geminiTemperature,
          'maxOutputTokens': AppConfig.geminiMaxTokens,
        },
      });
      stopwatch.stop();
      log.i('[Gemini] Response in ${stopwatch.elapsedMilliseconds}ms');

      final json = _parseResponse(response.data);
      if (json == null) return null;

      final itemsJson = json['items'] as List? ?? [];
      final items = itemsJson
          .map((i) => AnalyzedItem.fromJson(i as Map<String, dynamic>))
          .toList();

      log.i('[Gemini] ${json['meal_name']}: ${items.length} items');
      for (final item in items) {
        log.d('[Gemini]   ${item.name} (${item.portion}): ${item.calories} kcal');
      }

      return GeminiResult(
        mealName: json['meal_name'] ?? 'Unknown Meal',
        items: items,
        confidence: json['confidence'] ?? 'medium',
      );
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error']?['message'] ?? e.message ?? 'Unknown error';
      throw GeminiAnalysisException('Failed to analyze food: $errorMsg');
    } catch (e, st) {
      log.e('[Gemini] Error: $e\n$st');
      throw GeminiAnalysisException('Failed to analyze food: $e');
    }
  }

  /// Recalculate nutrition for edited items (text-only, no image).
  /// Only recalculates non-user-edited items.
  Future<List<AnalyzedItem>?> recalculateItems(List<AnalyzedItem> items) async {
    final toRecalc = items.where((i) => !i.isUserEdited && i.name.trim().isNotEmpty).toList();
    if (toRecalc.isEmpty) return items;

    log.i('[Gemini] Recalculating ${toRecalc.length} items (${items.length - toRecalc.length} user-edited, preserved)');

    final itemsList = toRecalc.map((i) => '- ${i.name}: ${i.portion}').join('\n');
    final prompt = '''Calculate nutrition per item. Reference USDA/IFCT. Be conservative.

Items:
$itemsList

Return ONLY JSON, no text, no markdown:
{
  "items": [
    {
      "name": "item name",
      "portion": "portion",
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
  ]
}''';

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/${AppConfig.geminiModel}:generateContent?key=$_apiKey';

    try {
      final stopwatch = Stopwatch()..start();
      final response = await _dio.post(url, data: {
        'contents': [
          {'parts': [{'text': prompt}]}
        ],
        'generationConfig': {
          'temperature': AppConfig.geminiTemperature,
          'maxOutputTokens': AppConfig.geminiMaxTokens,
        },
      });
      stopwatch.stop();
      log.i('[Gemini] Recalculation in ${stopwatch.elapsedMilliseconds}ms');

      final json = _parseResponse(response.data);
      if (json == null) return null;

      final recalcItems = (json['items'] as List? ?? [])
          .map((i) => AnalyzedItem.fromJson(i as Map<String, dynamic>))
          .toList();

      // Merge: keep user-edited items, replace recalculated ones
      final result = <AnalyzedItem>[];
      int recalcIdx = 0;
      for (final item in items) {
        if (item.isUserEdited || item.name.trim().isEmpty) {
          result.add(item);
        } else if (recalcIdx < recalcItems.length) {
          result.add(recalcItems[recalcIdx++]);
        } else {
          result.add(item);
        }
      }

      return result;
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error']?['message'] ?? e.message ?? 'Unknown error';
      throw GeminiAnalysisException('Recalculation failed: $errorMsg');
    } catch (e) {
      throw GeminiAnalysisException('Recalculation failed: $e');
    }
  }

  Map<String, dynamic>? _parseResponse(dynamic data) {
    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
    if (text == null) {
      log.w('[Gemini] Response text is null');
      return null;
    }
    log.d('[Gemini] Raw:\n$text');

    String clean = text.trim();
    if (clean.startsWith('```')) {
      clean = clean.replaceAll(RegExp(r'^```\w*\n?'), '');
      clean = clean.replaceAll(RegExp(r'\n?```$'), '');
    }

    final decoded = jsonDecode(clean);
    if (decoded is! Map<String, dynamic>) {
      log.e('[Gemini] Not a JSON object');
      return null;
    }
    return decoded;
  }

  Future<Uint8List> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    img.Image resized;
    final maxW = AppConfig.imageMaxWidth;
    if (image.width > maxW || image.height > maxW) {
      resized = img.copyResize(image,
          width: image.width > image.height ? maxW : null,
          height: image.height >= image.width ? maxW : null,
          interpolation: img.Interpolation.linear);
    } else {
      resized = image;
    }

    return Uint8List.fromList(
        img.encodeJpg(resized, quality: AppConfig.imageCompressionQuality));
  }
}

class GeminiResult {
  final String mealName;
  final List<AnalyzedItem> items;
  final String confidence;

  GeminiResult({
    required this.mealName,
    required this.items,
    this.confidence = 'medium',
  });
}

class GeminiAnalysisException implements Exception {
  final String message;
  GeminiAnalysisException(this.message);

  @override
  String toString() => message;
}
