import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cached_image_service.dart';

/// CAP 8 - Local Maintenance
/// Herramientas de mantenimiento y limpieza local
class LocalMaintenancePage extends ConsumerStatefulWidget {
  const LocalMaintenancePage({super.key});

  @override
  ConsumerState<LocalMaintenancePage> createState() =>
      _LocalMaintenancePageState();
}

class _LocalMaintenancePageState extends ConsumerState<LocalMaintenancePage> {
  Map<String, dynamic> _storageInfo = {};
  bool _isLoading = true;
  double _imageCacheSize = 0;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    setState(() => _isLoading = true);
    try {
      final box = await Hive.openBox('app_data');
      final userData = StorageService.userData ?? {};
      final hasSeenWelcome = StorageService.hasSeenWelcome;
      final userMode = StorageService.userMode;
      final hasCompletedSetup = StorageService.hasCompletedInitialSetup;
      final cacheSize = await CachedImageService.getCacheSize();

      setState(() {
        _storageInfo = {
          'box_keys': box.keys.toList(),
          'box_length': box.length,
          'has_seen_welcome': hasSeenWelcome,
          'user_mode': userMode,
          'has_completed_setup': hasCompletedSetup,
          'selected_region': userData['selected_region'],
          'selected_park': userData['selected_park'],
          'user_email': SupabaseService.client.auth.currentUser?.email,
          'is_authenticated': SupabaseService.client.auth.currentUser != null,
        };
        _imageCacheSize = cacheSize;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error cargando info de almacenamiento: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Limpiar Caché'),
        content: const Text(
          'Esto eliminará:\n'
          '• Datos temporales\n'
          '• Caché de imágenes\n'
          '• Datos de sesión anteriores\n\n'
          'NO afectará:\n'
          '✓ Datos de usuario\n'
          '✓ Region y parque\n'
          '✓ Estado de onboarding',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpiar Caché'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await CachedImageService.clearAllCache();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Caché de imágenes limpiado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          _loadStorageInfo();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _clearImageCacheByCategory(String category) async {
    final categoryName = category == CachedImageService.cartas
        ? 'Cartas'
        : category == CachedImageService.mercado
        ? 'Mercado'
        : 'Áreas';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🗑️ Limpiar Caché de $categoryName'),
        content: Text('¿Eliminar imágenes cacheadas de $categoryName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await CachedImageService.clearCategoryCache(category);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Caché de $categoryName limpiado'),
              backgroundColor: Colors.green,
            ),
          );
          _loadStorageInfo();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _resetOnboarding() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔄 Resetear Onboarding'),
        content: const Text(
          'Esto hará que el usuario vea el onboarding nuevamente.\n\n'
          'Se resetearán:\n'
          '• hasSeenWelcome\n'
          '• hasCompletedInitialSetup\n'
          '• userMode\n\n'
          'Se mantendrán:\n'
          '✓ Sesión activa\n'
          '✓ Datos de usuario',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resetear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await StorageService.setHasSeenWelcome(false);
        await StorageService.setHasCompletedInitialSetup(false);
        await StorageService.setUserMode(null);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Onboarding reseteado. Reinicie la app.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          _loadStorageInfo();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _clearAllLocalData() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final hasActiveSession = currentUser != null;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ PELIGRO: Borrar TODO'),
        content: Text(
          '⚠️ ACCIÓN DESTRUCTIVA ⚠️\n\n'
          'Esto eliminará TODOS los datos locales:\n'
          '• Flags de onboarding\n'
          '• Region y parque\n'
          '• Modo de usuario\n'
          '• Toda la configuración local\n\n'
          '${hasActiveSession ? '⚠️ TIENES SESIÓN ACTIVA:\n${currentUser.email ?? "Usuario autenticado"}\n\n' : ''}'
          'NO afectará:\n'
          '${hasActiveSession ? '⚠️ Sesión de Supabase (seguirá logueado)\n' : ''}'
          '✓ Datos en la base de datos\n\n'
          'La app regresará al estado inicial${hasActiveSession ? ' pero mantendrás tu sesión' : ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('BORRAR TODO'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final box = await Hive.openBox('app_data');
        await box.clear();
        await StorageService.setHasSeenWelcome(false);
        await StorageService.setHasCompletedInitialSetup(false);
        await StorageService.setUserMode(null);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasActiveSession
                    ? '✅ Datos locales eliminados (Sesión activa: ${currentUser.email})'
                    : '✅ Todos los datos locales eliminados',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          _loadStorageInfo();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚪 Cerrar Sesión'),
        content: const Text(
          'Esto cerrará la sesión de Supabase.\n\n'
          'Se mantendrán:\n'
          '✓ Region y parque\n'
          '✓ hasSeenWelcome\n\n'
          'Se resetearán:\n'
          '• userMode\n'
          '• hasCompletedInitialSetup',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Save region/park
        final userData = StorageService.userData ?? {};
        final savedRegion = userData['selected_region'];
        final savedPark = userData['selected_park'];

        await StorageService.clearUserData();
        await SupabaseService.client.auth.signOut();

        // Restore region/park
        if (savedRegion != null && savedPark != null) {
          final newUserData = {
            'selected_region': savedRegion,
            'selected_park': savedPark,
          };
          await StorageService.setUserData(newUserData);
        }

        await StorageService.setHasCompletedInitialSetup(false);
        await StorageService.setUserMode(null);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Sesión cerrada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          _loadStorageInfo();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _fullReset() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('☢️ RESET COMPLETO'),
        content: Text(
          '⚠️⚠️⚠️ ACCIÓN MUY DESTRUCTIVA ⚠️⚠️⚠️\n\n'
          'Esto hará:\n'
          '1. Borrar TODOS los datos locales\n'
          '2. Cerrar sesión de Supabase\n'
          '3. Resetear la app al estado inicial\n\n'
          '${currentUser != null ? 'Tu sesión actual: ${currentUser.email}\n\n' : ''}'
          'La app volverá a la pantalla de bienvenida.\n'
          'Deberás configurar región, parque y crear cuenta nuevamente.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESET COMPLETO'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Borrar storage local
        final box = await Hive.openBox('app_data');
        await box.clear();

        // 2. Cerrar sesión Supabase
        await SupabaseService.client.auth.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Reset completo. Reiniciando app...'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );

          // 3. Navegar a onboarding
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/boot', (route) => false);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error en reset: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenimiento Local'),
        backgroundColor: Colors.red,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoCard(),
                const SizedBox(height: 20),
                _buildSectionTitle('Acciones de Mantenimiento'),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.photo_library, color: Colors.teal),
                            const SizedBox(width: 12),
                            Text(
                              'Caché de Imágenes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tamaño: ${_imageCacheSize.toStringAsFixed(2)} MB',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _clearImageCacheByCategory(
                                CachedImageService.cartas,
                              ),
                              icon: const Icon(Icons.style, size: 16),
                              label: const Text('Cartas'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple.shade100,
                                foregroundColor: Colors.purple.shade900,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _clearImageCacheByCategory(
                                CachedImageService.mercado,
                              ),
                              icon: const Icon(Icons.shopping_bag, size: 16),
                              label: const Text('Mercado'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade100,
                                foregroundColor: Colors.green.shade900,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _clearImageCacheByCategory(
                                CachedImageService.areas,
                              ),
                              icon: const Icon(Icons.map, size: 16),
                              label: const Text('Áreas'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade100,
                                foregroundColor: Colors.teal.shade900,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _clearCache,
                              icon: const Icon(Icons.delete_sweep, size: 16),
                              label: const Text('Todas'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade100,
                                foregroundColor: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.refresh,
                  title: 'Resetear Onboarding',
                  subtitle: 'Volver a mostrar el onboarding inicial',
                  color: Colors.blue,
                  onTap: _resetOnboarding,
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.logout,
                  title: 'Cerrar Sesión',
                  subtitle: 'Desconectar de Supabase (mantiene region/park)',
                  color: Colors.purple,
                  onTap: _logout,
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('Zona de Peligro'),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.delete_forever,
                  title: 'Borrar TODO (mantiene sesión)',
                  subtitle: 'Elimina datos locales pero mantiene sesión auth',
                  color: Colors.red,
                  onTap: _clearAllLocalData,
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.delete_sweep,
                  title: 'RESET COMPLETO + Cerrar Sesión',
                  subtitle: 'Borra TODO y cierra sesión (reseteo total)',
                  color: Colors.red.shade900,
                  onTap: _fullReset,
                ),
              ],
            ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Estado del Sistema',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildInfoRow(
              'Autenticado',
              _storageInfo['is_authenticated'] == true ? '✅ Sí' : '❌ No',
            ),
            _buildInfoRow('Email', _storageInfo['user_email'] ?? 'N/A'),
            _buildInfoRow('Region', _storageInfo['selected_region'] ?? 'N/A'),
            _buildInfoRow('Parque', _storageInfo['selected_park'] ?? 'N/A'),
            _buildInfoRow('Modo Usuario', _storageInfo['user_mode'] ?? 'N/A'),
            _buildInfoRow(
              'Vio Welcome',
              _storageInfo['has_seen_welcome'] == true ? 'Sí' : 'No',
            ),
            _buildInfoRow(
              'Setup Completo',
              _storageInfo['has_completed_setup'] == true ? 'Sí' : 'No',
            ),
            _buildInfoRow(
              'Claves en Hive',
              '${_storageInfo['box_length'] ?? 0}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[700],
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
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
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
