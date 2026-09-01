import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_service.dart';

enum UserType {
  guest, // Visitante solitario
  family, // Crear grupo familiar
  joinFamily, // Unirse a grupo familiar
}

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _currentStep = 0;
  String? _selectedRegion;
  String? _selectedPark;
  UserType? _selectedUserType;
  bool _isAuthenticating = false;
  String? _userEmail;
  String? _familyCode;
  final TextEditingController _familyCodeController = TextEditingController();
  bool _isSupabaseConnected = false;
  String? _connectionError;

  final List<String> _steps = [
    'Bienvenida',
    'Región',
    'Parque',
    'Reglas',
    'Tutorial',
    'Tipo de usuario',
    'Autenticación',
  ];

  // Datos para las opciones
  final List<Map<String, String>> _regions = [
    {
      'id': 'biobio',
      'name': 'Región del Biobío',
      'description':
          'Precordillera, embalses y biodiversidad del centro-sur de Chile',
    },
    {
      'id': 'araucania',
      'name': 'Región de La Araucanía',
      'description': 'Próximamente disponible',
    },
  ];

  final List<Map<String, dynamic>> _parks = [
    {
      'id': 'angostura',
      'name': 'Parque Angostura Colbún',
      'description': 'Zona cordillerana con embalse Colbún y bosque nativo',
      'species': 127,
      'region': 'biobio',
      'enabled': true,
    },
    {
      'id': 'nonguen',
      'name': 'Reserva Nacional Nonguén',
      'description': 'Bosque nativo y senderos educativos',
      'species': 89,
      'region': 'biobio',
      'enabled': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkSupabaseConnection();
  }

  @override
  void dispose() {
    _familyCodeController.dispose();
    super.dispose();
  }

  Future<void> _checkSupabaseConnection() async {
    try {
      final isConnected = await SupabaseService.testConnection();
      setState(() {
        _isSupabaseConnected = isConnected;
        _connectionError = null;
      });
      debugPrint('Conexión a Supabase: $isConnected');
    } catch (e) {
      setState(() {
        _isSupabaseConnected = false;
        _connectionError = e.toString().length > 50
            ? '${e.toString().substring(0, 50)}...'
            : e.toString();
      });
      debugPrint('Error de conexión Supabase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundLight),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(AppConstants.primaryGreen),
              Color(AppConstants.secondaryGreen),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              children: [
                _buildProgressIndicator(),
                const SizedBox(height: 32),
                Expanded(child: _buildCurrentStep()),
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        const Text(
          '🏠 ${AppConstants.appName}',
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
          valueColor: const AlwaysStoppedAnimation<Color>(
            Color(AppConstants.accentOrange),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Paso ${_currentStep + 1} de ${_steps.length}: ${_steps[_currentStep]}',
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: _getStepWidget(),
    );
  }

  Widget _getStepWidget() {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildRegionStep();
      case 2:
        return _buildParkStep();
      case 3:
        return _buildRulesStep();
      case 4:
        return _buildTutorialStep();
      case 5:
        return _buildUserTypeStep();
      case 6:
        return _buildAuthStep();
      default:
        return Center(
          child: Text(
            'Paso ${_currentStep + 1}\n${_steps[_currentStep]}',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        );
    }
  }

  Widget _buildWelcomeStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🌿', style: TextStyle(fontSize: 80)),
        const SizedBox(height: 24),
        const Text(
          '¡Bienvenido a AngosturApp!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(AppConstants.primaryGreen),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Tu guía interactiva para explorar, aprender y coleccionar la biodiversidad del parque. ¡Escanea QR y descubre especies!',
          style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
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
                          ? 'Conectado a la base de datos'
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
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRulesStep() {
    final screenHeight = MediaQuery.of(context).size.height;
    final dynamicFontSize = screenHeight < 700 ? 14.0 : 16.0;
    final dynamicTitleSize = screenHeight < 700 ? 20.0 : 24.0;
    final dynamicSpacing = screenHeight < 700 ? 8.0 : 12.0;
    final dynamicPadding = screenHeight < 700 ? 10.0 : 16.0;

    return Column(
      children: [
        Text(
          '📋 Reglas del Parque',
          style: TextStyle(
            fontSize: dynamicTitleSize,
            fontWeight: FontWeight.bold,
            color: const Color(AppConstants.primaryGreen),
          ),
        ),
        SizedBox(height: screenHeight < 700 ? 12 : 24),
        Expanded(
          child: ListView(
            children: [
              _buildRuleItem(
                '🌿',
                'Respeta la flora y fauna',
                dynamicFontSize,
                dynamicSpacing,
                dynamicPadding,
              ),
              _buildRuleItem(
                '🚶‍♂️',
                'Sigue los senderos marcados',
                dynamicFontSize,
                dynamicSpacing,
                dynamicPadding,
              ),
              _buildRuleItem(
                '🚯',
                'No alimentes a los animales',
                dynamicFontSize,
                dynamicSpacing,
                dynamicPadding,
              ),
              _buildRuleItem(
                '📷',
                'Fotografía sin flash',
                dynamicFontSize,
                dynamicSpacing,
                dynamicPadding,
              ),
              _buildRuleItem(
                '🤫',
                'Mantén el silencio',
                dynamicFontSize,
                dynamicSpacing,
                dynamicPadding,
              ),
              _buildRuleItem(
                '🗑️',
                'No dejes residuos',
                dynamicFontSize,
                dynamicSpacing,
                dynamicPadding,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuleItem(
    String emoji,
    String rule,
    double fontSize,
    double spacing,
    double padding,
  ) {
    final emojiSize = fontSize * 1.5;

    return Container(
      margin: EdgeInsets.only(bottom: spacing),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: emojiSize)),
          SizedBox(width: padding),
          Expanded(
            child: Text(
              rule,
              style: TextStyle(
                fontSize: fontSize,
                color: const Color(AppConstants.primaryGreen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialStep() {
    final screenHeight = MediaQuery.of(context).size.height;
    final dynamicEmojiSize = screenHeight < 700 ? 50.0 : 80.0;
    final dynamicTitleSize = screenHeight < 700 ? 20.0 : 24.0;
    final dynamicTitleSpacing = screenHeight < 700 ? 12.0 : 24.0;
    final dynamicContentSpacing = screenHeight < 700 ? 16.0 : 32.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('📱', style: TextStyle(fontSize: dynamicEmojiSize)),
        SizedBox(height: dynamicTitleSpacing),
        Text(
          'Cómo funciona la app',
          style: TextStyle(
            fontSize: dynamicTitleSize,
            fontWeight: FontWeight.bold,
            color: const Color(AppConstants.primaryGreen),
          ),
        ),
        SizedBox(height: dynamicContentSpacing),
        Expanded(
          child: ListView(
            children: [
              _buildTutorialItem(
                '1',
                'Escanea códigos QR',
                'Encuentra códigos QR en el parque y escanéalos',
              ),
              _buildTutorialItem(
                '2',
                'Colecciona cartas',
                'Cada QR te da una carta de especie única',
              ),
              _buildTutorialItem(
                '3',
                'Gana puntos',
                'Acumula puntos EcoAngostura por cada descubrimiento',
              ),
              _buildTutorialItem(
                '4',
                'Canjea recompensas',
                'Usa tus puntos en comercios locales',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTutorialItem(String number, String title, String description) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dynamicCircleSize = screenHeight < 700 ? 32.0 : 40.0;
    final dynamicNumberSize = screenHeight < 700 ? 14.0 : 18.0;
    final dynamicTitleSize = screenHeight < 700 ? 14.0 : 16.0;
    final dynamicDescSize = screenHeight < 700 ? 12.0 : 14.0;
    final dynamicSpacing = screenHeight < 700 ? 12.0 : 16.0;
    final dynamicPadding = screenHeight < 700 ? 12.0 : 16.0;

    return Container(
      margin: EdgeInsets.only(bottom: dynamicSpacing),
      padding: EdgeInsets.all(dynamicPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: dynamicCircleSize,
            height: dynamicCircleSize,
            decoration: BoxDecoration(
              color: const Color(AppConstants.primaryGreen),
              borderRadius: BorderRadius.circular(dynamicCircleSize / 2),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: dynamicNumberSize,
                ),
              ),
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
                    fontSize: dynamicTitleSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(AppConstants.primaryGreen),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: dynamicDescSize,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionStep() {
    return Column(
      children: [
        const Text(
          '🗺️ Selecciona tu Región',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(AppConstants.primaryGreen),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: _regions.length,
            itemBuilder: (context, index) {
              final region = _regions[index];
              final isEnabled = region['id'] == 'biobio';
              return _buildRegionCard(
                region['id']!,
                region['name']!,
                region['description']!,
                isEnabled: isEnabled,
              );
            },
          ),
        ),
      ],
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
            color: isSelected
                ? const Color(AppConstants.primaryGreen)
                : Colors.grey.shade300,
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
                      color: isEnabled
                          ? const Color(AppConstants.primaryGreen)
                          : Colors.grey,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isEnabled ? Colors.grey : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(AppConstants.primaryGreen),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkStep() {
    final availableParks = _parks
        .where((park) => park['region'] == _selectedRegion)
        .toList();

    return Column(
      children: [
        const Text(
          '🏞️ Selecciona tu Parque',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(AppConstants.primaryGreen),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: availableParks.length,
            itemBuilder: (context, index) {
              final park = availableParks[index];
              return _buildParkCard(
                park['id'],
                park['name'],
                park['description'],
                park['species'],
                isEnabled: park['enabled'],
              );
            },
          ),
        ),
      ],
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
            color: isSelected
                ? const Color(AppConstants.primaryGreen)
                : Colors.grey.shade300,
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
                              ? const Color(AppConstants.primaryGreen)
                              : Colors.grey,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: isEnabled ? Colors.grey : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(AppConstants.primaryGreen),
                  ),
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
                  color: const Color(AppConstants.primaryGreen).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$species especies disponibles',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(AppConstants.primaryGreen),
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
    return Column(
      children: [
        const Text(
          '👥 ¿Cómo visitas el parque?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(AppConstants.primaryGreen),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildUserTypeCard(
                  UserType.guest,
                  '🚶‍♂️',
                  'Visitante Individual',
                  'Explora por tu cuenta',
                  const Color(0xFF2196F3),
                ),
                const SizedBox(height: 16),
                _buildUserTypeCard(
                  UserType.family,
                  '👨‍👩‍👧‍👦',
                  'Crear Grupo Familiar',
                  'Experiencia grupal con actividades especiales',
                  const Color(0xFFFF8F00),
                ),
                const SizedBox(height: 16),
                _buildUserTypeCard(
                  UserType.joinFamily,
                  '🔗',
                  'Unirse a Grupo Familiar',
                  'Usa un código de familia',
                  const Color(0xFF9C27B0),
                ),
                const SizedBox(height: 40), // Espacio extra para scroll
              ],
            ),
          ),
        ),
      ],
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
      onTap: () => setState(() {
        _selectedUserType = type;
        if (type != UserType.joinFamily) {
          _familyCodeController.clear();
          _familyCode = null;
        }
      }),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? color
                          : const Color(AppConstants.primaryGreen),
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
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
    return Column(
      children: [
        Text(
          _selectedUserType == UserType.family
              ? '🔐 Configura tu Cuenta'
              : '🔐 Configura tu Cuenta (Opcional)',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(AppConstants.primaryGreen),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _selectedUserType == UserType.family
              ? 'Crea una cuenta para tu grupo familiar:'
              : 'Puedes crear una cuenta o continuar como invitado:',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),

        // Mostrar resumen del tipo de usuario seleccionado
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                _getEmojiForUserType(),
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTitleForUserType(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(AppConstants.primaryGreen),
                      ),
                    ),
                    if (_selectedUserType == UserType.joinFamily &&
                        _familyCode != null)
                      Text(
                        'Código: $_familyCode',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(AppConstants.primaryGreen),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        Expanded(
          child: Column(
            children: [
              if (_userEmail == null) ...[
                // Login Button (usuarios existentes)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isAuthenticating ? null : _showLoginDialog,
                    icon: const Icon(Icons.login, size: 24),
                    label: const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppConstants.primaryGreen),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Register Button (crear cuenta nueva)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isAuthenticating ? null : _showRegisterDialog,
                    icon: const Icon(Icons.person_add, size: 24),
                    label: const Text(
                      'Crear cuenta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(AppConstants.primaryGreen),
                      side: const BorderSide(
                        color: Color(AppConstants.primaryGreen),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                // Botón "Saltar" solo para visitantes
                if (_selectedUserType == UserType.guest) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      if (_currentStep < _steps.length - 1) {
                        setState(() => _currentStep++);
                      } else {
                        _completeOnboarding();
                      }
                    },
                    child: const Text(
                      'Saltar y continuar como invitado',
                      style: TextStyle(
                        color: Colors.grey,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // Mostrar cuenta configurada
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cuenta configurada:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _userEmail!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _userEmail = null;
                          });
                        },
                        child: const Text('Cambiar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botón para continuar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _completeOnboarding,
                    icon: const Icon(Icons.check, size: 24),
                    label: const Text(
                      'Continuar a la aplicación',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppConstants.primaryGreen),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Estado de conexión
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSupabaseConnected
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSupabaseConnected
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSupabaseConnected ? Icons.wifi : Icons.wifi_off,
                      color: _isSupabaseConnected
                          ? Colors.green
                          : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isSupabaseConnected
                            ? 'Conectado a la base de datos'
                            : 'Conexión limitada: ${_connectionError ?? 'Verificando...'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isSupabaseConnected
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    final canContinue = _canContinue();
    final isJoinFamilyStep =
        _currentStep == 5 && _selectedUserType == UserType.joinFamily;
    final isAuthStep = _currentStep == 6;

    return Column(
      children: [
        // Mostrar mensaje cuando no puede continuar en paso de autenticación
        if (!canContinue && isAuthStep) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedUserType == UserType.guest
                        ? 'Configuración opcional: Puedes continuar sin cuenta'
                        : 'Debes crear una cuenta para ${_selectedUserType == UserType.family ? 'tu grupo familiar' : 'unirte al grupo'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
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
                onPressed: canContinue ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canContinue
                      ? const Color(AppConstants.accentOrange)
                      : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!canContinue && (isJoinFamilyStep || isAuthStep)) ...[
                      const Icon(Icons.lock, size: 16),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _currentStep < _steps.length - 1
                          ? 'Continuar'
                          : 'Finalizar',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getEmojiForUserType() {
    switch (_selectedUserType) {
      case UserType.guest:
        return '🚶‍♂️';
      case UserType.family:
        return '👨‍👩‍👧‍👦';
      case UserType.joinFamily:
        return '🔗';
      default:
        return '👤';
    }
  }

  String _getTitleForUserType() {
    switch (_selectedUserType) {
      case UserType.guest:
        return 'Visitante Individual';
      case UserType.family:
        return 'Crear Grupo Familiar';
      case UserType.joinFamily:
        return 'Unirse a Grupo Familiar';
      default:
        return 'Usuario';
    }
  }

  bool _canContinue() {
    switch (_currentStep) {
      case 0:
        return true;
      case 1:
        return _selectedRegion != null;
      case 2:
        return _selectedPark != null;
      case 3:
      case 4:
        return true;
      case 5:
        // Selección de tipo de usuario
        // joinFamily ya no necesita validar código aquí (se pedirá al final)
        return _selectedUserType != null;
      case 6:
        // Autenticación OBLIGATORIA SOLO para family
        // joinFamily y guest NO requieren autenticación (pueden ser invitados)
        if (_selectedUserType == UserType.family) {
          // REQUERIDO: Debe tener email
          return _userEmail != null && _userEmail!.isNotEmpty;
        }
        // OPCIONAL para guest y joinFamily: Pueden continuar sin email
        return true;
      default:
        return false;
    }
  }

  void _nextStep() async {
    // Si acabamos de completar el paso 2 (Parque), guardar region/park
    if (_currentStep == 2 && _selectedRegion != null && _selectedPark != null) {
      final userData = StorageService.userData ?? {};
      userData['selected_region'] = _selectedRegion;
      userData['selected_park'] = _selectedPark;
      await StorageService.setUserData(userData);
      // Marcar que ya vimos bienvenida y seleccionamos region/park
      await StorageService.setHasSeenWelcome(true);
      debugPrint(
        '✅ Region y parque guardados: $_selectedRegion / $_selectedPark',
      );
    }

    // CASO ESPECIAL: Si terminó paso 5 (tipo de usuario) con joinFamily,
    // saltar paso de autenticación e ir directo a completar (mostrará diálogo de código)
    if (_currentStep == 5 && _selectedUserType == UserType.joinFamily) {
      debugPrint('🔀 joinFamily detectado: saltando paso de autenticación');
      await _completeOnboarding();
      return;
    }

    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _completeOnboarding();
    }
  }

  // LOGIN: Solo para usuarios existentes
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
    setState(() => _isAuthenticating = true);

    try {
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Usuario no encontrado');
      }

      // MODO DESARROLLO: Permitir login sin verificación de email
      // En producción, descomentar estas líneas:
      // if (response.user!.emailConfirmedAt == null) {
      //   await SupabaseService.client.auth.signOut();
      //   throw Exception('EMAIL_NOT_VERIFIED');
      // }

      setState(() {
        _userEmail = email;
        _isAuthenticating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sesión iniciada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isAuthenticating = false);

      if (mounted) {
        String errorMessage = '❌ Error al iniciar sesión';

        // Mejorar mensajes según el tipo de error
        if (e.toString().contains('EMAIL_NOT_VERIFIED')) {
          errorMessage =
              '❌ Cuenta no verificada\n\n📧 Debes verificar tu email con el código que te enviamos.\n\n💡 ¿No recibiste el código? Regístrate de nuevo y verifica inmediatamente.';
        } else if (e.toString().contains('Invalid login credentials') ||
            e.toString().contains('invalid_credentials') ||
            e.toString().contains('400')) {
          errorMessage =
              '❌ Email o contraseña incorrectos.\n\n💡 ¿Olvidaste tu contraseña o no tienes cuenta? Usa "Crear cuenta"';
        } else if (e.toString().contains('Email not confirmed')) {
          errorMessage =
              '❌ Cuenta no verificada. Revisa tu email y usa el código de verificación.';
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

  // REGISTRO: Crear cuenta nueva con verificación OTP
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
                    hintText: 'tu.email@ejemplo.com',
                    helperText: 'Usa tu email personal o institucional',
                    helperMaxLines: 2,
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

                // Validación básica de email
                if (email.isEmpty ||
                    !email.contains('@') ||
                    !email.contains('.')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '❌ Email inválido. Debe tener formato correcto',
                      ),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }

                // Solo bloquear dominios claramente falsos (de testing)
                final testDomains = ['.test', '.local', '.example', '.invalid'];
                if (testDomains.any(
                  (domain) => email.toLowerCase().endsWith(domain),
                )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Usa un email real, no uno de prueba'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
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
    setState(() => _isAuthenticating = true);

    try {
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: null, // Deshabilitar redirect
      );

      setState(() => _isAuthenticating = false);

      if (response.user == null) {
        throw Exception('Error al crear cuenta');
      }

      // ✅ FIX: Establecer _userEmail INMEDIATAMENTE después del registro exitoso
      // Supabase crea la sesión aunque el email no esté confirmado
      setState(() {
        _userEmail = email;
      });

      debugPrint('✅ Cuenta creada: $email');
      debugPrint('   User ID: ${response.user!.id}');
      debugPrint('   Session activa: ${response.session != null}');

      // Verificar si Supabase requiere confirmación de email
      final requiresEmailConfirmation = response.user!.emailConfirmedAt == null;

      if (mounted) {
        if (requiresEmailConfirmation) {
          // Mostrar diálogo informativo (pero _userEmail ya está establecido)
          _showEmailConfirmationDialog(email);
        } else {
          // Email auto-confirmado (configuración de Supabase)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Cuenta creada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isAuthenticating = false);

      if (mounted) {
        String errorMessage = '❌ Error al crear cuenta';

        if (e.toString().contains('email_address_invalid') ||
            e.toString().contains('invalid')) {
          errorMessage =
              '❌ Email inválido. Verifica que esté escrito correctamente';
        } else if (e.toString().contains('already registered') ||
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

  // Diálogo simplificado de confirmación de email
  void _showEmailConfirmationDialog(String email) {
    // Verificar sesión antes de mostrar el diálogo
    final currentUser = SupabaseService.client.auth.currentUser;
    debugPrint('📧 Mostrando diálogo de confirmación de email');
    debugPrint('   Email: $email');
    debugPrint('   Sesión activa: ${currentUser != null}');
    debugPrint('   User ID: ${currentUser?.id}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.email_outlined, color: Color(AppConstants.primaryGreen)),
            SizedBox(width: 8),
            Text('Confirmación de Email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mark_email_read,
              size: 64,
              color: Color(AppConstants.primaryGreen),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Cuenta creada!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              email,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                children: [
                  Text(
                    '📧 Revisa tu email',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Te hemos enviado un código de verificación.\n\nSi no lo recibes en 2-3 minutos, puedes continuar de todas formas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '💡 Puedes continuar sin verificar (recomendado para desarrollo)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showOTPInputDialog(email);
            },
            child: const Text('Tengo el código'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              // Ya no es necesario verificar o establecer _userEmail
              // porque ya se hizo en _performRegister
              debugPrint('✅ Continuando con cuenta sin verificar email');
              debugPrint('   _userEmail ya establecido: $_userEmail');

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Puedes completar el onboarding'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.primaryGreen),
            ),
            child: const Text('Continuar sin verificar'),
          ),
        ],
      ),
    );
  }

  // Pantalla de verificación OTP con código
  void _showOTPInputDialog(String email) {
    final otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Color(AppConstants.primaryGreen)),
            SizedBox(width: 8),
            Text('Verificar email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa el código de 6 dígitos:',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 12,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: '• • • • • •',
                border: OutlineInputBorder(),
                counterText: '',
                contentPadding: EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '📧 Revisa tu bandeja de entrada y spam',
                style: TextStyle(fontSize: 12, color: Colors.orange),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _userEmail = email;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Continuando sin verificación'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Omitir'),
          ),
          ElevatedButton(
            onPressed: () async {
              final otp = otpController.text.trim();

              if (otp.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ El código debe tener 6 dígitos'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await _verifyOTP(email, otp);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.primaryGreen),
            ),
            child: const Text('Verificar'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOTP(String email, String otp) async {
    setState(() => _isAuthenticating = true);

    try {
      await SupabaseService.client.auth.verifyOTP(
        type: OtpType.signup,
        email: email,
        token: otp,
      );

      setState(() {
        _userEmail = email;
        _isAuthenticating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Email verificado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isAuthenticating = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Código inválido o expirado'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      // CASO ESPECIAL: joinFamily como invitado (sin autenticación)
      if (_selectedUserType == UserType.joinFamily) {
        await _handleJoinFamilyAsGuest();
        return;
      }

      // VALIDACIÓN CRÍTICA: Para family, DEBE haber sesión activa
      if (_selectedUserType == UserType.family) {
        final currentUser = SupabaseService.client.auth.currentUser;

        debugPrint('🔍 === VALIDACIÓN FAMILIA ===');
        debugPrint('   Current User: ${currentUser?.email ?? "NULL"}');
        debugPrint('   User ID: ${currentUser?.id ?? "NULL"}');
        debugPrint(
          '   Email confirmado: ${currentUser?.emailConfirmedAt != null}',
        );
        debugPrint('   _userEmail: $_userEmail');
        debugPrint('   Sesión activa: ${currentUser != null}');

        if (currentUser == null || _userEmail == null) {
          debugPrint('❌ BLOQUEADO: Familia sin autenticación completa');
          debugPrint(
            '   Razón: currentUser=${currentUser != null}, _userEmail=${_userEmail != null}',
          );

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

        debugPrint('✅ Validación pasada: Usuario autenticado para familia');
        debugPrint('   Procediendo a crear usuario en BD...');
      }

      await StorageService.setOnboardingCompleted(true);

      // hasSeenWelcome ya se guardó en paso 3 (region/park)
      // Ahora solo guardamos datos de autenticación

      if (_userEmail != null) {
        // Save user data locally
        final userData = StorageService.userData ?? {};
        userData['email'] = _userEmail;
        userData['region'] = _selectedRegion;
        userData['park'] = _selectedPark;
        userData['user_type'] = _selectedUserType.toString();
        userData['family_code'] = _familyCode;
        // selected_region y selected_park ya están guardados desde paso 3
        await StorageService.setUserData(userData);

        // SMART START: Guardar modo de usuario
        await StorageService.setUserMode(_selectedUserType.toString());

        // Create user in Supabase database
        String? userId;
        try {
          // Verificar si hay usuario autenticado
          final currentUser = SupabaseService.client.auth.currentUser;
          debugPrint(
            '🔍 Usuario actual en auth: ${currentUser?.email ?? "NINGUNO"}',
          );
          debugPrint(
            '🔍 Usuario confirmado: ${currentUser?.emailConfirmedAt != null}',
          );

          userId = await SupabaseService.createUserComplete(
            email: _userEmail!,
            region: _selectedRegion ?? '',
            park: _selectedPark ?? 'angostura',
            userType: _selectedUserType.toString(),
            familyCode: _familyCode,
          );

          debugPrint('✅ Usuario creado con ID: $userId');
        } catch (e) {
          debugPrint('⚠️ Error creating user in Supabase: $e');
          debugPrint('⚠️ Stack trace: ${e.toString()}');

          // Mostrar error al usuario si hay problema
          if (mounted && e.toString().contains('No hay usuario autenticado')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ No se pudo completar el registro. Por favor, intenta nuevamente.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          debugPrint('📝 Usando guest-user-id como fallback');
        }

        // Si no se pudo crear usuario, usar guest-user-id
        userId ??= 'guest-user-id';

        // Guardar userId localmente para uso posterior
        userData['user_id'] = userId;
        userData['selected_region'] = _selectedRegion;
        userData['selected_park'] = _selectedPark;
        await StorageService.setUserData(userData);

        // SMART START: Marcar setup como completo
        await StorageService.setHasCompletedInitialSetup(true);

        // If user created a family, show verification code dialog
        if (_selectedUserType == UserType.family) {
          final householdData = StorageService.householdData;
          if (householdData != null && mounted) {
            _showVerificationCodeDialog(householdData);
            return; // Don't navigate immediately
          }
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      // Even if there's an error, continue to dashboard
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  void _showVerificationCodeDialog(Map<String, dynamic> householdData) {
    final familyCode = householdData['family_code'];
    final ownerEmail = householdData['owner_email'];
    final isNew = householdData['is_new'] ?? false;

    showDialog(
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
              Text(isNew ? '¡Familia Creada!' : 'Grupo Familiar'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNew) ...[
                  const Text(
                    '✅ Tu grupo familiar ha sido creado exitosamente.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '📧 Se ha enviado un código de verificación a:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ownerEmail,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Revisa tu email y verifica tu cuenta usando el código de 6 dígitos.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                ],
                const Text(
                  '👨‍👩‍👧 Código de Familia:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    familyCode,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF2E7D32),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Comparte este código para que familiares puedan unirse a tu grupo.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'El código también aparecerá en la pantalla principal.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/home');
              },
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );
  }

  /// Maneja unirse a familia como invitado (child_user) sin autenticación
  Future<void> _handleJoinFamilyAsGuest() async {
    debugPrint(
      '👥 Iniciando flujo: Unirse a familia como invitado (onboarding)',
    );

    if (!mounted) return;

    // Mostrar dialog para ingresar código
    final code = await _showJoinFamilyCodeDialog();

    if (code == null || code.isEmpty) {
      debugPrint('❌ Usuario canceló ingreso de código');
      return;
    }

    setState(() => _isAuthenticating = true);

    try {
      debugPrint('🔑 Código ingresado: $code');

      // Validar código primero (sin autenticación, usando RPC para evitar RLS)
      debugPrint('🔍 Validando código de familia...');

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
      userData['selected_region'] = _selectedRegion ?? 'biobio';
      userData['selected_park'] = _selectedPark ?? 'angostura';
      await StorageService.setUserData(userData);

      // Guardar en householdData también
      await StorageService.setHouseholdData({
        'household_id': householdId,
        'family_code': code,
        'is_guest': true,
        'household_name': householdName,
      });

      // Marcar onboarding como completo
      await StorageService.setOnboardingCompleted(true);
      await StorageService.setHasCompletedInitialSetup(true);

      setState(() => _isAuthenticating = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Acceso temporal a "$householdName"'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar a home
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      debugPrint('❌ Error uniéndose como invitado: $e');
      setState(() => _isAuthenticating = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Dialog simple para ingresar código de familia (formato FAM-XXXXX)
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
                  '💡 El código debe tener el formato FAM-XXXXX',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isValid
                  ? () => Navigator.of(context).pop(codeController.text.trim())
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
              ),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
