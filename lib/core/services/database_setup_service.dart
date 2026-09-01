import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseSetupService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Crea households de ejemplo para pruebas
  static Future<void> createSampleHouseholds() async {
    try {
      debugPrint('Creando households de ejemplo...');

      // Verificar si ya existen households de ejemplo
      final existingHouseholds = await _client
          .from('households')
          .select('id')
          .eq('redeem_code', 'ANG251119001');

      if (existingHouseholds.isNotEmpty) {
        debugPrint('Los households de ejemplo ya existen');
        return;
      }

      // Obtener el sitio de Angostura
      final siteResponse = await _client
          .from('sites')
          .select('id')
          .eq('name', 'Parque Angostura')
          .limit(1);

      if (siteResponse.isEmpty) {
        throw Exception('No se encontró el sitio de Angostura');
      }

      final siteId = siteResponse.first['id'] as String;

      // Crear usuario de ejemplo
      final userResponse = await _client
          .from('users')
          .insert({
            'email': 'demo.familia@angostura.cl',
            'display_name': 'Demo Familia',
            'username': 'demo_familia',
          })
          .select()
          .single();

      final userId = userResponse['id'] as String;

      // Crear households de ejemplo
      final householdsData = [
        {
          'site_id': siteId,
          'name': 'Familia González Demo',
          'owner_user_id': userId,
          'redeem_code': 'ANG251119001',
          'activated_at': DateTime.now().toIso8601String(),
        },
        {
          'site_id': siteId,
          'name': 'Exploradores Biobío',
          'owner_user_id': userId,
          'redeem_code': 'ANG251119002',
          'activated_at': DateTime.now().toIso8601String(),
        },
        {
          'site_id': siteId,
          'name': 'Amigos de la Naturaleza',
          'owner_user_id': userId,
          'redeem_code': 'ANG251119003',
          'activated_at': DateTime.now().toIso8601String(),
        },
      ];

      final householdsResponse = await _client
          .from('households')
          .insert(householdsData)
          .select();

      // Agregar el usuario como miembro del primer household
      final firstHouseholdId = householdsResponse.first['id'] as String;
      await _client.from('household_members').insert({
        'household_id': firstHouseholdId,
        'user_id': userId,
        'role': 'owner',
        'display_name': 'Demo Familia',
        'is_child': false,
      });

      debugPrint('Households de ejemplo creados exitosamente');
      debugPrint('Códigos disponibles para pruebas:');
      debugPrint('   - ANG251119001 (Familia González Demo)');
      debugPrint('   - ANG251119002 (Exploradores Biobío)');
      debugPrint('   - ANG251119003 (Amigos de la Naturaleza)');
    } catch (e) {
      debugPrint('Error creando households de ejemplo: $e');
      // Si el usuario ya existe, no es un error crítico
      if (!e.toString().contains(
        'duplicate key value violates unique constraint',
      )) {
        rethrow;
      }
    }
  }

  /// Obtiene la lista de households disponibles para debugging
  static Future<List<Map<String, dynamic>>> getAvailableHouseholds() async {
    try {
      final response = await _client
          .from('households')
          .select('id, name, redeem_code, activated_at')
          .not('redeem_code', 'is', null)
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error obteniendo households: $e');
      return [];
    }
  }

  /// Verifica la conexión a la base de datos
  static Future<bool> checkDatabaseConnection() async {
    try {
      final response = await _client.from('sites').select('count').limit(1);

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Error verificando conexión: $e');
      return false;
    }
  }
}
