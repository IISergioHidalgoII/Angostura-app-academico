import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_type.dart' as models;
import '../../core/providers/user_mode_provider.dart';
import '../../core/services/household_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/supabase_service.dart';

/// Router post-autenticación según UserMode
class PostAuthRouter {
  /// Procesa el flujo después de autenticación exitosa
  static Future<void> route({
    required BuildContext context,
    required WidgetRef ref,
    required UserMode mode,
    required String userId,
    required String email,
  }) async {
    debugPrint('[MODE] post-auth routing mode=$mode userId=$userId');

    // Marcar que estamos procesando
    ref.read(isPostAuthProcessingProvider.notifier).state = true;

    try {
      switch (mode) {
        case UserMode.individual:
          await _handleIndividual(context, userId);
          break;

        case UserMode.createFamily:
          await _handleCreateFamily(context, ref, userId, email);
          break;

        case UserMode.joinFamily:
          await _handleJoinFamily(context, ref, userId, email);
          break;
      }
    } catch (e) {
      debugPrint('[MODE] post-auth error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ref.read(isPostAuthProcessingProvider.notifier).state = false;
    }
  }

  /// Caso: Usuario individual (sin familia)
  static Future<void> _handleIndividual(
    BuildContext context,
    String userId,
  ) async {
    debugPrint('[MODE] individual - navegando a home');
    debugPrint('[HOME] no household');

    // Asegurar que userData tiene userId
    final existingUserData = StorageService.userData ?? {};
    if (!existingUserData.containsKey('user_id')) {
      final updatedUserData = {...existingUserData, 'user_id': userId};
      await StorageService.setUserData(updatedUserData);
    }

    if (context.mounted) {
      final args = _buildNavigationArgs();
      Navigator.of(context).pushReplacementNamed('/home', arguments: args);
    }
  }

  /// Caso: Crear grupo familiar
  static Future<void> _handleCreateFamily(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String email,
  ) async {
    debugPrint('[HOUSEHOLD] create:start userId=$userId email=$email');

    try {
      // Obtener site_id del parque seleccionado
      final userData = StorageService.userData ?? {};
      final park = userData['selected_park'] ?? 'angostura';
      final siteId = await _getSiteId(park);

      if (siteId == null) {
        throw Exception('No se encontró el sitio para el parque: $park');
      }

      // Usar HouseholdService para crear
      final householdName = 'Familia de ${email.split('@')[0]}';
      final result = await HouseholdService.createHouseholdForOwner(
        siteId: siteId,
        householdName: householdName,
      );

      final householdId = result['household_id'];
      final familyCode = result['family_code'];
      final verificationCode = result['verification_code'];
      final isNew = result['is_new'] ?? false;

      debugPrint('[HOUSEHOLD] create:success householdId=$householdId');
      debugPrint('[HOUSEHOLD] create:groupCode=$familyCode');
      debugPrint('[HOUSEHOLD] create:verificationCode=$verificationCode');

      // Preservar userData existente (region, park, etc.)
      final existingUserData = StorageService.userData ?? {};
      final updatedUserData = {
        ...existingUserData,
        'email': email,
        'user_id': userId,
      };
      await StorageService.setUserData(updatedUserData);

      // Guardar en storage para mostrar en Home
      await StorageService.setHouseholdData({
        'household_id': householdId,
        'family_code': familyCode,
        'verification_code': verificationCode,
        'owner_email': email,
        'is_new': isNew,
        'verified': false,
      });

      // Enviar email de verificación
      if (isNew) {
        try {
          debugPrint('[EMAIL] send:start to=$email code=$verificationCode');
          await HouseholdService.sendVerificationEmail(
            email: email,
            verificationCode: verificationCode,
            familyCode: familyCode,
            householdName: householdName,
          );
          debugPrint('[EMAIL] send:success');
        } catch (e) {
          debugPrint('[EMAIL] send:error $e');
          // No bloquear el flujo si falla el email
        }
      }

      // Navegar a Home primero
      debugPrint('[HOME] household loaded householdId=$householdId');
      if (context.mounted) {
        final args = _buildNavigationArgs();
        Navigator.of(context).pushReplacementNamed('/home', arguments: args);

        // Luego mostrar dialog con código (después de navegar)
        await Future.delayed(const Duration(milliseconds: 300));

        if (context.mounted) {
          await _showFamilyCreatedDialog(
            context,
            familyCode: familyCode,
            email: email,
            isNew: isNew,
          );
        }
      }
    } catch (e) {
      debugPrint('[HOUSEHOLD] create:error $e');
      rethrow;
    }
  }

  /// Caso: Unirse a grupo familiar
  static Future<void> _handleJoinFamily(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String email,
  ) async {
    debugPrint('[HOUSEHOLD] join:start userId=$userId');

    if (!context.mounted) return;

    // Mostrar dialog para ingresar código
    final code = await _showJoinFamilyDialog(context);

    if (code == null || code.isEmpty) {
      debugPrint('[HOUSEHOLD] join:cancelled');
      // Usuario canceló, ir a home sin familia
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
      return;
    }

    debugPrint('[HOUSEHOLD] join:code=$code');

    try {
      // Validar y unirse usando HouseholdService
      final result = await HouseholdService.joinHouseholdByCode(code);

      final householdId = result['household_id'];
      final householdName = result['household_name'];
      final isNewMember = result['is_new_member'] ?? false;

      debugPrint('[HOUSEHOLD] join:success householdId=$householdId');

      // Preservar userData existente (region, park, etc.)
      final existingUserData = StorageService.userData ?? {};
      final updatedUserData = {
        ...existingUserData,
        'email': email,
        'user_id': userId,
      };
      await StorageService.setUserData(updatedUserData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNewMember
                  ? '✅ Te has unido a "$householdName"'
                  : '✅ Ya eres miembro de "$householdName"',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Navegar a Home
      debugPrint('[HOME] household loaded householdId=$householdId');
      if (context.mounted) {
        final args = _buildNavigationArgs();
        Navigator.of(context).pushReplacementNamed('/home', arguments: args);
      }
    } catch (e) {
      debugPrint('[HOUSEHOLD] join:error $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );

        // Ir a home sin familia
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  /// Obtiene el site_id del parque
  static Future<String?> _getSiteId(String park) async {
    try {
      final siteName = park == 'angostura'
          ? 'Parque Humedal Angostura del Biobío'
          : park;

      final siteResponse = await SupabaseService.client
          .from('sites')
          .select('id, name')
          .eq('name', siteName)
          .limit(1);

      if (siteResponse.isEmpty) {
        debugPrint('[HOUSEHOLD] site not found: $siteName');
        return null;
      }

      return siteResponse.first['id'];
    } catch (e) {
      debugPrint('[HOUSEHOLD] error getting site: $e');
      return null;
    }
  }

  /// Dialog para mostrar código familiar creado
  static Future<void> _showFamilyCreatedDialog(
    BuildContext context, {
    required String familyCode,
    required String email,
    required bool isNew,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isNew ? Icons.family_restroom : Icons.info_outline,
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 8),
              Text(isNew ? '🏠 ¡Familia Creada!' : 'ℹ️ Familia Existente'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isNew
                    ? '✅ Tu grupo familiar ha sido creado exitosamente.'
                    : '✅ Ya tienes un grupo familiar creado.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (isNew) ...[
                const Text(
                  '📧 Se ha enviado un código de verificación a:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  email,
                  style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                '👨‍👩‍👧 Código de Familia:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF9C27B0)),
                ),
                child: Center(
                  child: SelectableText(
                    familyCode,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF9C27B0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Comparte este código con tus familiares para que puedan unirse al grupo.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog para ingresar código de familia
  static Future<String?> _showJoinFamilyDialog(BuildContext context) async {
    final controller = TextEditingController();
    String? validationError;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.family_restroom, color: Color(0xFF9C27B0)),
                  SizedBox(width: 8),
                  Text('Unirse a Familia'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingresa el código del grupo familiar:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'FAM-XXXXX',
                      border: const OutlineInputBorder(),
                      errorText: validationError,
                      prefixIcon: const Icon(Icons.qr_code),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (value) {
                      setState(() {
                        validationError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '💡 El código debe tener el formato FAM-XXXXX',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final code = controller.text.trim().toUpperCase();
                    if (code.isEmpty) {
                      setState(() {
                        validationError = 'El código no puede estar vacío';
                      });
                      return;
                    }
                    if (!code.startsWith('FAM-')) {
                      setState(() {
                        validationError = 'El código debe empezar con FAM-';
                      });
                      return;
                    }
                    Navigator.of(context).pop(code);
                  },
                  child: const Text('Unirse'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Construye arguments de navegación desde userData almacenado
  static Map<String, dynamic> _buildNavigationArgs() {
    final userData = StorageService.userData ?? {};
    final userModeStr = StorageService.userMode ?? 'UserType.guest';

    // Parsear UserType
    models.UserType userType = models.UserType.guest;
    if (userModeStr.contains('family')) {
      userType = models.UserType.family;
    }

    debugPrint('[ARGS] Building navigation args:');
    debugPrint('   email: ${userData['email']}');
    debugPrint('   userType: $userType');
    debugPrint('   region: ${userData['selected_region']}');
    debugPrint('   park: ${userData['selected_park']}');

    return {
      'userEmail': userData['email'] as String? ?? 'usuario@angostura.local',
      'userType': userType,
      'selectedRegion': userData['selected_region'] as String? ?? 'biobio',
      'selectedPark': userData['selected_park'] as String? ?? 'angostura',
    };
  }
}
