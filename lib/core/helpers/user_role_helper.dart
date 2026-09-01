import 'package:flutter/foundation.dart';
import '../models/user_role.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

/// Helper para gestionar roles y permisos de usuario
class UserRoleHelper {
  /// Obtiene el rol actual del usuario desde su household
  /// Retorna null si el usuario no está en un household
  static Future<UserRole?> getCurrentUserRole() async {
    try {
      final familyInfo = await SupabaseService.getCurrentUserFamilyInfo();

      if (familyInfo == null) {
        // Usuario sin household = visitante
        return UserRole.visitor;
      }

      final role = familyInfo['role'] as String? ?? 'member';
      final isChild = familyInfo['is_child'] as bool? ?? false;

      return getUserRoleFromHouseholdMember(role: role, isChild: isChild);
    } catch (e) {
      debugPrint('Error obteniendo rol de usuario: $e');
      return UserRole.visitor; // Fallback seguro
    }
  }

  /// Verifica si el usuario actual puede administrar households
  static Future<bool> canManageHousehold() async {
    final role = await getCurrentUserRole();
    return role?.canManageHousehold ?? false;
  }

  /// Verifica si el usuario actual tiene restricciones de edad
  static Future<bool> hasAgeRestrictions() async {
    final role = await getCurrentUserRole();
    return role?.hasAgeRestrictions ?? false;
  }

  /// Verifica si el usuario actual está en un household
  static Future<bool> isInHousehold() async {
    final role = await getCurrentUserRole();
    return role?.isInHousehold ?? false;
  }

  /// Obtiene información legible del rol actual
  static Future<Map<String, dynamic>> getCurrentRoleInfo() async {
    final role = await getCurrentUserRole();

    if (role == null) {
      return {
        'role': UserRole.visitor,
        'display_name': 'Visitante',
        'emoji': '🚶‍♂️',
        'can_manage': false,
        'has_restrictions': false,
        'is_in_household': false,
      };
    }

    return {
      'role': role,
      'display_name': role.displayName,
      'emoji': role.emoji,
      'can_manage': role.canManageHousehold,
      'has_restrictions': role.hasAgeRestrictions,
      'is_in_household': role.isInHousehold,
    };
  }

  /// Guarda el rol en storage local para acceso rápido
  static Future<void> cacheUserRole(UserRole role) async {
    final userData = StorageService.userData ?? {};
    userData['cached_role'] = role.toDbValue();
    await StorageService.setUserData(userData);
  }

  /// Obtiene el rol cacheado sin consultar la base de datos
  static UserRole? getCachedRole() {
    try {
      final userData = StorageService.userData ?? {};
      final cachedRole = userData['cached_role'] as String?;

      if (cachedRole != null) {
        return userRoleFromDb(cachedRole);
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo rol cacheado: $e');
      return null;
    }
  }

  /// Verifica permisos específicos
  static Future<bool> hasPermission(UserPermission permission) async {
    final role = await getCurrentUserRole();
    if (role == null) return false;

    switch (permission) {
      case UserPermission.manageHousehold:
        return role.canManageHousehold;

      case UserPermission.inviteMembers:
        return role == UserRole.owner || role == UserRole.admin;

      case UserPermission.viewFamilyCode:
        return role == UserRole.owner;

      case UserPermission.redeemRewards:
        // Los hijos no pueden canjear recompensas sin supervisión
        return !role.hasAgeRestrictions;

      case UserPermission.scanQRCodes:
        // Todos pueden escanear QR
        return true;

      case UserPermission.viewStatistics:
        return role == UserRole.admin || role == UserRole.owner;

      case UserPermission.moderateContent:
        return role == UserRole.admin;
    }
  }
}

/// Permisos específicos del sistema
enum UserPermission {
  manageHousehold,
  inviteMembers,
  viewFamilyCode,
  redeemRewards,
  scanQRCodes,
  viewStatistics,
  moderateContent,
}
