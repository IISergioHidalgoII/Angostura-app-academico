import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para gestionar el modo desarrollador
/// Restringe acceso a funciones de debug/admin según whitelist de emails
class DevModeService {
  static const Set<String> _devEmails = {
    'ryleth.2001@gmail.com',
    // 'otro-dev@example.com',
    // 'tercer-dev@example.com',
  };

  /// Verifica si el usuario actual es desarrollador
  /// Retorna true si el email del usuario está en la whitelist
  static bool isDevUser() {
    try {
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (email == null || email.isEmpty) return false;

      return _devEmails.contains(email.toLowerCase());
    } catch (e) {
      // Si hay error leyendo usuario, denegar acceso por seguridad
      return false;
    }
  }

  /// Email del usuario actual (para mostrar en UI si es necesario)
  static String? getCurrentUserEmail() {
    try {
      return Supabase.instance.client.auth.currentUser?.email;
    } catch (e) {
      return null;
    }
  }
}
