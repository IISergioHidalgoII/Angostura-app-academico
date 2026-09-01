/// Servicio para gestionar las imágenes de las cartas
/// Mapea códigos de cartas a assets locales
class CardImageService {
  /// Mapeo de códigos de cartas a nombres de archivo (sin extensión)
  static const Map<String, String> _cardCodeToFileName = {
    'ANG-CARD-001': 'carpinteronegro01',
    'ANG-CARD-005': 'zorroculpeo01',
    'ANG-CARD-007': 'huemul01',
    'ANG-CARD-011': 'pehuen01',
  };

  /// Obtiene la ruta del asset de imagen para una carta dada
  ///
  /// Prioridad:
  /// 1. Imagen específica por código (ej: ANG-CARD-001 → carpintero_negro.png)
  /// 2. Imagen por rareza (common.png, rare.png, epic.png, legendary.png)
  /// 3. Imagen placeholder genérica
  static String getCardImage(String? cardCode, String? rarity) {
    // Si hay código de carta, intentar buscar imagen específica
    if (cardCode != null && cardCode.isNotEmpty) {
      final normalizedCode = cardCode.toUpperCase();
      final fileName = _cardCodeToFileName[normalizedCode];

      if (fileName != null) {
        final path = 'assets/images/species/$fileName.png';
        print(
          '🖼️ CardImageService: código "$cardCode" → archivo "$fileName.png"',
        );
        return path;
      }

      // Fallback: usar el código directamente
      print(
        '⚠️ CardImageService: código "$cardCode" NO ENCONTRADO en mapeo, usando fallback',
      );
      return 'assets/images/species/${cardCode.toLowerCase().replaceAll('-', '_')}.png';
    }

    // Si no hay código pero hay rareza, usar imagen por rareza
    if (rarity != null && rarity.isNotEmpty) {
      return 'assets/images/species/${rarity.toLowerCase()}.png';
    }

    // Fallback: imagen genérica
    return 'assets/images/species/placeholder.png';
  }

  /// Verifica si existe una imagen específica para el código de carta
  static bool hasSpecificImage(String? cardCode) {
    if (cardCode == null || cardCode.isEmpty) return false;
    return _cardCodeToFileName.containsKey(cardCode.toUpperCase());
  }

  /// Obtiene el nombre común de la especie desde el código
  static String? getSpeciesName(String? cardCode) {
    if (cardCode == null) return null;

    final normalizedCode = cardCode.toUpperCase();
    final fileName = _cardCodeToFileName[normalizedCode];

    if (fileName != null) {
      // Convertir nombre_de_archivo a "Nombre De Archivo"
      return fileName
          .split('_')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
    }

    return null;
  }

  /// Obtiene todas las rutas de imágenes por rareza
  static Map<String, String> getRarityImages() {
    return {
      'common': 'assets/images/species/common.png',
      'rare': 'assets/images/species/rare.png',
      'epic': 'assets/images/species/epic.png',
      'legendary': 'assets/images/species/legendary.png',
    };
  }
}
