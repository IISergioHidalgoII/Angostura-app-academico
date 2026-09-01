/// Roles de usuario en el sistema
/// Define los diferentes tipos de roles y permisos
enum UserRole {
  /// Usuario visitante individual (sin household)
  visitor,

  /// Propietario/creador del grupo familiar
  /// Permisos: Administrar household, invitar miembros, ver código familiar
  owner,

  /// Miembro del grupo familiar (adulto)
  /// Permisos: Participar en actividades, coleccionar cartas
  member,

  /// Miembro hijo (menor con restricciones)
  /// Permisos: Participar en actividades con supervisión
  child,

  /// Administrador del parque/sitio (staff)
  /// Permisos: Gestionar sitio, ver estadísticas, moderar
  admin,
}

extension UserRoleExtension on UserRole {
  /// Convierte el enum a string para guardar en base de datos
  String toDbValue() {
    switch (this) {
      case UserRole.visitor:
        return 'visitor';
      case UserRole.owner:
        return 'owner';
      case UserRole.member:
        return 'member';
      case UserRole.child:
        return 'child';
      case UserRole.admin:
        return 'admin';
    }
  }

  /// Determina si el rol puede administrar un household
  bool get canManageHousehold {
    return this == UserRole.owner || this == UserRole.admin;
  }

  /// Determina si el rol tiene restricciones de edad
  bool get hasAgeRestrictions {
    return this == UserRole.child;
  }

  /// Determina si el rol es parte de un household
  bool get isInHousehold {
    return this == UserRole.owner ||
        this == UserRole.member ||
        this == UserRole.child;
  }

  /// Obtiene el nombre legible del rol
  String get displayName {
    switch (this) {
      case UserRole.visitor:
        return 'Visitante';
      case UserRole.owner:
        return 'Padre/Madre';
      case UserRole.member:
        return 'Miembro Adulto';
      case UserRole.child:
        return 'Hijo/Hija';
      case UserRole.admin:
        return 'Administrador';
    }
  }

  /// Obtiene el emoji representativo del rol
  String get emoji {
    switch (this) {
      case UserRole.visitor:
        return '🚶‍♂️';
      case UserRole.owner:
        return '👨‍👩‍👧‍👦';
      case UserRole.member:
        return '👤';
      case UserRole.child:
        return '👶';
      case UserRole.admin:
        return '⚙️';
    }
  }
}

/// Función auxiliar para parsear string de base de datos a UserRole
UserRole userRoleFromDb(String dbValue, {bool isChild = false}) {
  // Si está marcado como is_child, es un hijo independientemente del role
  if (isChild) {
    return UserRole.child;
  }

  switch (dbValue.toLowerCase()) {
    case 'visitor':
      return UserRole.visitor;
    case 'owner':
      return UserRole.owner;
    case 'member':
      return UserRole.member;
    case 'child':
      return UserRole.child;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.visitor; // fallback seguro
  }
}

/// Función auxiliar para determinar el rol desde household_members
UserRole getUserRoleFromHouseholdMember({
  required String role,
  required bool isChild,
}) {
  // Prioridad a is_child
  if (isChild) {
    return UserRole.child;
  }

  return userRoleFromDb(role);
}
