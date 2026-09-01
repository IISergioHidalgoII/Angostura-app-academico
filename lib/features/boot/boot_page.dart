import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/user_type.dart';
import '../../core/services/storage_service.dart';
import '../onboarding/pages/onboarding_page.dart' show OnboardingPage;
import '../user_mode/user_mode_selector_page.dart';

/// Pantalla de arranque que determina la ruta inicial según el estado de la app
class BootPage extends StatefulWidget {
  const BootPage({super.key});

  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage> {
  @override
  void initState() {
    super.initState();
    _determineInitialRoute();
  }

  /// Determina la ruta inicial según estado persistido y sesión
  Future<void> _determineInitialRoute() async {
    // Pequeño delay para mostrar splash
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      // Leer estado de sesión
      final currentUser = Supabase.instance.client.auth.currentUser;
      final hasSession = currentUser != null;

      // Leer flags de storage
      final hasSeenWelcome = StorageService.hasSeenWelcome;
      final hasCompletedSetup = StorageService.hasCompletedInitialSetup;

      debugPrint('🔄 BootPage - Determinando ruta inicial:');
      debugPrint('   hasSession: $hasSession');
      debugPrint('   hasSeenWelcome: $hasSeenWelcome');
      debugPrint('   hasCompletedSetup: $hasCompletedSetup');

      // REGLA 0: Si no tiene region/park, SIEMPRE ir a onboarding
      // (sin importar sesión o flags)
      if (!_hasBasicOnboardingData()) {
        debugPrint(
          '   → Sin datos básicos (region/park), navegando a Onboarding',
        );
        // Resetear flags para empezar limpio
        await StorageService.setHasSeenWelcome(false);
        await StorageService.setHasCompletedInitialSetup(false);
        _navigateToOnboarding();
        return;
      }

      // REGLA 1: Si tiene sesión activa
      if (hasSession) {
        debugPrint('   → Usuario con sesión activa');
        if (_isSetupDataValid()) {
          debugPrint('   → Datos válidos, navegando a MainApp');
          _navigateToMainApp();
        } else {
          debugPrint(
            '   → Datos incompletos (falta userMode), navegando a UserModeSelector',
          );
          _navigateToUserModeSelector();
        }
        return;
      }

      // REGLA 2: Sin sesión, pero setup completo
      if (hasCompletedSetup) {
        debugPrint('   → Sin sesión pero setup completo');
        if (_isSetupDataValid()) {
          debugPrint('   → Datos válidos, navegando a MainApp (guest)');
          _navigateToMainApp();
        } else {
          debugPrint(
            '   → Datos incompletos (falta userMode), navegando a UserModeSelector',
          );
          _navigateToUserModeSelector();
        }
        return;
      }

      // REGLA 3: Ha visto welcome (completó region/park) pero setup incompleto
      // Debe ir a UserModeSelector para autenticarse
      if (hasSeenWelcome && !hasCompletedSetup) {
        debugPrint(
          '   → Welcome visto (region/park configurados) pero sin autenticación',
        );
        debugPrint('   → Navegando a UserModeSelector');
        _navigateToUserModeSelector();
        return;
      }

      // REGLA 4: Primera vez (no ha visto welcome)
      debugPrint('   → Primera vez, navegando a Onboarding');
      _navigateToOnboarding();
    } catch (e) {
      debugPrint('❌ Error en BootPage: $e');
      // En caso de error, ir a onboarding por seguridad
      if (mounted) {
        _navigateToOnboarding();
      }
    }
  }

  /// Valida que existan todos los datos necesarios para MainApp
  bool _isSetupDataValid() {
    try {
      final userData = StorageService.userData ?? {};
      final userMode = StorageService.userMode;
      final region = userData['selected_region'];
      final park = userData['selected_park'];

      final isValid =
          userMode != null &&
          userMode.isNotEmpty &&
          region != null &&
          region is String &&
          region.isNotEmpty &&
          park != null &&
          park is String &&
          park.isNotEmpty;

      if (!isValid) {
        debugPrint('⚠️ Datos de setup inválidos:');
        debugPrint('   userMode: $userMode');
        debugPrint('   region: $region');
        debugPrint('   park: $park');
      }

      return isValid;
    } catch (e) {
      debugPrint('❌ Error validando setup data: $e');
      return false;
    }
  }

  /// Valida si existen region y park (datos básicos del onboarding)
  bool _hasBasicOnboardingData() {
    try {
      final userData = StorageService.userData ?? {};
      final region = userData['selected_region'];
      final park = userData['selected_park'];

      return region != null &&
          region is String &&
          region.isNotEmpty &&
          park != null &&
          park is String &&
          park.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Parsea el string de userMode a enum UserType (Parses the user mode string to UserType enum)
  UserType? _parseUserType(String userModeStr) {
    if (userModeStr.contains('guest') || userModeStr.contains('individual')) return UserType.guest;
    if (userModeStr.contains('family') || userModeStr.contains('createFamily') || userModeStr.contains('joinFamily')) {
      return UserType.family;
    }
    return UserType.guest; // fallback seguro (safe fallback)
  }

  void _navigateToMainApp() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userData = StorageService.userData ?? {};
    final userModeStr = StorageService.userMode!;

    Navigator.of(context).pushReplacementNamed(
      '/home',
      arguments: {
        'userEmail': currentUser?.email ?? userData['email'] as String?,
        'userType': _parseUserType(userModeStr),
        'selectedRegion': userData['selected_region'] as String,
        'selectedPark': userData['selected_park'] as String,
      },
    );
  }

  void _navigateToUserModeSelector() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const UserModeSelectorPage()),
    );
  }

  void _navigateToOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const OnboardingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E7D32),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo o icono de la app
              Icon(Icons.park, size: 80, color: Colors.white),
              SizedBox(height: 24),
              Text(
                'AngosturApp',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 48),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
