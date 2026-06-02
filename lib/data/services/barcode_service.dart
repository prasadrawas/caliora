import 'package:dio/dio.dart';
import '../../core/utils/app_logger.dart';
import '../models/meal_entry.dart';

class BarcodeService {
  final Dio _dio = Dio();

  Future<MealEntry?> lookupBarcode(String barcode) async {
    log.i('[Barcode] Looking up barcode: $barcode');

    final url = 'https://world.openfoodfacts.org/api/v2/product/$barcode.json';
    log.d('[Barcode] API URL: $url');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await _dio.get(
        url,
        options: Options(headers: {
          'User-Agent': 'Caliora/1.0 (Flutter; contact@caliora.app)',
        }),
      );
      stopwatch.stop();
      log.i('[Barcode] Response received in ${stopwatch.elapsedMilliseconds}ms');

      final data = response.data;
      if (data['status'] != 1 || data['product'] == null) {
        log.w('[Barcode] Product not found for barcode: $barcode');
        return null;
      }

      final product = data['product'] as Map<String, dynamic>;
      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
      final productName = product['product_name'] ?? product['product_name_en'] ?? 'Unknown Product';
      final servingSize = product['serving_size'] ?? product['quantity'] ?? '100g';

      log.d('[Barcode] Product: $productName');
      log.d('[Barcode] Brand: ${product['brands']}');
      log.d('[Barcode] Serving: $servingSize');
      log.d('[Barcode] Nutriments keys: ${nutriments.keys.take(10)}');

      // Use per-serving values if available, otherwise per 100g
      final suffix = nutriments.containsKey('energy-kcal_serving') ? '_serving' : '_100g';
      log.d('[Barcode] Using nutriment suffix: $suffix');

      final meal = MealEntry(
        id: '',
        mealName: productName,
        calories: _getNum(nutriments, 'energy-kcal$suffix').toInt(),
        protein: _getNum(nutriments, 'proteins$suffix'),
        carbs: _getNum(nutriments, 'carbohydrates$suffix'),
        fat: _getNum(nutriments, 'fat$suffix'),
        fiber: _getNum(nutriments, 'fiber$suffix'),
        sugar: _getNum(nutriments, 'sugars$suffix'),
        saturatedFat: _getNum(nutriments, 'saturated-fat$suffix'),
        sodium: _getNum(nutriments, 'sodium$suffix') * 1000, // g to mg
        potassium: _getNum(nutriments, 'potassium$suffix') * 1000,
        calcium: _getNum(nutriments, 'calcium$suffix') * 1000,
        iron: _getNum(nutriments, 'iron$suffix') * 1000,
        magnesium: _getNum(nutriments, 'magnesium$suffix') * 1000,
        vitaminA: _getNum(nutriments, 'vitamin-a$suffix') * 1000000, // g to mcg
        vitaminC: _getNum(nutriments, 'vitamin-c$suffix') * 1000, // g to mg
        vitaminD: _getNum(nutriments, 'vitamin-d$suffix') * 1000000,
        vitaminB12: _getNum(nutriments, 'vitamin-b12$suffix') * 1000000,
        servingSize: servingSize,
        mealType: MealEntry.mealTypeFromTime(DateTime.now()),
        itemsDetected: [
          if (product['brands'] != null) product['brands'],
          productName,
        ],
      );

      log.i('[Barcode] MealEntry created: ${meal.mealName} (${meal.calories} kcal)');
      return meal;
    } on DioException catch (e) {
      log.e('[Barcode] DioException: ${e.type}');
      log.e('[Barcode] Status: ${e.response?.statusCode}');
      log.e('[Barcode] Message: ${e.message}');
      throw BarcodeException('Failed to lookup barcode: ${e.message}');
    } catch (e, stackTrace) {
      log.e('[Barcode] Unexpected error: $e');
      log.e('[Barcode] Stack trace: $stackTrace');
      throw BarcodeException('Failed to lookup barcode: $e');
    }
  }

  double _getNum(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val == null) return 0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0;
  }
}

class BarcodeException implements Exception {
  final String message;
  BarcodeException(this.message);

  @override
  String toString() => message;
}
