import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/database_setup_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/household_service.dart';
import '../../../core/services/offline_storage_service.dart';
import '../../../core/services/dev_mode_service.dart';
import '../../../core/services/season_detector_service.dart';
import '../../../core/theme/season_theme.dart';
import '../../../core/utils/collection_refresh_notifier.dart';
import '../../developer_panel/presentation/developer_panel_page.dart';
import '../widgets/household_verification_widget.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _refreshKey = 0;
  late SeasonColors _seasonColors;
  Map<String, dynamic>? _familyInfo;

  @override
  void initState() {
    super.initState();

    // Detectar temporada y aplicar tema
    final currentSeason = SeasonDetectorService.getCurrentSeason();
    _seasonColors = SeasonTheme.getColorsForSeason(currentSeason);
    SeasonDetectorService.logCurrentSeason();

    // Escuchar cambios en la colección para actualizar estadísticas si existen
    CollectionRefreshNotifier().addListener(_onCollectionChanged);

    // Mostrar indicador de QRs pendientes si existen
    _checkPendingSync();

    // Cargar información familiar
    _loadFamilyInfo();
  }

  Future<void> _loadFamilyInfo() async {
    try {
      final info = await HouseholdService.getMyHouseholdInfo();
      if (mounted) {
        setState(() {
          _familyInfo = info;
        });
      }
    } catch (e) {
      debugPrint('Error cargando info familiar: $e');
    }
  }

  void _checkPendingSync() {
    final pendingCount = OfflineStorageService.getPendingCount();
    if (pendingCount > 0) {
      debugPrint('📵 $pendingCount QR(s) pendiente(s) de sincronizar');
      // La sincronización se hará automáticamente al abrir la colección
    }
  }

  @override
  void dispose() {
    CollectionRefreshNotifier().removeListener(_onCollectionChanged);
    super.dispose();
  }

  void _onCollectionChanged() {
    debugPrint('📊 Dashboard: detectado cambio en colección');
    if (mounted) {
      setState(() {
        _refreshKey++; // Forzar recálculo del FutureBuilder
        debugPrint('🔄 Dashboard refreshKey: $_refreshKey');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundLight),
      appBar: AppBar(
        title: Text(
          '🏠 ${AppConstants.appName} ${SeasonDetectorService.getSeasonEmoji(SeasonDetectorService.getCurrentSeason())}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _seasonColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showProfileMenu,
            icon: const Icon(Icons.account_circle, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _seasonColors.primary,
              const Color(AppConstants.backgroundLight),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 16),
              // Widget de verificación (solo si no está verificado)
              if (_familyInfo != null && _familyInfo!['verified'] == false) ...[
                HouseholdVerificationWidget(
                  householdInfo: _familyInfo!,
                  onVerified: _loadFamilyInfo,
                ),
              ],
              // Código de familia (siempre visible si pertenece a household)
              if (_familyInfo != null) ...[
                _buildFamilyCodeWidget(),
                const SizedBox(height: 16),
              ],
              _buildProgressCard(),
              const SizedBox(height: 24),
              Expanded(child: _buildFeatureGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '🌿 ¡Bienvenido!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(AppConstants.primaryGreen),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Explora la biodiversidad del Maule',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyCodeWidget() {
    final isOwner = _familyInfo?['is_owner'] ?? false;
    final redeemCode = _familyInfo?['redeem_code'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOwner ? Colors.amber.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOwner ? Icons.family_restroom : Icons.child_care,
              color: isOwner ? Colors.amber.shade700 : Colors.blue.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOwner ? 'Código Familiar' : 'Cuenta Familiar',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  redeemCode,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: redeemCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Código copiado al portapapeles'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              tooltip: 'Copiar código',
            ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'guest-user-id';

    return FutureBuilder<Map<String, int>>(
      key: ValueKey(
        _refreshKey,
      ), // Forzar reconstrucción cuando cambia _refreshKey
      future: _getLocalProgress(userId),
      builder: (context, snapshot) {
        final collected = snapshot.data?['collected'] ?? 0;
        final total = snapshot.data?['total'] ?? 3;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu Progreso',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Cartas Coleccionadas',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              snapshot.connectionState == ConnectionState.waiting
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Text(
                      '$collected/$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, int>> _getLocalProgress(String userId) async {
    try {
      // Códigos de las cartas visibles en la app (las que tienen imágenes)
      const targetCodes = [
        'ANG-CARD-001', // Carpintero Negro
        'ANG-CARD-005', // Zorro Culpeo
        'ANG-CARD-007', // Huemul
      ];

      // Obtener todas las cartas del usuario
      final userCards = await SupabaseService.getUserCards(userId);

      // Contar solo las cartas que tienen imágenes
      int collected = 0;
      for (final userCard in userCards) {
        final card = userCard['cards'] as Map<String, dynamic>?;
        if (card != null) {
          final code = card['code']?.toString().toUpperCase();
          if (code != null && targetCodes.contains(code)) {
            collected++;
          }
        }
      }

      debugPrint(
        '📊 Dashboard Progress (local): $collected/${targetCodes.length}',
      );
      return {'collected': collected, 'total': targetCodes.length};
    } catch (e) {
      debugPrint('⚠️ Error obteniendo progreso: $e');
      return {'collected': 0, 'total': 3};
    }
  }

  Widget _buildFeatureGrid() {
    final features = [
      {
        'icon': '📱',
        'title': 'Escanear QR',
        'description': 'Escanea códigos QR',
        'route': '/qr-scanner',
      },
      {
        'icon': '🏆',
        'title': 'Colección',
        'description': 'Ver mi colección',
        'route': '/collection',
      },
      {
        'icon': '🗺️',
        'title': 'Mapa',
        'description': 'Explorar zonas',
        'route': '/map',
      },
      {
        'icon': '🎁',
        'title': 'Recompensas',
        'description': 'Mis logros',
        'route': '/rewards',
      },
      {
        'icon': '🏗️',
        'title': 'Setup DB',
        'description': 'Crear datos demo',
        'route': 'setup',
      },
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return _buildFeatureCard(feature);
      },
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          onTap: () => _handleFeatureTap(feature['route']),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(feature['icon'], style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  feature['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(AppConstants.primaryGreen),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  feature['description'],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileMenu() {
    final isDevUser = DevModeService.isDevUser();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppConstants.borderRadius),
            topRight: Radius.circular(AppConstants.borderRadius),
          ),
        ),
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.person,
                color: Color(AppConstants.primaryGreen),
              ),
              title: const Text('Mi Perfil'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.settings,
                color: Color(AppConstants.primaryGreen),
              ),
              title: const Text('Configuración'),
              onTap: () => Navigator.pop(context),
            ),
            // CAP 8 - Developer Panel (solo para usuarios autorizados)
            if (isDevUser) ...[
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.build_circle,
                  color: Colors.deepPurple,
                ),
                title: const Text('🛠️ Developer Panel'),
                subtitle: const Text('Panel de administración'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeveloperPanelPage(),
                    ),
                  );
                },
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar Sesión'),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  void _handleFeatureTap(String route) {
    if (route == 'setup') {
      _setupDatabase();
    } else {
      NavigationService.navigateTo(route);
    }
  }

  Future<void> _setupDatabase() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🏗️ Configurando Base de Datos'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Creando datos de ejemplo para pruebas...'),
          ],
        ),
      ),
    );

    try {
      await DatabaseSetupService.createSampleHouseholds();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Mostrar códigos disponibles
      final households = await DatabaseSetupService.getAvailableHouseholds();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('✅ Base de Datos Configurada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Códigos de familia disponibles para pruebas:'),
              const SizedBox(height: 12),
              ...households.map(
                (household) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          household['redeem_code'] ?? 'N/A',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          household['name'] ?? 'Sin nombre',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('❌ Error'),
          content: Text('Error configurando base de datos:\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _logout() async {
    Navigator.pop(context); // Close bottom sheet

    // Clear user data but keep onboarding completion status
    await StorageService.clearUserData();

    // Navigate back to onboarding
    NavigationService.goToOnboarding();
  }
}
