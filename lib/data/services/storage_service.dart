import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/app_logger.dart';

class StorageService {

  Future<String> uploadMealImage(
      String userId, String fileName, File file) async {
    log.i('[Storage] Uploading meal image: $fileName');
    log.d('[Storage] User: $userId');
    log.d('[Storage] File path: ${file.path}');
    log.d('[Storage] File size: ${await file.length()} bytes');

    final dio = Dio();
    final formData = FormData.fromMap({
      'upload_preset': AppConfig.cloudinaryUploadPreset,
      'folder': 'users/$userId/meals',
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    try {
      final stopwatch = Stopwatch()..start();
      final response = await dio.post(
        'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload',
        data: formData,
      );
      stopwatch.stop();

      final url = response.data['secure_url'] as String;
      log.i('[Storage] Upload complete in ${stopwatch.elapsedMilliseconds}ms');
      log.d('[Storage] URL: $url');
      return url;
    } catch (e, stackTrace) {
      log.e('[Storage] Upload failed: $e');
      log.e('[Storage] Stack trace: $stackTrace');
      rethrow;
    }
  }

}
