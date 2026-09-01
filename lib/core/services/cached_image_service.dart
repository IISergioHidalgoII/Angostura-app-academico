import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio para manejar caché de imágenes con estructura organizada
/// Carpetas: cartas/, mercado/, areas/
class CachedImageService {
  static const String _cacheBasePath = 'image_cache';

  /// Tipos de caché soportados
  static const String cartas = 'cartas';
  static const String mercado = 'mercado';
  static const String areas = 'areas';

  /// Obtiene el directorio base de caché
  static Future<Directory> getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheBasePath');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Obtiene el directorio para un tipo específico (cartas, mercado, areas)
  static Future<Directory> getCategoryDirectory(String category) async {
    final baseDir = await getCacheDirectory();
    final categoryDir = Directory('${baseDir.path}/$category');
    if (!await categoryDir.exists()) {
      await categoryDir.create(recursive: true);
    }
    return categoryDir;
  }

  /// Widget para mostrar imagen de carta con caché
  static Widget buildCardImage({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    String? cardId,
  }) {
    return _buildCachedImage(
      imageUrl: imageUrl,
      category: cartas,
      width: width,
      height: height,
      fit: fit,
      placeholder: const Icon(Icons.style, size: 48, color: Colors.grey),
      errorWidget: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
    );
  }

  /// Widget para mostrar imagen de item del mercado con caché
  static Widget buildMarketItemImage({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    String? itemId,
  }) {
    return _buildCachedImage(
      imageUrl: imageUrl,
      category: mercado,
      width: width,
      height: height,
      fit: fit,
      placeholder: const Icon(Icons.shopping_bag, size: 48, color: Colors.grey),
      errorWidget: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
    );
  }

  /// Widget para mostrar imagen de área con caché
  static Widget buildAreaImage({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    String? areaId,
  }) {
    return _buildCachedImage(
      imageUrl: imageUrl,
      category: areas,
      width: width,
      height: height,
      fit: fit,
      placeholder: const Icon(Icons.map, size: 48, color: Colors.grey),
      errorWidget: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
    );
  }

  /// Widget base para imágenes cacheadas
  static Widget _buildCachedImage({
    required String? imageUrl,
    required String category,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: Center(child: placeholder),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              if (height != null && height > 60) ...[
                const SizedBox(height: 8),
                const Text(
                  'Cargando...',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: Center(child: errorWidget),
      ),
      cacheKey: '${category}_${imageUrl.hashCode}',
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  /// Limpia caché de una categoría específica
  static Future<void> clearCategoryCache(String category) async {
    try {
      final categoryDir = await getCategoryDirectory(category);
      if (await categoryDir.exists()) {
        await categoryDir.delete(recursive: true);
        await categoryDir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Error limpiando caché de $category: $e');
    }
  }

  /// Limpia todo el caché de imágenes
  static Future<void> clearAllCache() async {
    try {
      final cacheDir = await getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Error limpiando todo el caché: $e');
    }
  }

  /// Obtiene el tamaño del caché en MB
  static Future<double> getCacheSize() async {
    try {
      final cacheDir = await getCacheDirectory();
      if (!await cacheDir.exists()) return 0;

      int totalSize = 0;
      await for (var entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize / (1024 * 1024); // Convertir a MB
    } catch (e) {
      debugPrint('Error calculando tamaño de caché: $e');
      return 0;
    }
  }
}
