import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/models/user_type.dart' as models;
import 'features/onboarding/pages/onboarding_page.dart' show UserType;
import 'features/boot/boot_page.dart';
import 'features/user_mode/user_mode_selector_page.dart';
// ignore: unused_import
import 'features/auth/presentation/user_mode_selection_page.dart';
// ignore: unused_import
import 'features/auth/presentation/auth_flow_page.dart';
import 'core/services/supabase_service.dart';
import 'core/services/offline_storage_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/season_detector_service.dart';
import 'core/services/auth_service.dart';
import 'core/routing/post_auth_router.dart';
import 'core/providers/user_mode_provider.dart';
import 'core/theme/season_theme.dart';
import 'features/qr_scanner/pages/qr_scanner_page.dart';
import 'features/collection/pages/collection_page.dart';
import 'features/market/presentation/market_page.dart';
import 'features/explore/presentation/explore_page.dart';
import 'features/notifications/presentation/notifications_page.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/rewards/pages/rewards_page.dart';
import 'shared/widgets/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize Storage Service (must be before OfflineStorage)
  await StorageService.init();

  // Initialize Offline Storage
  await OfflineStorageService.init();

  // Initialize Supabase
  await SupabaseService.init();

  runApp(const ProviderScope(child: AngosturaApp()));
}

class AngosturaApp extends StatefulWidget {
  const AngosturaApp({super.key});

  @override
  State<AngosturaApp> createState() => _AngosturaAppState();
}

class _AngosturaAppState extends State<AngosturaApp> {
  late SeasonColors _seasonColors;
  late String _currentSeason;

  @override
  void initState() {
    super.initState();
    _currentSeason = SeasonDetectorService.getCurrentSeason();
    _seasonColors = SeasonTheme.getColorsForSeason(_currentSeason);
    SeasonDetectorService.logCurrentSeason();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AngosturApp',
      theme: _buildSeasonTheme(),
      home: const BootPage(),
      debugShowCheckedModeBanner: false,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/boot':
            return MaterialPageRoute(builder: (context) => const BootPage());
          case '/home':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => MainApp(
                userEmail:
                    args?['userEmail'] as String? ?? 'usuario@angostura.local',
                userType: args?['userType'] as models.UserType?,
                selectedRegion: args?['selectedRegion'] as String? ?? 'biobio',
                selectedPark: args?['selectedPark'] as String? ?? 'angostura',
              ),
            );
          case '/onboarding':
            return MaterialPageRoute(
              builder: (context) => const SimpleOnboardingScreen(),
            );
          case '/user-mode-selector':
            return MaterialPageRoute(
              builder: (context) => const UserModeSelectorPage(),
            );
          case '/mode-selection':
            return MaterialPageRoute(
              builder: (context) => const UserModeSelectionPage(),
            );
          case '/auth':
            return MaterialPageRoute(
              builder: (context) => const AuthFlowPage(),
            );
          default:
            return null;
        }
      },
      routes: {
        '/boot': (context) => const BootPage(),
        '/home': (context) => MainApp(
          userEmail: 'usuario@angostura.local',
          userType: models.UserType.guest,
          selectedRegion: 'biobio',
          selectedPark: 'angostura',
        ),
        '/onboarding': (context) => const SimpleOnboardingScreen(),
        '/user-mode-selector': (context) => const UserModeSelectorPage(),
      },
    );
  }

  /// Construye el tema de la app según la temporada actual
  ThemeData _buildSeasonTheme() {
    return ThemeData(
      useMaterial3: true,

      // Color primario de la temporada
      primaryColor: _seasonColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seasonColors.primary,
        primary: _seasonColors.primary,
        secondary: _seasonColors.secondary,
        tertiary: _seasonColors.accent,
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: _seasonColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // FloatingActionButton theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _seasonColors.primary,
        foregroundColor: Colors.white,
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _seasonColors.primary,
          foregroundColor: Colors.white,
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade200,
        selectedColor: _seasonColors.primary,
        labelStyle: const TextStyle(fontSize: 13),
      ),

      // Progress indicators
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: _seasonColors.primary,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _seasonColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

/// Onboarding simplificado que funciona sin Bloc
class SimpleOnboardingScreen extends ConsumerStatefulWidget {
  const SimpleOnboardingScreen({super.key});

  @override
  ConsumerState<SimpleOnboardingScreen> createState() =>
      _SimpleOnboardingScreenState();
}

class _SimpleOnboardingScreenState
    extends ConsumerState<SimpleOnboardingScreen> {
  int _currentStep = 0;
  String? _selectedRegion;
  String? _selectedPark;
  UserType? _selectedUserType;
  bool _isAuthenticating = false;
  String? _userEmail;
  bool _isSupabaseConnected = false;
  String? _connectionError;

  final List<String> _steps = [
    'Bienvenida',
    'Reglas',
    'Tutorial',
    'Región',
    'Parque',
    'Tipo de usuario',
    'Autenticación',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E8),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Progress indicator
                    _buildProgressIndicator(),

                    const SizedBox(height: 32),

                    // Current step content
                    Expanded(child: _buildStepContent()),

                    // Navigation buttons
                    _buildNavigationButtons(),
                  ],
                ),
              ),

              // Botón flotante de Modo Desarrollador
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orangeAccent, width: 2),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _enterDevMode,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.code,
                              color: Colors.orangeAccent,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'DEV',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        const Text(
          '🏠 Configuración Angostura',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: (_currentStep + 1) / _steps.length,
          backgroundColor: Colors.white.withAlpha(77),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8F00)),
        ),
        const SizedBox(height: 8),
        Text(
          'Paso ${_currentStep + 1} de ${_steps.length}: ${_steps[_currentStep]}',
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildRulesStep();
      case 2:
        return _buildTutorialStep();
      case 3:
        return _buildRegionStep();
      case 4:
        return _buildParkStep();
      case 5:
        return _buildUserTypeStep();
      case 6:
        return _buildAuthStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeStep() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🌿', style: TextStyle(fontSize: 80)),
          SizedBox(height: 24),
          Text(
            '¡Bienvenido a AngosturApp!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            'Descubre la biodiversidad de la precordillera del Biobío en el Parque Angostura. Aprende sobre conservación y apoya el turismo sustentable.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRulesStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            '📋 Reglas del Parque',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildRuleItem('🌿', 'Respeta la flora y fauna'),
                _buildRuleItem('🚶‍♂️', 'Sigue los senderos marcados'),
                _buildRuleItem('🚯', 'No alimentes a los animales'),
                _buildRuleItem('📷', 'Fotografía sin flash'),
                _buildRuleItem('🧙‍♂️', 'Mantén el silencio'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String emoji, String rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              rule,
              style: const TextStyle(fontSize: 16, color: Color(0xFF2E7D32)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialStep() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('📱', style: TextStyle(fontSize: 80)),
          SizedBox(height: 24),
          Text(
            'Cómo funciona la app',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          SizedBox(height: 16),
          Text(
            '1. Escanea códigos QR en el parque\n'
            '2. Colecciona cartas de especies\n'
            '3. Gana puntos EcoAngostura\n'
            '4. Canjea recompensas locales',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              height: 1.8,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRegionStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            '🗺️ Selecciona tu Región',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildRegionCard(
                  'biobio',
                  'Región del Biobío',
                  'Precordillera, embalses y biodiversidad del centro-sur de Chile',
                ),
                _buildRegionCard(
                  'araucania',
                  'Región de La Araucanía',
                  'Próximamente disponible',
                  isEnabled: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionCard(
    String id,
    String name,
    String description, {
    bool isEnabled = true,
  }) {
    final isSelected = _selectedRegion == id;

    return GestureDetector(
      onTap: isEnabled ? () => setState(() => _selectedRegion = id) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(
              '🏞️',
              style: TextStyle(
                fontSize: 32,
                color: isEnabled ? null : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isEnabled ? const Color(0xFF1B5E20) : Colors.grey,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isEnabled ? const Color(0xFF666666) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
          ],
        ),
      ),
    );
  }

  Widget _buildParkStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            '🏞️ Selecciona tu Parque',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildParkCard(
                  'angostura',
                  'Parque Angostura',
                  'Zona cordillerana con embalse Colbún, bosque nativo y biodiversidad',
                  127,
                ),
                _buildParkCard(
                  'nonguen',
                  'Reserva Nacional Nonguén',
                  'Bosque nativo y senderos educativos',
                  89,
                  isEnabled: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParkCard(
    String id,
    String name,
    String description,
    int species, {
    bool isEnabled = true,
  }) {
    final isSelected = _selectedPark == id;

    return GestureDetector(
      onTap: isEnabled ? () => setState(() => _selectedPark = id) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '🌿',
                  style: TextStyle(
                    fontSize: 32,
                    color: isEnabled ? null : Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isEnabled
                              ? const Color(0xFF1B5E20)
                              : Colors.grey,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: isEnabled
                              ? const Color(0xFF666666)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
              ],
            ),
            if (isEnabled) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$species especies disponibles',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserTypeStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            '👥 ¿Cómo deseas usar la app?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Column(
              children: [
                _buildUserTypeCard(
                  UserType.guest,
                  '🚶‍♂️',
                  'Visitante Individual',
                  'Explora solo, sin grupo',
                  const Color(0xFF2196F3),
                ),
                const SizedBox(height: 16),
                _buildUserTypeCard(
                  UserType.family,
                  '👨‍👩‍👧‍👦',
                  'Crear Grupo Familiar',
                  'Inicia tu propio grupo',
                  const Color(0xFFFF8F00),
                ),
                const SizedBox(height: 16),
                _buildUserTypeCard(
                  UserType.joinFamily,
                  '👥',
                  'Unirse a Grupo Familiar',
                  'Usa un código de familia',
                  const Color(0xFF9C27B0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeCard(
    UserType type,
    String emoji,
    String title,
    String description,
    Color color,
  ) {
    final isSelected = _selectedUserType == type;

    return GestureDetector(
      onTap: () async {
        // Si selecciona joinFamily, pedir código inmediatamente
        if (type == UserType.joinFamily) {
          await _handleJoinFamilyInOnboarding();
        } else {
          setState(() => _selectedUserType = type);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withAlpha(51),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : const Color(0xFF1B5E20),
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            _selectedUserType == UserType.family
                ? '👨‍👩‍👧‍👦'
                : _selectedUserType == UserType.joinFamily
                ? '👥'
                : '🚶‍♂️',
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 24),
          const Text(
            '¡Último paso!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 16),

          // Estado de conexión a Supabase
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isSupabaseConnected
                  ? const Color(0xFFE8F5E8)
                  : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isSupabaseConnected
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF8F00),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isSupabaseConnected ? Icons.check_circle : Icons.cloud,
                  color: _isSupabaseConnected
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF8F00),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSupabaseConnected
                            ? 'Conectado a Supabase'
                            : 'Verificando conexión...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isSupabaseConnected
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE65100),
                        ),
                      ),
                      if (_connectionError != null)
                        Text(
                          _connectionError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Mostrar email si está autenticado
          if (_userEmail != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF1976D2)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cuenta conectada',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                        Text(
                          _userEmail!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Botones de autenticación
          if (_userEmail == null) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isAuthenticating ? null : _signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1B5E20),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isAuthenticating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Conectando...', style: TextStyle(fontSize: 16)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🔑', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 12),
                          Text(
                            'Continuar con Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isAuthenticating ? null : _continueAsGuest,
              child: const Text(
                'Continuar sin cuenta (modo invitado)',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _completeOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Continuar a la aplicación',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Atrás'),
            ),
          ),

        if (_currentStep > 0) const SizedBox(width: 16),

        Expanded(
          child: ElevatedButton(
            onPressed: _canContinue() ? _nextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: Colors.grey,
            ),
            child: Text(
              _currentStep < _steps.length - 1 ? 'Continuar' : 'Finalizar',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  bool _canContinue() {
    switch (_currentStep) {
      case 0: // Welcome
      case 1: // Rules
      case 2: // Tutorial
        return true;
      case 3: // Region
        return _selectedRegion != null;
      case 4: // Park
        return _selectedPark != null;
      case 5: // User type
        return _selectedUserType != null;
      case 6: // Auth
        // Para family, requerir autenticación
        if (_selectedUserType == models.UserType.family) {
          return _userEmail != null;
        }
        // Para guest, permitir continuar sin auth
        return true;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _completeOnboarding();
    }
  }

  @override
  void initState() {
    super.initState();
    _checkSupabaseConnection();
  }

  Future<void> _checkSupabaseConnection() async {
    try {
      // Verificar conexión real consultando la tabla sites
      final client = Supabase.instance.client;

      // Verificando tabla sites...

      final response = await client
          .from('sites')
          .select('id, name, region, is_active')
          .limit(10);

      // Sitios encontrados: ${response.length}

      setState(() {
        _isSupabaseConnected = true;
        _connectionError = null;
      });

      // Conexión a Supabase exitosa

      // Si no hay sitios, crear datos de ejemplo
      if (response.isEmpty) {
        // No se encontraron sitios, creando datos de ejemplo...
        await _createSampleData();
      }
    } catch (e) {
      setState(() {
        _isSupabaseConnected = false;
        if (e.toString().contains('Invalid API Key') ||
            e.toString().contains('401')) {
          _connectionError = 'Clave API inválida';
        } else if (e.toString().contains('relation') &&
            e.toString().contains('does not exist')) {
          _connectionError =
              'Esquema de BD no encontrado - Ejecutar SQL de setup';
        } else if (e.toString().contains('NetworkException') ||
            e.toString().contains('SocketException')) {
          _connectionError = 'Sin conexión a internet';
        } else {
          _connectionError =
              'Error: ${e.toString().length > 50 ? '${e.toString().substring(0, 50)}...' : e.toString()}';
        }
      });

      debugPrint('Error de conexión Supabase: $e');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isAuthenticating = true;
    });

    try {
      // Simulamos autenticación con Google (para demo)
      await Future.delayed(const Duration(seconds: 2));

      // En producción, aquí iría la autenticación real con Google
      const demoEmail = 'usuario@ejemplo.com';

      setState(() {
        _userEmail = demoEmail;
        _isAuthenticating = false;
      });

      // Simular guardado en Supabase
      await _saveUserDemo();
    } catch (e) {
      setState(() {
        _isAuthenticating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de autenticación: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveUserDemo() async {
    try {
      if (_userEmail == null) {
        throw Exception('Email no proporcionado');
      }

      debugPrint('💾 Guardando usuario demo: $_userEmail');

      // Para usuarios guest, solo guardar datos localmente
      if (_selectedUserType == models.UserType.guest) {
        debugPrint('   Tipo: Guest - Sin household');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Continuando como invitado'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // Para familia, crear usuario y household
      if (_selectedPark == null) {
        throw Exception('Parque no seleccionado');
      }

      // Buscar el sitio seleccionado
      final client = Supabase.instance.client;
      final siteResponse = await client
          .from('sites')
          .select('id, name')
          .eq(
            'name',
            _selectedPark == 'angostura'
                ? 'Parque Humedal Angostura del Biobío'
                : _selectedPark!,
          )
          .limit(1);

      if (siteResponse.isEmpty) {
        throw Exception('Sitio no encontrado');
      }

      final siteId = siteResponse.first['id'];

      // Usar el nuevo servicio de autenticación para crear el usuario completo
      await AuthService.setupNewUser(
        email: _userEmail!,
        siteId: siteId,
        userType: 'Familia',
        displayName: _userEmail?.split('@')[0],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Usuario y grupo familiar creados!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error guardando usuario: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _createSampleData() async {
    try {
      final client = Supabase.instance.client;

      // Crear sitios de ejemplo
      final sitesData = [
        {
          'name': 'Parque Angostura',
          'region': 'Región del Biobío',
          'description':
              'Zona cordillerana con embalse Colbún, bosque nativo y biodiversidad',
          'latitude': -35.7,
          'longitude': -71.416667,
          'is_active': true,
        },
        {
          'name': 'Reserva Nacional Nonguén',
          'region': 'Región del Biobío',
          'description': 'Bosque nativo y senderos educativos',
          'latitude': -36.8500,
          'longitude': -73.0000,
          'is_active': true,
        },
      ];

      for (var siteData in sitesData) {
        await client.from('sites').insert(siteData);
        // Sitio creado: ${siteData['name']}
      }

      // Obtener el sitio de Angostura para crear áreas y cartas
      final angosturaResponse = await client
          .from('sites')
          .select('id')
          .eq('name', 'Parque Angostura')
          .single();

      final siteId = angosturaResponse['id'];

      // Crear áreas
      final areasData = [
        {
          'site_id': siteId,
          'name': 'Embalse Colbún',
          'description': 'Zona del embalse Colbún, el más grande de Chile',
        },
        {
          'site_id': siteId,
          'name': 'Sendero del Bosque',
          'description': 'Zona boscosa con especies nativas',
        },
        {
          'site_id': siteId,
          'name': 'Mirador Norte',
          'description': 'Punto elevado para observación panorámica',
        },
      ];

      await client.from('areas').insert(areasData);
      // 3 áreas creadas para Angostura

      // Obtener área para crear cartas
      final areaResponse = await client
          .from('areas')
          .select('id')
          .eq('site_id', siteId)
          .limit(1)
          .single();

      final areaId = areaResponse['id'];

      // Crear algunas cartas de ejemplo
      final cardsData = [
        {
          'site_id': siteId,
          'area_id': areaId,
          'title': 'Tagua Común',
          'code': 'ANG001',
          'rarity': 'común',
        },
        {
          'site_id': siteId,
          'area_id': areaId,
          'title': 'Cisne de Cuello Negro',
          'code': 'ANG002',
          'rarity': 'poco_común',
        },
        {
          'site_id': siteId,
          'area_id': areaId,
          'title': 'Flamenco Chileno',
          'code': 'ANG003',
          'rarity': 'raro',
        },
      ];

      await client.from('cards').insert(cardsData);
      // 3 cartas de especies creadas

      // Refrescar la verificación de sitios
      setState(() {});
      _checkSupabaseConnection();
    } catch (e) {
      debugPrint('Error creando datos de ejemplo: $e');
    }
  }

  Future<void> _continueAsGuest() async {
    await _completeOnboarding();
  }

  Future<void> _handleJoinFamilyInOnboarding() async {
    final TextEditingController codeController = TextEditingController();
    bool isValidating = false;
    bool isValid = false;
    String? householdId;
    String? householdName;

    final result = await showDialog<bool>(
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
              Text('Código de Familia'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresa el código de tu grupo familiar para unirte',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
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
                          householdId = response['id'];
                          householdName = response['name'] ?? 'Grupo Familiar';
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isValid
                  ? () async {
                      try {
                        debugPrint('🔘 Botón Unirse presionado');
                        debugPrint('   household_id: $householdId');
                        debugPrint('   household_name: $householdName');

                        // 1. Crear cuenta anónima en Supabase
                        debugPrint('🔐 Creando cuenta anónima...');
                        final authResponse = await Supabase.instance.client.auth
                            .signInAnonymously();
                        final anonUserId = authResponse.user?.id;

                        if (anonUserId == null) {
                          throw Exception('No se pudo crear cuenta anónima');
                        }

                        debugPrint('✅ Cuenta anónima creada: $anonUserId');

                        // 2. Vincular al household en household_members
                        debugPrint('🔗 Vinculando a household...');
                        await SupabaseService.client
                            .from('household_members')
                            .insert({
                              'household_id': householdId,
                              'user_id': anonUserId,
                              'role': 'guest',
                              'joined_at': DateTime.now().toIso8601String(),
                            });

                        debugPrint('✅ Vinculado a household exitosamente');

                        // 3. Guardar datos localmente
                        await StorageService.setHouseholdData({
                          'household_id': householdId,
                          'household_name': householdName,
                          'family_code': codeController.text.trim(),
                          'role': 'guest',
                          'joined_at': DateTime.now().toIso8601String(),
                        });

                        await StorageService.setUserData({
                          'user_id': anonUserId,
                          'user_type': 'joinFamily',
                          'household_id': householdId,
                        });

                        debugPrint('💾 Datos guardados en Storage');

                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      } catch (e) {
                        debugPrint('❌ Error al unirse: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al unirse: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
              ),
              child: const Text('Unirse'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _selectedUserType = UserType.joinFamily;
        debugPrint('✅ _selectedUserType actualizado a: $_selectedUserType');
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Unido a: $householdName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      debugPrint('❌ Dialog cerrado sin completar (result = $result)');
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      // VALIDACIÓN CRÍTICA: Solo family (crear) requiere autenticación
      // joinFamily puede ser sin autenticación (invitado temporal)
      if (_selectedUserType == UserType.family) {
        final currentUser = Supabase.instance.client.auth.currentUser;

        if (currentUser == null || _userEmail == null) {
          debugPrint('❌ BLOQUEADO: Crear familia sin autenticación');
          debugPrint('   Current User: ${currentUser?.email}');
          debugPrint('   User Email: $_userEmail');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '❌ Debes crear una cuenta para tu grupo familiar',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return; // NO permitir continuar
        }

        debugPrint(
          '✅ Validación pasada: Usuario autenticado para crear familia',
        );
      }

      // Guardar en Storage
      await StorageService.setOnboardingCompleted(true);

      if (_userEmail != null) {
        final userData = StorageService.userData ?? {};
        userData['email'] = _userEmail;
        userData['user_type'] = _selectedUserType.toString();
        await StorageService.setUserData(userData);
      }

      if (_selectedRegion != null) {
        final userData = StorageService.userData ?? {};
        userData['selected_region'] = _selectedRegion;
        await StorageService.setUserData(userData);
      }

      if (_selectedPark != null) {
        final userData = StorageService.userData ?? {};
        userData['selected_park'] = _selectedPark;
        await StorageService.setUserData(userData);
      }

      // Para usuarios guest sin autenticación, navegar directo
      if (_selectedUserType == UserType.guest && _userEmail == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MainApp(
                userEmail: _userEmail,
                userType: _convertToModelsUserType(_selectedUserType),
                selectedRegion: _selectedRegion,
                selectedPark: _selectedPark,
              ),
            ),
          );
        }
        return;
      }

      // Para usuarios autenticados, usar PostAuthRouter
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && _userEmail != null && mounted) {
        // Convertir UserType a UserMode
        UserMode userMode;
        switch (_selectedUserType) {
          case UserType.family:
            userMode = UserMode.createFamily;
            break;
          case UserType.joinFamily:
            userMode = UserMode.joinFamily;
            break;
          case UserType.guest:
            userMode = UserMode.individual;
            break;
          default:
            userMode = UserMode.individual;
        }

        await PostAuthRouter.route(
          context: context,
          ref: ref,
          mode: userMode,
          userId: currentUser.id,
          email: _userEmail!,
        );
      } else {
        // Fallback: navegar directo si no hay usuario autenticado
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MainApp(
                userEmail: _userEmail,
                userType: _convertToModelsUserType(_selectedUserType),
                selectedRegion: _selectedRegion,
                selectedPark: _selectedPark,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error en _completeOnboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _enterDevMode() {
    // Saltar directamente a la app en modo desarrollador
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.code, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Modo Desarrollador'),
          ],
        ),
        content: const Text(
          '¿Entrar a la app sin configuración?\n\n'
          'Ideal para demos y pruebas rápidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const MainApp(
                    userEmail: 'dev@angostura.local',
                    userType: models.UserType.guest,
                    selectedRegion: 'maule',
                    selectedPark: 'angostura',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Entrar como DEV'),
          ),
        ],
      ),
    );
  }

  /// Convierte UserType de onboarding a models.UserType
  models.UserType? _convertToModelsUserType(UserType? userType) {
    if (userType == null) return null;

    switch (userType) {
      case UserType.guest:
        return models.UserType.guest;
      case UserType.family:
      case UserType.joinFamily:
        return models.UserType.family;
    }
  }
}

class MainApp extends StatefulWidget {
  final String? userEmail;
  final models.UserType? userType;
  final String? selectedRegion;
  final String? selectedPark;

  const MainApp({
    super.key,
    this.userEmail,
    this.userType,
    this.selectedRegion,
    this.selectedPark,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  void changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Páginas/módulos de la app (orden: Inicio, Explorar, QR, Colección, Market)
  List<Widget> get _pages => [
    const _HomePage(),
    const ExplorePage(),
    const QRScannerPage(),
    const CollectionPage(key: ValueKey('collection_page')),
    const MarketPage(),
  ];

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ ============================================');
    debugPrint('🏗️ MainApp.build() INICIADO');
    debugPrint('🏗️ _currentIndex: $_currentIndex');
    debugPrint('🏗️ ============================================');
    
    // Obtener altura real del BottomNavigationBar con escalado de resolución
    final bottomNavBarHeight =
        kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom;

    // Calcular posición del banner: 20% más abajo que antes
    final bannerBottomPosition = (bottomNavBarHeight + 4) * 0.8;

    final seasonColors = SeasonTheme.getColorsForSeason(
      SeasonDetectorService.getCurrentSeason(),
    );

    debugPrint('📦 Renderizando página en índice: $_currentIndex');
    debugPrint('📦 Página a renderizar: ${_pages[_currentIndex].runtimeType}');
    
    return Scaffold(
      backgroundColor: seasonColors.cardBackground,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _pages),
          // Banner flotante sobre la navbar
          Positioned(
            bottom: bannerBottomPosition,
            left: 0,
            right: 0,
            child: const OfflineBanner(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: seasonColors.cardBackground,
        currentIndex: _currentIndex,
        onTap: (index) async {
          // Si está cambiando al tab de QR, esperar el resultado
          if (index == 2) {
            debugPrint('📱 Abriendo QR Scanner...');
            final result = await Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const QRScannerPage()));

            debugPrint('🔍 Resultado del QR Scanner: $result');

            // Si el resultado indica que debe ir a Colección
            if (result is Map && result['navigateToCollection'] == true) {
              final cardId = result['cardId'];
              debugPrint('✅ Cambiando a tab de Colección con cardId: $cardId');
              debugPrint('🔧 ANTES de setState - _currentIndex actual: $_currentIndex');
              setState(() {
                debugPrint('🔧 DENTRO de setState - cambiando _currentIndex a 3');
                _currentIndex = 3; // Tab de Colección
              });
              debugPrint('🔧 DESPUÉS de setState - _currentIndex ahora: $_currentIndex');
              debugPrint('🎬 setState completado, Flutter debería renderizar tab 3 (CollectionPage)');
            } else {
              debugPrint('ℹ️ QR Scanner cerrado sin navegar a colección');
            }
          } else {
            debugPrint('📑 Cambiando a tab normal: $index');
            setState(() {
              _currentIndex = index;
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explorar'),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'QR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.collections),
            label: 'Colección',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Market'),
        ],
      ),
    );
  }
}

// Página de inicio (Home/Dashboard)
class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  late Future<Map<String, int>> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressFuture = _loadProgress();
  }

  Future<Map<String, int>> _loadProgress() async {
    try {
      final userId =
          Supabase.instance.client.auth.currentUser?.id ?? 'guest-user-id';
      final userCards = await SupabaseService.getUserCardsCount(userId);
      final totalCards = await SupabaseService.getTotalCardsCount();
      return {'userCards': userCards, 'totalCards': totalCards};
    } catch (e) {
      debugPrint('Error loading progress: $e');
      return {'userCards': 0, 'totalCards': 0};
    }
  }

  void _navigateToTab(int tabIndex) {
    final mainAppState = context.findAncestorStateOfType<_MainAppState>();
    mainAppState?.changeTab(tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Obtener tema de temporada actual
    final seasonColors = SeasonTheme.getColorsForSeason(
      SeasonDetectorService.getCurrentSeason(),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [seasonColors.gradient1, seasonColors.gradient2],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Barra superior
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Botón de novedades
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  // Botón de ajustes
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // Contenido principal
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Widget de código familiar (si existe)
                    _buildFamilyCodeWidget(),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          const Text('🌿', style: TextStyle(fontSize: 80)),
                          const SizedBox(height: 24),
                          const Text(
                            'Angostura Colbún',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B5E20),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Explora el parque, escanea códigos QR y colecciona cartas de especies nativas.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF666666),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Dashboard de progreso
                          FutureBuilder<Map<String, int>>(
                            future: _progressFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final userCards =
                                  snapshot.data?['userCards'] ?? 0;
                              final totalCards =
                                  snapshot.data?['totalCards'] ?? 0;
                              return Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4CAF50),
                                      Color(0xFF66BB6A),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tu Progreso',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Cartas Coleccionadas',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '$userCards/$totalCards',
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 32),

                          // Cards de acceso rápido
                          _buildQuickAccessCard(
                            context: context,
                            icon: Icons.qr_code_scanner,
                            title: 'Escanear QR',
                            description: 'Descubre nuevas especies',
                            color: const Color(0xFF2196F3),
                            onTap: () => _navigateToTab(2),
                          ),
                          const SizedBox(height: 12),
                          _buildQuickAccessCard(
                            context: context,
                            icon: Icons.store,
                            title: 'Mercado Local',
                            description: 'Emprendedores del parque',
                            color: const Color(0xFFFF8F00),
                            onTap: () => _navigateToTab(4),
                          ),
                          const SizedBox(height: 12),
                          _buildQuickAccessCard(
                            context: context,
                            icon: Icons.collections,
                            title: 'Mi Colección',
                            description: 'Ver cartas obtenidas',
                            color: const Color(0xFF4CAF50),
                            onTap: () => _navigateToTab(3),
                          ),
                          const SizedBox(height: 12),
                          _buildQuickAccessCard(
                            context: context,
                            icon: Icons.card_giftcard,
                            title: 'Recompensas',
                            description: 'Mis logros',
                            color: const Color(0xFF9C27B0),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RewardsPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyCodeWidget() {
    final householdData = StorageService.householdData;

    if (householdData == null || householdData['family_code'] == null) {
      return const SizedBox.shrink();
    }

    final familyCode = householdData['family_code'] as String;
    final isVerified = householdData['verified'] as bool? ?? false;
    final isNew = householdData['is_new'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8F00), Color(0xFFFFB300)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.family_restroom,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Código de Grupo Familiar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isVerified
                          ? '✅ Verificado'
                          : '⚠️ Pendiente de verificación',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  familyCode,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF8F00),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Comparte este código para que otros se unan',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (isNew && !isVerified) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.mail_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Revisa tu email para verificar tu grupo',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
