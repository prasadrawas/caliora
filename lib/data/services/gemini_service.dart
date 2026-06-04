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
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

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

    final requestData = {
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
    };

    try {
      final response = await _postWithFallback(requestData);

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
    } on GeminiAnalysisException {
      rethrow;
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

    final requestData = {
      'contents': [
        {'parts': [{'text': prompt}]}
      ],
      'generationConfig': {
        'temperature': AppConfig.geminiTemperature,
        'maxOutputTokens': AppConfig.geminiMaxTokens,
      },
    };

    try {
      final response = await _postWithFallback(requestData);

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
    } on GeminiAnalysisException {
      rethrow;
    } catch (e) {
      throw GeminiAnalysisException('Recalculation failed: $e');
    }
  }

  /// POST to Gemini API with automatic model fallback on 429 (quota exceeded).
  Future<Response> _postWithFallback(Map<String, dynamic> requestData) async {
    final models = AppConfig.geminiModels;
    DioException? lastError;

    for (final model in models) {
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey';
      try {
        final stopwatch = Stopwatch()..start();
        final response = await _dio.post(url, data: requestData);
        stopwatch.stop();
        log.i('[Gemini] $model responded in ${stopwatch.elapsedMilliseconds}ms');
        return response;
      } on DioException catch (e) {
        lastError = e;
        final status = e.response?.statusCode;
        if (status == 429 || status == 503) {
          log.w('[Gemini] $model quota exceeded (HTTP $status), trying next model...');
          continue;
        }
        // Non-quota error — don't retry
        final errorMsg = e.response?.data?['error']?['message'] ?? e.message ?? 'Unknown error';
        throw GeminiAnalysisException('Analysis failed: $errorMsg');
      }
    }

    // All models exhausted
    final errorMsg = lastError?.response?.data?['error']?['message'] ?? 'All models quota exceeded';
    throw GeminiAnalysisException('All AI models are currently at capacity. Please try again later. ($errorMsg)');
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
