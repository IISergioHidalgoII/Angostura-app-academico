import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Servicio dedicado para gestión de Households (grupos familiares)
/// Con logging extensivo para trazabilidad
class HouseholdService {
  static const String _tag = '[HOUSEHOLD_SERVICE]';

  /// Crea un household para el usuario actual (owner/padre)
  ///
  /// Flujo:
  /// 1. Verifica que hay usuario autenticado
  /// 2. Llama a RPC create_household_for_owner
  /// 3. Si ya existe household, retorna el existente
  /// 4. Si es nuevo, genera códigos (familia + verificación)
  /// 5. Retorna información completa incluyendo código de verificación
  ///
  /// Returns:
  /// ```dart
  /// {
  ///   'household_id': String,
  ///   'family_code': String,        // FAM-XXXXX
  ///   'household_name': String,
  ///   'verified': bool,             // false al crear
  ///   'verification_code': String,  // 6 dígitos para email
  ///   'verification_code_expires_at': DateTime,
  ///   'owner_email': String,
  ///   'is_new': bool                // true si se creó nuevo, false si existía
  /// }
  /// ```
  static Future<Map<String, dynamic>> createHouseholdForOwner({
    required String siteId,
    String? householdName,
  }) async {
    debugPrint('$_tag create:start');
    debugPrint('$_tag   siteId: $siteId');
    debugPrint('$_tag   householdName: $householdName');

    try {
      // 1. Verificar autenticación
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('$_tag create:error - No authenticated user');
        throw Exception('No hay usuario autenticado');
      }

      debugPrint('$_tag   userId: ${currentUser.id}');
      debugPrint('$_tag   userEmail: ${currentUser.email}');

      // 2. Llamar a RPC
      final response = await SupabaseService.client.rpc(
        'create_household_for_owner',
        params: {'p_site_id': siteId, 'p_household_name': householdName},
      );

      debugPrint('$_tag create:response received');
      debugPrint('$_tag   household_id: ${response['household_id']}');
      debugPrint('$_tag   family_code: ${response['family_code']}');
      debugPrint('$_tag   verified: ${response['verified']}');
      debugPrint('$_tag   is_new: ${response['is_new']}');

      // 3. Registrar resultado
      if (response['is_new'] == true) {
        debugPrint('$_tag create:success - NEW household created');
        debugPrint(
          '$_tag   verification_code: ${response['verification_code']}',
        );
        debugPrint('$_tag   IMPORTANTE: Enviar código por email');
      } else {
        debugPrint('$_tag create:success - EXISTING household returned');
      }

      return Map<String, dynamic>.from(response);
    } catch (e, stackTrace) {
      debugPrint('$_tag create:error - $e');
      debugPrint('$_tag create:stackTrace - $stackTrace');
      rethrow;
    }
  }

  /// Une al usuario actual a un household existente usando código
  ///
  /// Flujo:
  /// 1. Verifica autenticación
  /// 2. Valida que el código existe
  /// 3. Verifica que el usuario no sea ya miembro
  /// 4. Agrega como miembro con role='member' (adulto) o role='child' (hijo)
  ///
  /// Roles asignados:
  /// - 'member' + is_child=false: Miembro adulto del household
  /// - 'member' + is_child=true: Hijo/menor con restricciones
  ///
  /// Parámetros:
  /// - familyCode: Código del grupo (ej: FAM-XXXXX)
  ///
  /// Returns:
  /// ```dart
  /// {
  ///   'household_id': String,
  ///   'household_name': String,
  ///   'family_code': String,
  ///   'role': 'member',
  ///   'is_new_member': bool,
  ///   'message': String
  /// }
  /// ```
  static Future<Map<String, dynamic>> joinHouseholdByCode(
    String familyCode,
  ) async {
    debugPrint('$_tag join:start');
    debugPrint('$_tag   familyCode: $familyCode');

    try {
      // 1. Verificar autenticación
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('$_tag join:error - No authenticated user');
        throw Exception('No hay usuario autenticado');
      }

      debugPrint('$_tag   userId: ${currentUser.id}');
      debugPrint('$_tag   userEmail: ${currentUser.email}');

      // 2. Validar código (verificación rápida antes de RPC)
      final isValid = await validateFamilyCode(familyCode);
      if (!isValid) {
        debugPrint('$_tag join:error - Invalid family code');
        throw Exception('Código de familia inválido');
      }

      debugPrint('$_tag   code validated: OK');

      // 3. Llamar a RPC
      final response = await SupabaseService.client.rpc(
        'join_household_by_code',
        params: {'p_family_code': familyCode},
      );

      debugPrint('$_tag join:response received');
      debugPrint('$_tag   household_id: ${response['household_id']}');
      debugPrint('$_tag   household_name: ${response['household_name']}');
      debugPrint('$_tag   is_new_member: ${response['is_new_member']}');
      debugPrint('$_tag   message: ${response['message']}');

      if (response['is_new_member'] == true) {
        debugPrint('$_tag join:success - NEW member added');
      } else {
        debugPrint('$_tag join:success - ALREADY a member');
      }

      return Map<String, dynamic>.from(response);
    } catch (e, stackTrace) {
      debugPrint('$_tag join:error - $e');
      debugPrint('$_tag join:stackTrace - $stackTrace');
      rethrow;
    }
  }

  /// Verifica un household usando el código OTP enviado por email
  /// Solo el owner puede verificar
  ///
  /// Parámetros:
  /// - householdId: ID del household
  /// - verificationCode: Código de 6 dígitos recibido por email
  static Future<bool> verifyHouseholdCode({
    required String householdId,
    required String verificationCode,
  }) async {
    debugPrint('$_tag verify:start');
    debugPrint('$_tag   householdId: $householdId');
    debugPrint('$_tag   verificationCode: $verificationCode');

    try {
      final response = await SupabaseService.client.rpc(
        'verify_household_code',
        params: {
          'p_household_id': householdId,
          'p_verification_code': verificationCode,
        },
      );

      debugPrint('$_tag verify:response - ${response['message']}');
      debugPrint('$_tag verify:success - Household verified');

      return response['success'] == true;
    } catch (e, stackTrace) {
      debugPrint('$_tag verify:error - $e');
      debugPrint('$_tag verify:stackTrace - $stackTrace');
      rethrow;
    }
  }

  /// Reenvía el código de verificación
  /// Solo el owner puede solicitar reenvío
  ///
  /// Returns: Nuevo código de verificación y fecha de expiración
  static Future<Map<String, dynamic>> resendVerificationCode(
    String householdId,
  ) async {
    debugPrint('$_tag resend:start');
    debugPrint('$_tag   householdId: $householdId');

    try {
      final response = await SupabaseService.client.rpc(
        'resend_verification_code',
        params: {'p_household_id': householdId},
      );

      debugPrint('$_tag resend:success');
      debugPrint(
        '$_tag   new verification_code: ${response['verification_code']}',
      );
      debugPrint('$_tag   IMPORTANTE: Enviar nuevo código por email');

      return Map<String, dynamic>.from(response);
    } catch (e, stackTrace) {
      debugPrint('$_tag resend:error - $e');
      debugPrint('$_tag resend:stackTrace - $stackTrace');
      rethrow;
    }
  }

  /// Obtiene información completa del household del usuario actual
  ///
  /// Returns:
  /// ```dart
  /// {
  ///   'household_id': String,
  ///   'household_name': String,
  ///   'family_code': String,
  ///   'verified': bool,
  ///   'role': 'owner' | 'member',
  ///   'is_child': bool,
  ///   'is_owner': bool,
  ///   'member_count': int,
  ///   'created_at': DateTime
  /// }
  /// ```
  ///
  /// Si el usuario no pertenece a ningún household, retorna null
  static Future<Map<String, dynamic>?> getMyHouseholdInfo() async {
    debugPrint('$_tag getInfo:start');

    try {
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('$_tag getInfo:error - No authenticated user');
        return null;
      }

      final response = await SupabaseService.client.rpc(
        'get_my_household_info',
      );

      if (response == null) {
        debugPrint('$_tag getInfo:result - No household');
        return null;
      }

      debugPrint('$_tag getInfo:result - Found household');
      debugPrint('$_tag   household_id: ${response['household_id']}');
      debugPrint('$_tag   family_code: ${response['family_code']}');
      debugPrint('$_tag   role: ${response['role']}');
      debugPrint('$_tag   is_owner: ${response['is_owner']}');
      debugPrint('$_tag   verified: ${response['verified']}');
      debugPrint('$_tag   member_count: ${response['member_count']}');

      return Map<String, dynamic>.from(response);
    } catch (e, stackTrace) {
      debugPrint('$_tag getInfo:error - $e');
      debugPrint('$_tag getInfo:stackTrace - $stackTrace');
      return null;
    }
  }

  /// Valida que un código de familia existe y está activo
  /// (verificación rápida sin agregar al usuario)
  static Future<bool> validateFamilyCode(String familyCode) async {
    debugPrint('$_tag validate:start - code: $familyCode');

    try {
      final response = await SupabaseService.client
          .from('households')
          .select('id, redeem_code, activated_at')
          .eq('redeem_code', familyCode)
          .maybeSingle();

      if (response == null) {
        debugPrint('$_tag validate:result - NOT FOUND');
        return false;
      }

      if (response['activated_at'] == null) {
        debugPrint('$_tag validate:result - NOT ACTIVATED');
        return false;
      }

      debugPrint('$_tag validate:result - VALID');
      return true;
    } catch (e) {
      debugPrint('$_tag validate:error - $e');
      return false;
    }
  }

  /// Envía email con código de verificación
  ///
  /// NOTA: Esta función es un placeholder. En producción debe:
  /// 1. Usar una Edge Function de Supabase
  /// 2. O un servicio como SendGrid, Resend, etc.
  /// 3. O el servicio de email que tengas configurado
  ///
  /// Parámetros esperados:
  /// - email: destinatario
  /// - verificationCode: código de 6 dígitos
  /// - familyCode: código del grupo (para referencia)
  /// - householdName: nombre del grupo
  static Future<bool> sendVerificationEmail({
    required String email,
    required String verificationCode,
    required String familyCode,
    required String householdName,
  }) async {
    debugPrint('[EMAIL] send:start');
    debugPrint('[EMAIL]   to: $email');
    debugPrint('[EMAIL]   verificationCode: $verificationCode');
    debugPrint('[EMAIL]   familyCode: $familyCode');
    debugPrint('[EMAIL]   householdName: $householdName');

    try {
      // TODO: Implementar envío real de email
      // Opciones:
      // 1. Edge Function en Supabase
      // 2. Servicio externo (SendGrid, Resend, etc.)
      // 3. API propia de envío de correos

      // Ejemplo con Edge Function (cuando esté configurada):
      /*
      final response = await SupabaseService.client.functions.invoke(
        'send-verification-email',
        body: {
          'to': email,
          'verification_code': verificationCode,
          'family_code': familyCode,
          'household_name': householdName,
        },
      );
      
      if (response.status == 200) {
        debugPrint('[EMAIL] send:success');
        return true;
      }
      */

      // Por ahora, solo log (debe implementarse)
      debugPrint('[EMAIL] send:TODO - Implementar envío real');
      debugPrint('[EMAIL]   MOCK: Email enviado exitosamente');

      return true;
    } catch (e, stackTrace) {
      debugPrint('[EMAIL] send:error - $e');
      debugPrint('[EMAIL] send:stackTrace - $stackTrace');
      return false;
    }
  }

  /// Marca un miembro como hijo (is_child = true)
  /// Solo el owner puede hacer esto
  static Future<bool> markMemberAsChild({
    required String householdId,
    required String memberId,
  }) async {
    debugPrint('$_tag markChild:start');
    debugPrint('$_tag   householdId: $householdId');
    debugPrint('$_tag   memberId: $memberId');

    try {
      // Verificar que el usuario actual es el owner
      final myInfo = await getMyHouseholdInfo();
      if (myInfo == null || myInfo['is_owner'] != true) {
        debugPrint('$_tag markChild:error - Not owner');
        throw Exception('Solo el owner puede marcar miembros como hijos');
      }

      await SupabaseService.client
          .from('household_members')
          .update({'is_child': true})
          .eq('id', memberId)
          .eq('household_id', householdId);

      debugPrint('$_tag markChild:success');
      return true;
    } catch (e, stackTrace) {
      debugPrint('$_tag markChild:error - $e');
      debugPrint('$_tag markChild:stackTrace - $stackTrace');
      return false;
    }
  }

  /// Obtiene todos los miembros del household del usuario actual
  static Future<List<Map<String, dynamic>>> getMyHouseholdMembers() async {
    debugPrint('$_tag getMembers:start');

    try {
      final myInfo = await getMyHouseholdInfo();
      if (myInfo == null) {
        debugPrint('$_tag getMembers:result - No household');
        return [];
      }

      final householdId = myInfo['household_id'];

      final members = await SupabaseService.client
          .from('household_members')
          .select('id, user_id, display_name, role, is_child, created_at')
          .eq('household_id', householdId)
          .order('created_at', ascending: true);

      debugPrint('$_tag getMembers:result - ${members.length} members found');
      return List<Map<String, dynamic>>.from(members);
    } catch (e, stackTrace) {
      debugPrint('$_tag getMembers:error - $e');
      debugPrint('$_tag getMembers:stackTrace - $stackTrace');
      return [];
    }
  }
}
