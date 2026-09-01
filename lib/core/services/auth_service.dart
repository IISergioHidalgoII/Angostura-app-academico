import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_config.dart';

/// Servicio simplificado de autenticación y creación de usuarios
class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Verifica si hay un usuario autenticado
  static bool get isAuthenticated => _client.auth.currentUser != null;

  /// Obtiene el ID del usuario actual
  static String? get currentUserId => _client.auth.currentUser?.id;

  /// Obtiene el email del usuario actual
  static String? get currentUserEmail => _client.auth.currentUser?.email;

  /// Registra un nuevo usuario como invitado (guest) sin autenticación real
  /// Útil para modo demo/prueba
  static Future<Map<String, dynamic>> createGuestUser({
    required String email,
    String? displayName,
  }) async {
    try {
      debugPrint('🔑 Creando usuario invitado: $email');

      // Generar un ID único para el usuario guest
      final userId = 'guest_${DateTime.now().millisecondsSinceEpoch}';

      // Insertar directamente en la tabla users (sin auth)
      final response = await _client
          .from(SupabaseConfig.usersTable)
          .insert({
            'id': userId,
            'email': email,
            'display_name': displayName ?? email.split('@')[0],
            'username': email.split('@')[0].replaceAll('.', '_'),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      debugPrint('✅ Usuario invitado creado: ${response['id']}');
      return response;
    } catch (e) {
      debugPrint('❌ Error creando usuario invitado: $e');
      rethrow;
    }
  }

  /// Registra un usuario real con autenticación
  static Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      debugPrint('🔑 Registrando usuario: $email');

      // 1. Crear usuario en Supabase Auth
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('No se pudo crear el usuario en auth');
      }

      final userId = authResponse.user!.id;
      debugPrint('✅ Usuario auth creado: $userId');

      // 2. Crear registro en tabla users
      final userResponse = await _client
          .from(SupabaseConfig.usersTable)
          .insert({
            'id': userId,
            'email': email,
            'display_name': displayName ?? email.split('@')[0],
            'username': email.split('@')[0].replaceAll('.', '_'),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      debugPrint('✅ Usuario en tabla creado: ${userResponse['id']}');
      return userResponse;
    } catch (e) {
      debugPrint('❌ Error en signUp: $e');
      rethrow;
    }
  }

  /// Inicia sesión con email y contraseña
  static Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Iniciando sesión: $email');

      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Credenciales inválidas');
      }

      // Obtener datos del usuario de la tabla users
      final userResponse = await _client
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('id', authResponse.user!.id)
          .single();

      debugPrint('✅ Sesión iniciada: ${userResponse['id']}');
      return userResponse;
    } catch (e) {
      debugPrint('❌ Error en signIn: $e');
      rethrow;
    }
  }

  /// Cierra sesión del usuario actual
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      debugPrint('✅ Sesión cerrada');
    } catch (e) {
      debugPrint('❌ Error cerrando sesión: $e');
      rethrow;
    }
  }

  /// Crea un household para el usuario
  static Future<Map<String, dynamic>> createUserHousehold({
    required String userId,
    required String siteId,
    required String householdName,
    required String userType,
    String? displayName,
  }) async {
    try {
      debugPrint('🏠 Creando household para usuario: $userId');

      // 1. Generar código único de redención
      final redeemCode = _generateRedeemCode(siteId);

      // 2. Crear household
      final householdResponse = await _client
          .from(SupabaseConfig.householdsTable)
          .insert({
            'site_id': siteId,
            'name': householdName,
            'owner_user_id': userId,
            'redeem_code': redeemCode,
            'activated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final householdId = householdResponse['id'];
      debugPrint('✅ Household creado: $householdId');

      // 3. Agregar usuario como miembro del household
      // ROL: 'owner' = Padre/Madre que crea el grupo familiar
      // Permisos: Administrar household, invitar miembros, ver código
      await _client.from(SupabaseConfig.householdMembersTable).insert({
        'household_id': householdId,
        'user_id': userId,
        'role': 'owner', // Rol de propietario/padre
        'display_name': displayName ?? 'Usuario Principal',
        'is_child': false, // No es cuenta de hijo
      });

      debugPrint('✅ Usuario agregado como miembro del household');

      return householdResponse;
    } catch (e) {
      debugPrint('❌ Error creando household: $e');
      rethrow;
    }
  }

  /// Genera un código de redención único
  static String _generateRedeemCode(String siteId) {
    final now = DateTime.now();
    final random = DateTime.now().millisecondsSinceEpoch % 1000;
    return 'ANG${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}$random';
  }

  /// Setup completo de usuario nuevo con household
  static Future<Map<String, dynamic>> setupNewUser({
    required String email,
    required String siteId,
    required String userType,
    String? displayName,
    String? password,
  }) async {
    try {
      debugPrint('🎬 Iniciando setup de nuevo usuario...');

      Map<String, dynamic> user;

      // 1. Crear usuario (guest o con autenticación)
      if (password == null || password.isEmpty) {
        user = await createGuestUser(email: email, displayName: displayName);
      } else {
        user = await signUpWithEmail(
          email: email,
          password: password,
          displayName: displayName,
        );
      }

      // 2. Crear household
      final household = await createUserHousehold(
        userId: user['id'],
        siteId: siteId,
        householdName: '$userType de ${user['display_name']}',
        userType: userType,
        displayName: user['display_name'],
      );

      debugPrint('✅ Setup de usuario completado exitosamente');

      return {'user': user, 'household': household};
    } catch (e) {
      debugPrint('❌ Error en setup de usuario: $e');
      rethrow;
    }
  }
}
