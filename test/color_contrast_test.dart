import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas de contraste de colores para accesibilidad
/// Verifica que los colores de fondo tengan suficiente contraste con texto oscuro
void main() {
  group('Color Contrast Tests', () {
    // Colores de fondo de temporada
    const veranoBackground = Color(0xFFFFF9E6); // Amarillo muy claro
    const otonioBackground = Color(0xFFFFF3E0); // Naranja muy claro
    const inviernoBackground = Color(0xFFE3F2FD); // Azul muy claro
    const primaveraBackground = Color(0xFFFCE4EC); // Rosa muy claro
    const defaultBackground = Color(0xFFF1F8E9); // Verde muy claro

    // Colores de texto comunes
    const textBlack87 = Color(0xDD000000); // Colors.black87

    test('Verano background - contraste con texto negro', () {
      final contrast = _calculateContrast(veranoBackground, textBlack87);
      print('Verano + Negro87: ${contrast.toStringAsFixed(2)}:1');
      expect(
        contrast,
        greaterThan(4.5),
        reason: 'Debe cumplir WCAG AA (4.5:1)',
      );
    });

    test('Otonio background - contraste con texto negro', () {
      final contrast = _calculateContrast(otonioBackground, textBlack87);
      print('Otonio + Negro87: ${contrast.toStringAsFixed(2)}:1');
      expect(
        contrast,
        greaterThan(4.5),
        reason: 'Debe cumplir WCAG AA (4.5:1)',
      );
    });

    test('Invierno background - contraste con texto negro', () {
      final contrast = _calculateContrast(inviernoBackground, textBlack87);
      print('Invierno + Negro87: ${contrast.toStringAsFixed(2)}:1');
      expect(
        contrast,
        greaterThan(4.5),
        reason: 'Debe cumplir WCAG AA (4.5:1)',
      );
    });

    test('Primavera background - contraste con texto negro', () {
      final contrast = _calculateContrast(primaveraBackground, textBlack87);
      print('Primavera + Negro87: ${contrast.toStringAsFixed(2)}:1');
      expect(
        contrast,
        greaterThan(4.5),
        reason: 'Debe cumplir WCAG AA (4.5:1)',
      );
    });

    test('Default background - contraste con texto negro', () {
      final contrast = _calculateContrast(defaultBackground, textBlack87);
      print('Default + Negro87: ${contrast.toStringAsFixed(2)}:1');
      expect(
        contrast,
        greaterThan(4.5),
        reason: 'Debe cumplir WCAG AA (4.5:1)',
      );
    });
  });
}

/// Calcula el ratio de contraste entre dos colores según WCAG 2.0
double _calculateContrast(Color background, Color foreground) {
  final bgLuminance = _calculateLuminance(background);
  final fgLuminance = _calculateLuminance(foreground);

  final lighter = bgLuminance > fgLuminance ? bgLuminance : fgLuminance;
  final darker = bgLuminance > fgLuminance ? fgLuminance : bgLuminance;

  return (lighter + 0.05) / (darker + 0.05);
}

/// Calcula la luminancia relativa de un color según WCAG 2.0
double _calculateLuminance(Color color) {
  double toLinear(int channel) {
    final c = channel / 255.0;
    return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = toLinear(color.red);
  final g = toLinear(color.green);
  final b = toLinear(color.blue);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Helper para pow
double pow(double base, double exponent) {
  double result = 1.0;
  for (int i = 0; i < exponent.toInt(); i++) {
    result *= base;
  }
  return result;
}
