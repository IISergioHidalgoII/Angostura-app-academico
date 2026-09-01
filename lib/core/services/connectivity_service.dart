import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Servicio para monitorear conectividad a internet
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static bool _isOnline = true;

  /// Obtener estado actual de conectividad
  static bool get isOnline => _isOnline;

  /// Stream de cambios de conectividad
  static Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((result) {
      // Considerar online si hay cualquier tipo de conexión
      final hasConnection =
          result.isNotEmpty && !result.contains(ConnectivityResult.none);
      _isOnline = hasConnection;
      debugPrint(
        hasConnection
            ? '🌐 Conexión restaurada'
            : '📵 Sin conexión - Modo Offline',
      );
      return hasConnection;
    });
  }

  /// Verificar conectividad actual (sin stream)
  static Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final hasConnection =
          result.isNotEmpty && !result.contains(ConnectivityResult.none);
      _isOnline = hasConnection;
      return hasConnection;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }
}
