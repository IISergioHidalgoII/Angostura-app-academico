class AppConstants {
  static const String appName = 'AngosturApp';
  static const String appVersion = '1.0.0';

  // Keys para almacenamiento local
  static const String userDataKey = 'user_data';
  static const String onboardingCompletedKey = 'onboarding_completed';
  static const String selectedSiteKey = 'selected_site';
  static const String householdDataKey = 'household_data';

  // Configuración de UI
  static const double borderRadius = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingMedium = 16.0;
  static const double paddingSmall = 8.0;

  // Colores del tema
  static const int primaryGreen = 0xFF2E7D32;
  static const int secondaryGreen = 0xFF4CAF50;
  static const int accentOrange = 0xFFFF8F00;
  static const int backgroundLight = 0xFFE8F5E8;
}

class UserType {
  static const String guest = 'guest';
  static const String family = 'family';
}

class CardRarity {
  static const String common = 'común';
  static const String uncommon = 'poco_común';
  static const String rare = 'raro';
  static const String epic = 'épico';
}

// Temporadas (normalizadas: minúsculas, sin acentos)
class Season {
  static const String verano = 'verano';
  static const String otono = 'otono';
  static const String invierno = 'invierno';
  static const String primavera = 'primavera';

  static const List<String> all = [verano, otono, invierno, primavera];

  // Labels para UI
  static const Map<String, String> labels = {
    verano: 'Verano',
    otono: 'Otoño',
    invierno: 'Invierno',
    primavera: 'Primavera',
  };

  /// Normaliza una temporada a formato estándar (minúsculas, sin acentos)
  static String? normalize(String? input) {
    if (input == null || input.isEmpty) return null;
    final normalized = input.toLowerCase().trim();

    // Mapear variaciones comunes
    if (normalized.contains('verano')) return verano;
    if (normalized.contains('oto') ||
        normalized.contains('autumn') ||
        normalized.contains('fall')) {
      return otono;
    }
    if (normalized.contains('invierno') || normalized.contains('winter')) {
      return invierno;
    }
    if (normalized.contains('primavera') || normalized.contains('spring')) {
      return primavera;
    }

    return null;
  }
}

// Estados de conservación
class ConservationStatus {
  static const String normal = 'normal';
  static const String amenazado = 'amenazado';
  static const String extincion = 'extincion';

  // Colores de alerta (usar del theme si existen)
  static const int warningYellow = 0xFFFFA726; // Amenazado
  static const int dangerRed = 0xFFE53935; // En extinción
}
