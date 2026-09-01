import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart' hide UserType;
import '../../core/models/user_type.dart' as models;
import '../../core/services/storage_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/routing/post_auth_router.dart';
import '../../core/providers/user_mode_provider.dart';
import '../boot/boot_page.dart';
import '../onboarding/pages/onboarding_page.dart' show UserType;

class UserModeSelectorPage extends ConsumerStatefulWidget {
  const UserModeSelectorPage({super.key});

  @override
  ConsumerState<UserModeSelectorPage> createState() =>
      _UserModeSelectorPageState();
}

class _UserModeSelectorPageState extends ConsumerState<UserModeSelectorPage> {
  UserType? _selectedUserType;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryGreen),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.waving_hand, size: 64, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                '¿Cómo deseas usar la app?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Selecciona tu modo de usuario',
                style: TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Visitante Individual
              _buildUserTypeCard(
                type: UserType.guest,
                icon: Icons.person_outline,
                title: 'Visitante Individual',
                description: 'Explora solo, sin grupo',
                onTap: () => _selectUserType(UserType.guest),
              ),

              const SizedBox(height: 16),

              // Crear Grupo Familiar
              _buildUserTypeCard(
                type: UserType.family,
                icon: Icons.family_restroom,
                title: 'Crear Grupo Familiar',
                description: 'Inicia tu propio grupo',
                onTap: () => _selectUserType(UserType.family),
              ),

              const SizedBox(height: 16),

              // Unirse a Grupo Familiar
              _buildUserTypeCard(
                type: UserType.joinFamily,
                icon: Icons.group_add,
                title: 'Unirse a Grupo Familiar',
                description: 'Usa un código de familia',
                onTap: () => _selectUserType(UserType.joinFamily),
              ),

              const SizedBox(height: 32),

              if (_selectedUserType != null)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _continueToApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppConstants.accentOrange),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Continuar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeCard({
    required UserType type,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedUserType == type;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(AppConstants.accentOrange)
              : Colors.transparent,
          width: 3,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(
                    AppConstants.accentOrange,
                  ).withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(
                      AppConstants.primaryGreen,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: const Color(AppConstants.primaryGreen),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(AppConstants.primaryGreen),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(AppConstants.accentOrange),
                    size: 28,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectUserType(UserType type) {
    setState(() {
      _selectedUserType = type;
    });
  }

  Future<void> _continueToApp() async {
    if (_selectedUserType == null) return;

    setState(() => _isProcessing = true);

    try {
      // Guardar tipo de usuario seleccionado
      final userData = StorageService.userData ?? {};
      userData['user_type'] = _selectedUserType.toString();

      // SMART START: Guardar modo de usuario
      await StorageService.setUserMode(_selectedUserType.toString());

      await StorageService.setUserData(userData);

      setState(() => _isProcessing = false);

      // CASO ESPECIAL: Unirse a familia con cuenta invitado temporal
      if (_selectedUserType == UserType.joinFamily && mounted) {
        await _handleJoinFamilyAsGuest();
        return;
      }

      // Mostrar opciones de autenticación para otros casos
      if (mounted) {
        _showAuthOptionsDialog();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAuthOptionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Autenticación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Tienes una cuenta o quieres crear una nueva?'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showLoginDialog();
                },
                icon: const Icon(Icons.login),
                label: const Text('Iniciar sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConstants.primaryGreen),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showRegisterDialog();
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Crear cuenta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(AppConstants.primaryGreen),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLoginDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.login, color: Color(AppConstants.primaryGreen)),
              SizedBox(width: 8),
              Text('Iniciar sesión'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'ejemplo@email.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                final password = passwordController.text.trim();

                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Email inválido'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Ingresa tu contraseña'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _performLogin(email, password);
              },
              child: const Text('Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performLogin(String email, String password) async {
    try {
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Usuario no encontrado');
      }

      // Guardar email y asegurar que userMode esté guardado
      final userData = StorageService.userData ?? {};
      userData['email'] = email;

      // Debug: verificar datos existentes
      debugPrint('📋 Login - Datos actuales:');
      debugPrint('   Region: ${userData['selected_region']}');
      debugPrint('   Park: ${userData['selected_park']}');
      debugPrint('   UserMode: ${StorageService.userMode}');
      debugPrint('   Selected Type: $_selectedUserType');

      await StorageService.setUserData(userData);

      // Verificar que userMode esté guardado (ya debería estarlo de _continueToApp)
      if (StorageService.userMode == null && _selectedUserType != null) {
        await StorageService.setUserMode(_selectedUserType.toString());
        debugPrint('✅ UserMode guardado: ${_selectedUserType.toString()}');
      }

      await StorageService.setHasCompletedInitialSetup(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sesión iniciada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Usar PostAuthRouter para manejar el flujo según el tipo de usuario
        await _handlePostAuth(response.user!.id, email);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = '❌ Error al iniciar sesión';

        if (e.toString().contains('Invalid login credentials') ||
            e.toString().contains('invalid_credentials') ||
            e.toString().contains('400')) {
          errorMessage =
              '❌ Email o contraseña incorrectos.\n\n💡 ¿Olvidaste tu contraseña o no tienes cuenta? Usa "Crear cuenta"';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showRegisterDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Color(AppConstants.primaryGreen)),
              SizedBox(width: 8),
              Text('Crear cuenta'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Completa los datos para registrarte:'),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'ejemplo@gmail.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Mínimo 8 caracteres',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Repetir contraseña',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                final password = passwordController.text.trim();
                final confirmPassword = confirmPasswordController.text.trim();

                if (email.isEmpty ||
                    !email.contains('@') ||
                    !email.contains('.')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Email inválido. Usa: ejemplo@gmail.com'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (password.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '❌ La contraseña debe tener al menos 8 caracteres',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (password != confirmPassword) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Las contraseñas no coinciden'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _performRegister(email, password);
              },
              child: const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performRegister(String email, String password) async {
    try {
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: null,
      );

      if (response.user == null) {
        throw Exception('Error al crear cuenta');
      }

      // Guardar email y asegurar que userMode esté guardado
      final userData = StorageService.userData ?? {};
      userData['email'] = email;

      // Debug: verificar datos existentes
      debugPrint('📋 Registro - Datos actuales:');
      debugPrint('   Region: ${userData['selected_region']}');
      debugPrint('   Park: ${userData['selected_park']}');
      debugPrint('   UserMode: ${StorageService.userMode}');
      debugPrint('   Selected Type: $_selectedUserType');

      await StorageService.setUserData(userData);

      // Verificar que userMode esté guardado (ya debería estarlo de _continueToApp)
      if (StorageService.userMode == null && _selectedUserType != null) {
        await StorageService.setUserMode(_selectedUserType.toString());
        debugPrint('✅ UserMode guardado: ${_selectedUserType.toString()}');
      }

      await StorageService.setHasCompletedInitialSetup(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cuenta creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Usar PostAuthRouter para manejar el flujo según el tipo de usuario
        await _handlePostAuth(response.user!.id, email);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = '❌ Error al crear cuenta';

        if (e.toString().contains('already registered') ||
            e.toString().contains('already exists')) {
          errorMessage =
              '❌ Este email ya está registrado. Usa "Iniciar sesión"';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Maneja unirse a familia con cuenta invitado temporal (sin autenticación)
  Future<void> _handleJoinFamilyAsGuest() async {
    debugPrint('👥 Iniciando flujo: Unirse a familia como invitado');

    if (!mounted) return;

    // Mostrar dialog para ingresar código
    final code = await _showJoinFamilyCodeDialog();

    if (code == null || code.isEmpty) {
      debugPrint('❌ Usuario canceló ingreso de código');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const BootPage()),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      debugPrint('🔑 Código ingresado: $code');

      // Validar código primero (sin autenticación, usando RPC para evitar RLS)
      debugPrint('🔍 Validando código de familia...');

      // Usar función RPC que evita recursión infinita de RLS
      final householdResponse = await SupabaseService.client.rpc(
        'validate_family_code',
        params: {'p_code': code},
      );

      if (householdResponse == null || householdResponse['id'] == null) {
        throw Exception('Código inválido');
      }

      final householdId = householdResponse['id'];
      final householdName = householdResponse['name'] ?? 'Grupo Familiar';

      debugPrint('✅ Código válido: $householdName');

      // Crear child_user (sub-cuenta) ligada al household
      debugPrint('👶 Creando child_user...');
      final childUserResponse = await SupabaseService.client.rpc(
        'create_child_user',
        params: {'p_family_code': code, 'p_display_name': 'Invitado'},
      );

      if (childUserResponse == null ||
          childUserResponse['child_user_id'] == null) {
        throw Exception('No se pudo crear child_user');
      }

      final childUserId = childUserResponse['child_user_id'];
      debugPrint('✅ Child user creado: $childUserId');

      // Guardar información del household para acceso temporal
      final userData = StorageService.userData ?? {};
      userData['child_user_id'] = childUserId;
      userData['guest_household_code'] = code;
      userData['guest_household_id'] = householdId;
      userData['guest_household_name'] = householdName;
      userData['is_guest'] = true;
      userData['guest_email'] = 'invitado_$code@temp';
      await StorageService.setUserData(userData);

      // Guardar en householdData también (para el widget)
      await StorageService.setHouseholdData({
        'household_id': householdId,
        'family_code': code,
        'is_guest': true,
        'household_name': householdName,
      });

      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Acceso temporal a "$householdName"'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar a home
        final args = {
          'userEmail': 'Invitado',
          'userType': models.UserType.family,
          'selectedRegion': userData['selected_region'] as String? ?? 'biobio',
          'selectedPark': userData['selected_park'] as String? ?? 'angostura',
        };

        Navigator.of(context).pushReplacementNamed('/home', arguments: args);
      }
    } catch (e) {
      debugPrint('❌ Error uniéndose como invitado: $e');
      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const BootPage()),
        );
      }
    }
  }

  /// Dialog simple para ingresar código de familia
  Future<String?> _showJoinFamilyCodeDialog() async {
    final TextEditingController codeController = TextEditingController();
    bool isValidating = false;
    bool isValid = false;
    String? householdName;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.family_restroom, color: Color(0xFF9C27B0)),
              SizedBox(width: 12),
              Expanded(child: Text('Código de Familia')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa el código del grupo familiar:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: 'Código (FAM-XXXXX)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.qr_code),
                    suffixIcon: isValidating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : isValid
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  autofocus: true,
                  onChanged: (value) async {
                    if (value.trim().startsWith('FAM-') &&
                        value.trim().length > 8) {
                      setState(() {
                        isValidating = true;
                        isValid = false;
                      });

                      try {
                        final response = await SupabaseService.client.rpc(
                          'validate_family_code',
                          params: {'p_code': value.trim()},
                        );

                        if (response != null && response['id'] != null) {
                          setState(() {
                            isValid = true;
                            householdName =
                                response['name'] ?? 'Grupo Familiar';
                          });
                        } else {
                          setState(() => isValid = false);
                        }
                      } catch (e) {
                        setState(() => isValid = false);
                      } finally {
                        setState(() => isValidating = false);
                      }
                    } else {
                      setState(() {
                        isValid = false;
                        isValidating = false;
                      });
                    }
                  },
                ),
                if (isValid && householdName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Familia: $householdName',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'ℹ️ Te unirás como invitado temporal. Al cerrar sesión, deberás volver a ingresar el código.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isValid
                  ? () {
                      final code = codeController.text.trim().toUpperCase();
                      Navigator.pop(context, code);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
              ),
              child: const Text('Unirse'),
            ),
          ],
        ),
      ),
    );
  }

  /// Maneja el flujo post-autenticación usando PostAuthRouter
  Future<void> _handlePostAuth(String userId, String email) async {
    if (_selectedUserType == null) {
      debugPrint('⚠️ _selectedUserType es null, navegando a BootPage');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const BootPage()),
        );
      }
      return;
    }

    debugPrint('🔄 Manejando post-auth:');
    debugPrint('   userId: $userId');
    debugPrint('   email: $email');
    debugPrint('   selectedUserType: $_selectedUserType');

    // Convertir UserType a UserMode
    UserMode userMode;
    switch (_selectedUserType!) {
      case UserType.guest:
        userMode = UserMode.individual;
        debugPrint('   → Modo: Individual (guest)');
        break;
      case UserType.family:
        userMode = UserMode.createFamily;
        debugPrint('   → Modo: Crear Familia');
        break;
      case UserType.joinFamily:
        userMode = UserMode.joinFamily;
        debugPrint('   → Modo: Unirse a Familia');
        break;
    }

    try {
      await PostAuthRouter.route(
        context: context,
        ref: ref,
        mode: userMode,
        userId: userId,
        email: email,
      );
    } catch (e) {
      debugPrint('❌ Error en PostAuthRouter: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        // Fallback a BootPage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const BootPage()),
        );
      }
    }
  }
}
