import 'package:flutter/material.dart';

/// Tema de colores según la temporada
class SeasonTheme {
  // Colores base que no cambian
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFFFFFFFF);

  /// Obtiene los colores de la temporada actual
  static SeasonColors getColorsForSeason(String season) {
    switch (season.toLowerCase()) {
      case 'verano':
        return SeasonColors(
          primary: const Color(0xFFFFB300), // Amarillo dorado
          secondary: const Color(0xFFFF6F00), // Naranja
          accent: const Color(0xFFFF8A65),
          gradient1: const Color(0xFFFFB300),
          gradient2: const Color(0xFFFF6F00),
          cardBackground: const Color(0xFFFFF4CC), // Amarillo más visible
        );

      case 'otoño':
        return SeasonColors(
          primary: const Color(0xFFD84315), // Rojo otoñal
          secondary: const Color(0xFFBF360C), // Marrón rojizo
          accent: const Color(0xFFFF7043),
          gradient1: const Color(0xFFD84315),
          gradient2: const Color(0xFFBF360C),
          cardBackground: const Color(0xFFFFE6CC), // Naranja más visible
        );

      case 'invierno':
        return SeasonColors(
          primary: const Color(0xFF1565C0), // Azul profundo
          secondary: const Color(0xFF0D47A1), // Azul oscuro
          accent: const Color(0xFF42A5F5),
          gradient1: const Color(0xFF1565C0),
          gradient2: const Color(0xFF0D47A1),
          cardBackground: const Color(0xFFD4E8F7), // Azul más visible
        );

      case 'primavera':
        return SeasonColors(
          primary: const Color(0xFFE91E63), // Rosa
          secondary: const Color(0xFFC2185B), // Rosa oscuro
          accent: const Color(0xFFF06292),
          gradient1: const Color(0xFFE91E63),
          gradient2: const Color(0xFFC2185B),
          cardBackground: const Color(0xFFFAD4E4), // Rosa más visible
        );

      default:
        // Verde por defecto (tema original)
        return SeasonColors(
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF1B5E20),
          accent: const Color(0xFF66BB6A),
          gradient1: const Color(0xFF2E7D32),
          gradient2: const Color(0xFF1B5E20),
          cardBackground: const Color(0xFFF1F8E9), // Verde muy claro
        );
    }
  }
}

/// Clase para almacenar los colores de una temporada
class SeasonColors {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color gradient1;
  final Color gradient2;
  final Color cardBackground; // Fondo sutil para las cartas

  const SeasonColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.gradient1,
    required this.gradient2,
    required this.cardBackground,
  });

  /// Crea un degradado lineal con los colores de la temporada
  LinearGradient get gradient {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [gradient1, gradient2],
    );
  }
}
