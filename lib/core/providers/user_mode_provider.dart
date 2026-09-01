import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modo de usuario seleccionado en pantalla inicial
enum UserMode {
  individual, // Visitante sin familia
  createFamily, // Crear grupo familiar (owner)
  joinFamily, // Unirse a grupo existente (member)
}

/// Provider para el modo de usuario actual
final userModeProvider = StateProvider<UserMode?>((ref) => null);

/// Provider para trackear si estamos en proceso de post-auth
final isPostAuthProcessingProvider = StateProvider<bool>((ref) => false);
