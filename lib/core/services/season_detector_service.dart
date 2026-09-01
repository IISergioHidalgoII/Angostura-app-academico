import 'package:flutter/foundation.dart';

/// Servicio para detectar la temporada actual basándose en la fecha
class SeasonDetectorService {
  /// Detecta la temporada actual según la fecha del hemisferio sur (Chile)
  static String getCurrentSeason() {
    final now = DateTime.now();
    final month = now.month;

    // Hemisferio Sur (Chile)
    // Verano: Diciembre 21 - Marzo 20
    // Otoño: Marzo 21 - Junio 20
    // Invierno: Junio 21 - Septiembre 20
    // Primavera: Septiembre 21 - Diciembre 20

    if (month == 12 || month <= 3) {
      // Diciembre, Enero, Febrero, Marzo
      if (month == 3 && now.day >= 21) {
        return 'otoño';
      }
      return 'verano';
    } else if (month >= 4 && month <= 6) {
      // Abril, Mayo, Junio
      if (month == 6 && now.day >= 21) {
        return 'invierno';
      }
      return 'otoño';
    } else if (month >= 7 && month <= 9) {
      // Julio, Agosto, Septiembre
      if (month == 9 && now.day >= 21) {
        return 'primavera';
      }
      return 'invierno';
    } else {
      // Octubre, Noviembre, Diciembre (hasta 20)
      if (month == 12 && now.day >= 21) {
        return 'verano';
      }
      return 'primavera';
    }
  }

  /// Obtiene el emoji de la temporada
  static String getSeasonEmoji(String season) {
    switch (season.toLowerCase()) {
      case 'verano':
        return '☀️';
      case 'otoño':
        return '🍂';
      case 'invierno':
        return '❄️';
      case 'primavera':
        return '🌸';
      default:
        return '🌍';
    }
  }

  /// Obtiene el nombre bonito de la temporada
  static String getSeasonDisplayName(String season) {
    switch (season.toLowerCase()) {
      case 'verano':
        return 'Verano';
      case 'otoño':
        return 'Otoño';
      case 'invierno':
        return 'Invierno';
      case 'primavera':
        return 'Primavera';
      default:
        return season;
    }
  }

  /// Log de debug
  static void logCurrentSeason() {
    final season = getCurrentSeason();
    final emoji = getSeasonEmoji(season);
    debugPrint('📅 Temporada actual detectada: $emoji $season');
  }
}
