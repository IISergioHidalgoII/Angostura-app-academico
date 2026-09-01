import 'package:flutter/material.dart';
import '../../../core/services/card_image_service.dart';

/// Modelo de especie con toda la información para las cartas
class SpeciesCard {
  final String id;
  final String code; // ej: ANG001
  final String commonName; // ej: Huemul
  final String scientificName; // ej: Hippocamelus bisulcus
  final String? imageAsset; // assets/images/species/huemul.png
  final String? imageUrl; // URL de imagen desde Supabase Storage
  final Rarity rarity;
  final String description;
  final String habitat;
  final String family;
  final String weight;
  final String height;
  final String diet;
  final String conservationStatus;
  final String lifeExpectancy;
  final List<String> curiosities;
  final String? conservationDetails;
  final DateTime? unlockedAt;
  final String? source; // 'qr_scan', 'achievement', etc.
  final bool locked; // true = bloqueada, false = desbloqueada

  // Nuevos campos opcionales (nullable para compatibilidad con datos existentes)
  final String? season; // 'verano', 'invierno', 'otono', 'primavera' o null
  final String? threatLevel; // 'normal', 'amenazado', 'extincion' o null
  final String? cardType; // 'fauna', 'flora' o null

  const SpeciesCard({
    required this.id,
    required this.code,
    required this.commonName,
    required this.scientificName,
    this.imageAsset,
    this.imageUrl,
    required this.rarity,
    required this.description,
    required this.habitat,
    required this.family,
    required this.weight,
    required this.height,
    required this.diet,
    required this.conservationStatus,
    required this.lifeExpectancy,
    this.curiosities = const [],
    this.conservationDetails,
    this.unlockedAt,
    this.source,
    this.locked = false, // Por defecto desbloqueada
    this.season, // Opcional - nullable
    this.threatLevel, // Opcional - nullable
    this.cardType, // Opcional - nullable
  });

  /// Crea una SpeciesCard desde datos de Supabase
  factory SpeciesCard.fromSupabase(Map<String, dynamic> data) {
    final cardData = data['cards'] ?? data;
    final isLocked = data['locked'] == true; // Leer estado locked

    final code = cardData['code']?.toString() ?? '';
    final title = cardData['title']?.toString() ?? 'Desconocido';
    final scientificName = cardData['scientific_name']?.toString() ?? '';
    final technicalData = cardData['technical_data']?.toString() ?? '';
    final curiosities = cardData['curiosities']?.toString() ?? '';
    final cardType = cardData['card_type']?.toString();
    final seasonName = cardData['seasons']?['name']?.toString();

    print('🃏 SpeciesCard.fromSupabase:');
    print('   - Título: "$title" (código: $code)');
    print('   - Científico: "$scientificName"');
    print('   - Tipo: "$cardType"');
    print(
      '   - Temporada RAW: "${cardData['seasons']}" -> Parsed: "${_parseSeason(seasonName)}"',
    );
    print(
      '   - Technical Data: ${technicalData.isEmpty ? "VACÍO" : "${technicalData.substring(0, technicalData.length > 30 ? 30 : technicalData.length)}..."} ',
    );

    return SpeciesCard(
      id: cardData['id']?.toString() ?? '',
      code: code,
      commonName: title,
      scientificName: scientificName,
      imageAsset: _getImageAsset(cardData['code']),
      imageUrl: cardData['image_url']?.toString(),
      rarity: _parseRarity(cardData['rarity']),
      description: cardData['description']?.toString() ?? '',
      // Los campos individuales ahora vienen del technical_data
      habitat: technicalData,
      family: '',
      weight: '',
      height: '',
      diet: '',
      conservationStatus: '',
      lifeExpectancy: '',
      curiosities: _parseCuriositiesText(curiosities),
      conservationDetails: null,
      unlockedAt: data['unlocked_at'] != null
          ? DateTime.parse(data['unlocked_at'].toString())
          : null,
      source: data['source']?.toString(),
      locked: isLocked,
      season: _parseSeason(cardData['seasons']?['name']),
      threatLevel: _parseThreatLevel(cardData),
      cardType: cardType,
    );
  }

  static String _getImageAsset(String? code) {
    // Usar CardImageService para obtener la ruta correcta del asset
    // Esto mapea ANG-CARD-001 -> carpinteronegro01.png, etc.
    return CardImageService.getCardImage(code, null);
  }

  static Rarity _parseRarity(dynamic rarity) {
    if (rarity == null) return Rarity.common;

    final rarityStr = rarity.toString().toLowerCase();
    switch (rarityStr) {
      case 'rare':
      case 'rara':
        return Rarity.rare;
      case 'epic':
      case 'epica':
      case 'épica':
        return Rarity.epic;
      case 'legendary':
      case 'legendaria':
        return Rarity.legendary;
      default:
        return Rarity.common;
    }
  }

  /// Parsea curiosidades desde el nuevo formato de texto libre
  static List<String> _parseCuriositiesText(dynamic curiosities) {
    if (curiosities == null || curiosities.toString().isEmpty) return [];

    // Retornar como un solo elemento para mostrarlo como texto libre
    return [curiosities.toString()];
  }

  /// Obtiene el color asociado a la rareza
  Color get rarityColor {
    switch (rarity) {
      case Rarity.common:
        return const Color(0xFF4CAF50); // Verde
      case Rarity.rare:
        return const Color(0xFF2196F3); // Azul
      case Rarity.epic:
        return const Color(0xFF9C27B0); // Morado
      case Rarity.legendary:
        return const Color(0xFFFFD700); // Dorado
    }
  }

  /// Obtiene el gradiente de fondo para la carta
  LinearGradient get rarityGradient {
    switch (rarity) {
      case Rarity.common:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0E0E0), Color(0xFFF5F5F5)],
        );
      case Rarity.rare:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBBDEFB), Color(0xFFE3F2FD)],
        );
      case Rarity.epic:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE1BEE7), Color(0xFFF3E5F5)],
        );
      case Rarity.legendary:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE082), Color(0xFFFFF9C4)],
        );
    }
  }

  /// Obtiene el texto de rareza localizado
  String get rarityText {
    switch (rarity) {
      case Rarity.common:
        return 'COMÚN';
      case Rarity.rare:
        return 'RARA';
      case Rarity.epic:
        return 'ÉPICA';
      case Rarity.legendary:
        return 'LEGENDARIA';
    }
  }

  /// Obtiene el emoji de conservación
  String get conservationEmoji {
    final status = conservationStatus.toLowerCase();
    if (status.contains('peligro') || status.contains('danger')) return '🔴';
    if (status.contains('vulnerable')) return '🟡';
    if (status.contains('preocupación') || status.contains('concern')) {
      return '🟢';
    }
    return '⚪';
  }

  /// Parse seguro de temporada con normalización
  static String? _parseSeason(dynamic input) {
    if (input == null) return null;

    final season = input.toString().toLowerCase().trim();

    // Normalizar variaciones comunes
    if (season.contains('verano') || season.contains('summer')) return 'verano';
    if (season.contains('oto') ||
        season.contains('autumn') ||
        season.contains('fall')) {
      return 'otono';
    }
    if (season.contains('invierno') || season.contains('winter')) {
      return 'invierno';
    }
    if (season.contains('primavera') || season.contains('spring')) {
      return 'primavera';
    }

    return null; // Si no reconoce la temporada, devuelve null
  }

  /// Parse seguro de nivel de amenaza desde múltiples campos posibles
  static String? _parseThreatLevel(Map<String, dynamic> data) {
    // Buscar en diferentes campos posibles
    final threatLevel =
        data['threat_level']?.toString() ??
        data['threatLevel']?.toString() ??
        data['conservation_threat']?.toString();

    if (threatLevel != null) {
      final normalized = threatLevel.toLowerCase().trim();
      if (normalized.contains('extinc') || normalized.contains('critical')) {
        return 'extincion';
      }
      if (normalized.contains('amenaz') ||
          normalized.contains('endanger') ||
          normalized.contains('vulnerable') ||
          normalized.contains('threat')) {
        return 'amenazado';
      }
      if (normalized.contains('normal') ||
          normalized.contains('stable') ||
          normalized.contains('least concern')) {
        return 'normal';
      }
    }

    // Fallback: intentar detectar desde conservation_status
    final status = data['conservation_status']?.toString() ?? '';
    final statusLower = status.toLowerCase();

    if (statusLower.contains('peligro crític') ||
        statusLower.contains('critically')) {
      return 'extincion';
    }
    if (statusLower.contains('peligro') ||
        statusLower.contains('endanger') ||
        statusLower.contains('vulnerable') ||
        statusLower.contains('amenaz')) {
      return 'amenazado';
    }

    return null; // Sin datos suficientes -> no mostrar badge
  }
}

/// Enum de rareza de cartas
enum Rarity {
  common, // ⭐ - Verde
  rare, // ⭐⭐ - Azul
  epic, // ⭐⭐⭐ - Morado
  legendary, // 👑 - Dorado
}
