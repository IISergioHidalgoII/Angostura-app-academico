import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/dev_mode_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/offline_storage_service.dart';
import '../../developer_panel/presentation/developer_panel_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _settingsBoxName = '_settingsBox';
  Box<dynamic>? _settingsBox;

  bool _notificationsEnabled = true;
  bool _largeText = false;
  String _appVersion = '...';
  String _userEmail = 'Invitado';
  Map<String, dynamic>? _familyInfo;
  bool _loadingFamilyInfo = true;

  @override
  void initState() {
    super.initState();
    _initHive();
    _loadAppVersion();
    _loadUserEmail();
    _loadFamilyInfo();
  }

  Future<void> _loadFamilyInfo() async {
    try {
      final info = await SupabaseService.getCurrentUserFamilyInfo();
      setState(() {
        _familyInfo = info;
        _loadingFamilyInfo = false;
      });
    } catch (e) {
      debugPrint('Error cargando info familiar: $e');
      setState(() {
        _loadingFamilyInfo = false;
      });
    }
  }

  Future<void> _initHive() async {
    try {
      _settingsBox = await Hive.openBox(_settingsBoxName);
      setState(() {
        _notificationsEnabled =
            _settingsBox?.get('notifications_enabled', defaultValue: true) ??
            true;
        _largeText =
            _settingsBox?.get('large_text', defaultValue: false) ?? false;
      });
    } catch (e) {
      debugPrint('Error initializing Hive for settings: $e');
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  Future<void> _loadUserEmail() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        setState(() {
          _userEmail = user.email ?? 'Usuario';
        });
      }
    } catch (e) {
      debugPrint('Error loading user email: $e');
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Próximamente'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _savePreference(String key, dynamic value) async {
    try {
      await _settingsBox?.put(key, value);
    } catch (e) {
      debugPrint('Error saving preference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: const Color(AppConstants.primaryGreen),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // Sección 1: Notificaciones
          _buildSectionHeader('Notificaciones'),
          SwitchListTile(
            title: const Text('Permitir notificaciones'),
            subtitle: const Text('Recibe avisos de eventos y novedades'),
            value: _notificationsEnabled,
            onChanged: (value) async {
              setState(() {
                _notificationsEnabled = value;
              });
              await _savePreference('notifications_enabled', value);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? '✅ Notificaciones activadas'
                          : '🔕 Notificaciones desactivadas',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            secondary: const Icon(Icons.notifications),
          ),

          const Divider(height: 32),

          // Sección 2: Preferencias
          _buildSectionHeader('Preferencias'),
          SwitchListTile(
            title: const Text('Texto grande'),
            subtitle: const Text('Aumentar tamaño de fuente'),
            value: _largeText,
            onChanged: (value) async {
              setState(() {
                _largeText = value;
              });
              await _savePreference('large_text', value);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value ? '✅ Texto grande activado' : 'Texto normal',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            secondary: const Icon(Icons.text_fields),
          ),

          const Divider(height: 32),

          // Sección 3: Cuenta
          _buildSectionHeader('Cuenta'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Email'),
            subtitle: Text(_userEmail),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sincronizar datos'),
            subtitle: const Text('Sincronizar con servidor'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon('Sincronización de datos'),
          ),
          ListTile(
            leading: const Icon(Icons.card_giftcard),
            title: const Text('Recompensas'),
            subtitle: const Text('Ver mis logros'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => NavigationService.navigateTo('/rewards'),
          ),

          const Divider(height: 32),

          // Sección 4: Código Familiar (solo si el usuario tiene household)
          if (!_loadingFamilyInfo && _familyInfo != null) ...[
            _buildSectionHeader('Código Familiar'),
            // Usuario tiene familia
            ListTile(
              leading: Icon(
                _familyInfo!['is_owner']
                    ? Icons.family_restroom
                    : Icons.child_care,
                color: _familyInfo!['is_owner'] ? Colors.amber : Colors.blue,
              ),
              title: Text(_familyInfo!['household_name']),
              subtitle: Text(
                _familyInfo!['is_owner']
                    ? 'Cuenta Padre (${_familyInfo!['member_count']} miembros)'
                    : 'Cuenta Hijo',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2, color: Colors.green),
              title: const Text('Código de Familia'),
              subtitle: Text(
                _familyInfo!['redeem_code'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  // Copiar código al portapapeles
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✓ Código copiado: ${_familyInfo!['redeem_code']}',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ),
            if (_familyInfo!['is_owner'])
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade900),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Comparte este código con tu familia. Los hijos podrán escanear cartas y tú verás todas las cartas únicas desbloqueadas.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.child_care, color: Colors.blue.shade900),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Estás en modo hijo. Puedes escanear cartas libremente. El padre verá todas tus cartas desbloqueadas.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          const Divider(height: 32),

          // Sección 5: Cerrar sesión
          _buildSectionHeader('Sesión'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _showLogoutDialog,
          ),

          const SizedBox(height: 16),

          // Soporte y Acerca de (mantener como "Próximamente" permitido)
          _buildSectionHeader('Soporte'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Ayuda'),
            subtitle: const Text('Próximamente'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon('Centro de ayuda'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de'),
            subtitle: Text('Versión $_appVersion'),
          ),

          // Sección de Desarrollo (solo visible para desarrolladores)
          if (DevModeService.isDevUser()) ...[
            const Divider(height: 32),
            _buildSectionHeader('🛠️ Modo Desarrollador'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Modo desarrollador activo',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // CAP 8 - Developer Panel (Principal)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.deepPurple, width: 2),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.build_circle,
                    color: Colors.deepPurple,
                    size: 28,
                  ),
                ),
                title: const Text(
                  '🛠️ Developer Panel',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: const Text(
                  'Panel completo de administración\nTemporadas • Cartas • Mercado • Mantenimiento',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.deepPurple,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeveloperPanelPage(),
                    ),
                  );
                },
              ),
            ),
            // Mostrar herramientas debug legacy solo para desarrolladores
            if (DevModeService.isDevUser()) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Herramientas de Debug (legacy)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              // Debug - Opciones de colección
              ListTile(
                leading: const Icon(
                  Icons.collections_bookmark,
                  color: Colors.orange,
                ),
                title: const Text('Opciones de colección'),
                subtitle: const Text('Revelar o bloquear todas las cartas'),
                onTap: _showCollectionOptionsDialog,
              ),

              // Debug - Diagnóstico de temporadas
              ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.purple),
                title: const Text('Diagnóstico de temporadas'),
                subtitle: const Text(
                  'Ver estado de temporadas y cartas asignadas',
                ),
                onTap: _showSeasonDiagnostic,
              ),
            ],

            // Debug - Estadísticas de cache
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.grey),
              title: const Text('Estadísticas de cache'),
              subtitle: const Text('Ver información de almacenamiento offline'),
              onTap: _showCacheStats,
            ),
          ],

          const SizedBox(height: 24),

          // Firma del proyecto
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  Text(
                    'Powered by',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Inacap - Prototek',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión? Tu progreso se conservará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  // Debug - Mostrar opciones de colección
  Future<void> _showCollectionOptionsDialog() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ No hay usuario autenticado')),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎴 Opciones de Colección'),
        content: const Text('Elige una acción para todas las cartas:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _showSeasonSelectDialog(userId, unlock: true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('🔓 Revelar colección'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _lockAllCards(userId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('🔒 Bloquear colección'),
          ),
        ],
      ),
    );
  }

  // Selector de temporada para revelar/bloquear
  Future<void> _showSeasonSelectDialog(
    String userId, {
    required bool unlock,
  }) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          unlock ? '🔓 Selecciona Temporada' : '🔒 Selecciona Temporada',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSeasonOption(context, userId, 'verano', '☀️ Verano', unlock),
            _buildSeasonOption(context, userId, 'otono', '🍂 Otoño', unlock),
            _buildSeasonOption(
              context,
              userId,
              'invierno',
              '❄️ Invierno',
              unlock,
            ),
            _buildSeasonOption(
              context,
              userId,
              'primavera',
              '🌸 Primavera',
              unlock,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonOption(
    BuildContext context,
    String userId,
    String seasonKey,
    String label,
    bool unlock,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        onPressed: () async {
          Navigator.pop(context);
          if (unlock) {
            await _unlockSeasonCards(userId, seasonKey, label);
          }
        },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
        child: Text(label),
      ),
    );
  }

  // Desbloquear todas las cartas de una temporada específica
  Future<void> _unlockSeasonCards(
    String userId,
    String seasonKey,
    String seasonLabel,
  ) async {
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      final client = Supabase.instance.client;

      // Capitalizar el nombre de la temporada (verano -> Verano, otono -> Otoño)
      String capitalizedSeasonKey =
          seasonKey[0].toUpperCase() + seasonKey.substring(1);
      // Caso especial para "otono" -> "Otoño"
      if (seasonKey == 'otono') {
        capitalizedSeasonKey = 'Otoño';
      }
      debugPrint(
        '🔍 Buscando temporada: $capitalizedSeasonKey (original: $seasonKey)',
      );

      // 1. Primero obtener el season_id de la temporada (no el id)
      final seasonResponse = await client
          .from('seasons')
          .select('id, season_id, name')
          .eq('name', capitalizedSeasonKey)
          .maybeSingle();

      if (seasonResponse == null) {
        throw Exception('Temporada "$capitalizedSeasonKey" no encontrada');
      }

      // Usar season_id (no id) porque las cartas tienen FK a season_id
      final seasonId = seasonResponse['season_id'];
      debugPrint(
        '🌦️ Temporada encontrada: ${seasonResponse['name']} (season_id: $seasonId, id: ${seasonResponse['id']})',
      );

      // 2. Obtener todas las cartas de esa temporada
      final cardsResponse = await client
          .from('cards')
          .select('id, title, code')
          .eq('season_id', seasonId);

      debugPrint(
        '🎴 Cartas encontradas para $seasonKey: ${cardsResponse.length}',
      );

      if (cardsResponse.isEmpty) {
        throw Exception('No hay cartas en la temporada $seasonLabel');
      }

      int unlocked = 0;

      // 3. Insertar cada carta en user_cards
      for (final card in cardsResponse) {
        final cardId = card['id']?.toString();
        if (cardId == null) continue;

        try {
          // Verificar si ya existe
          final existing = await client
              .from('user_cards')
              .select('id')
              .eq('user_id', userId)
              .eq('card_id', cardId)
              .maybeSingle();

          if (existing == null) {
            // Insertar nueva carta
            await client.from('user_cards').insert({
              'user_id': userId,
              'card_id': cardId,
              'source': 'debug_unlock',
            });
            unlocked++;
            debugPrint('✅ Desbloqueada: ${card['title']} (${card['code']})');
          } else {
            debugPrint('⚠️ Ya desbloqueada: ${card['title']}');
          }
        } catch (e) {
          debugPrint('❌ Error con carta ${card['code']}: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close loading

        // Limpiar cache offline para forzar recarga desde BD
        await OfflineStorageService.cleanTemporaryCards();
        debugPrint(
          '🧹 Cache limpiado, cartas se recargarán desde BD en próxima visita a Colección',
        );

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Cartas Desbloqueadas'),
            content: Text(
              'Se desbloquearon $unlocked de ${cardsResponse.length} cartas de $seasonLabel.\n\n'
              '💡 Ve a "Mi Colección" para verlas (se refrescará automáticamente).',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  // Navegar a la página principal (donde está la colección)
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Ir a Colección'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                },
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      debugPrint('❌ Error al desbloquear cartas: $e');
    }
  }

  // Bloquear todas las cartas (eliminar de user_cards)
  Future<void> _lockAllCards(String userId) async {
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      await SupabaseService.resetUserCollection(userId);

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Todas las cartas bloqueadas'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al bloquear cartas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Debug - Mostrar estadísticas de cache
  Future<void> _showCacheStats() async {
    try {
      final cardsCount = await OfflineStorageService.getCachedCardsCount();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('📊 Estadísticas de cache'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cartas en cache: $cardsCount'),
                const SizedBox(height: 8),
                const Text('Cache de mercado: Ver logs en consola'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _performLogout() async {
    try {
      // Mostrar loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      // Cerrar sesión en Supabase
      await Supabase.instance.client.auth.signOut();

      // SMART START: Limpiar flags de setup pero mantener hasSeenWelcome
      await StorageService.setHasCompletedInitialSetup(false);
      await StorageService.setUserMode(null);
      // NO tocar hasSeenWelcome (mantener true para no repetir bienvenida)

      // Limpiar datos de usuario pero PRESERVAR región/parque
      final userData = StorageService.userData ?? {};
      final savedRegion = userData['selected_region'];
      final savedPark = userData['selected_park'];

      await StorageService.clearUserData();

      // Restaurar region y park
      if (savedRegion != null && savedPark != null) {
        final newUserData = {
          'selected_region': savedRegion,
          'selected_park': savedPark,
        };
        await StorageService.setUserData(newUserData);
      }

      // Navegar al selector de modo usuario (sin repetir bienvenida)
      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.of(context).pushReplacementNamed('/user-mode-selector');
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Diagnóstico de temporadas y cartas
  Future<void> _showSeasonDiagnostic() async {
    try {
      final client = Supabase.instance.client;

      // Obtener todas las temporadas
      final seasonsResponse = await client
          .from('seasons')
          .select('id, season_id, name, is_active')
          .order('name');

      debugPrint('🔍 === DIAGNÓSTICO DE TEMPORADAS ===');
      debugPrint('📊 Total temporadas: ${seasonsResponse.length}');

      final diagnosticData = <String>[];

      for (final season in seasonsResponse) {
        final tableId = season['id'];
        final seasonId = season['season_id'];
        final seasonName = season['name'];
        final isActive = season['is_active'];

        // Contar cartas usando season_id (no id)
        final cardsResponse = await client
            .from('cards')
            .select('id')
            .eq('season_id', seasonId);

        final cardCount = cardsResponse.length;

        final status = isActive ? '✅ ACTIVA' : '⚪ Inactiva';
        final info =
            '$status $seasonName\n  season_id: $seasonId\n  table_id: $tableId\n  → $cardCount cartas';

        diagnosticData.add(info);
        debugPrint(info);
      }

      // Buscar cartas sin temporada asignada
      final orphanCards = await client
          .from('cards')
          .select('id, title, code, season_id')
          .isFilter('season_id', null);

      if (orphanCards.isNotEmpty) {
        final orphanInfo = '⚠️ ${orphanCards.length} cartas SIN TEMPORADA:';
        diagnosticData.add(orphanInfo);
        debugPrint(orphanInfo);
        for (final card in orphanCards) {
          final cardInfo = '  - ${card['title']} (${card['code']})';
          debugPrint(cardInfo);
        }
      }

      debugPrint('🔍 === FIN DIAGNÓSTICO ===');

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🔍 Diagnóstico de Temporadas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total temporadas: ${seasonsResponse.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...diagnosticData.map(
                    (info) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(info, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error en diagnóstico: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
