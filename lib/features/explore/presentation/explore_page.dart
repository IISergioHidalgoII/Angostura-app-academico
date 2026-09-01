import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/season_theme.dart';
import '../../../core/services/season_detector_service.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  List<Map<String, dynamic>> _areas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.client
          .from('areas')
          .select('*, sites(name, region)')
          .order('name', ascending: true);

      setState(() {
        _areas = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando áreas: $e')));
      }
    }
  }

  // Obtener icono según el nombre del área (lógica simple)
  IconData _getIconForArea(String areaName) {
    final name = areaName.toLowerCase();
    if (name.contains('mirador') || name.contains('vista')) {
      return Icons.landscape;
    }
    if (name.contains('laguna') ||
        name.contains('agua') ||
        name.contains('río')) {
      return Icons.waves;
    }
    if (name.contains('bosque') ||
        name.contains('sendero') ||
        name.contains('árbol')) {
      return Icons.forest;
    }
    if (name.contains('observación') || name.contains('aves')) {
      return Icons.visibility;
    }
    if (name.contains('cafetería') ||
        name.contains('café') ||
        name.contains('comida')) {
      return Icons.restaurant;
    }
    if (name.contains('museo') ||
        name.contains('centro') ||
        name.contains('educación')) {
      return Icons.museum;
    }
    return Icons.map_outlined; // Por defecto
  }

  // Obtener color según el tipo de área
  Color _getColorForArea(String areaName) {
    final name = areaName.toLowerCase();
    if (name.contains('mirador') || name.contains('vista')) return Colors.blue;
    if (name.contains('laguna') ||
        name.contains('agua') ||
        name.contains('río')) {
      return Colors.cyan;
    }
    if (name.contains('bosque') ||
        name.contains('sendero') ||
        name.contains('árbol')) {
      return Colors.green;
    }
    if (name.contains('observación') || name.contains('aves')) {
      return Colors.orange;
    }
    if (name.contains('cafetería') ||
        name.contains('café') ||
        name.contains('comida')) {
      return Colors.brown;
    }
    if (name.contains('museo') ||
        name.contains('centro') ||
        name.contains('educación')) {
      return Colors.deepPurple;
    }
    return Colors.teal; // Por defecto
  }

  Widget _buildPointOfInterest(Map<String, dynamic> area) {
    final areaName = area['name'] ?? 'Sin nombre';
    final description = area['description'] ?? 'Sin descripción';
    final siteName = area['sites'] != null
        ? '${area['sites']['name']} (${area['sites']['region']})'
        : 'Sin sitio asignado';

    final icon = _getIconForArea(areaName);
    final iconColor = _getColorForArea(areaName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExploreDetailPage(
                icon: icon,
                iconColor: iconColor,
                title: areaName,
                description: description,
                details: '$description\n\nUbicación: $siteName',
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icono
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(width: 16),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      areaName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (area['sites'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              siteName,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Flecha
              Icon(Icons.arrow_forward_ios, color: iconColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seasonColors = SeasonTheme.getColorsForSeason(
      SeasonDetectorService.getCurrentSeason(),
    );

    return Scaffold(
      backgroundColor: seasonColors.cardBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🗺️ Explorar',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Conoce los principales puntos de interés del Parque Angostura',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de puntos de interés
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _areas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.explore_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay áreas disponibles',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Los puntos de interés aparecerán aquí',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAreas,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _areas.length,
                        itemBuilder: (context, index) {
                          return _buildPointOfInterest(_areas[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pantalla de detalle para cada punto de interés
class ExploreDetailPage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String details;

  const ExploreDetailPage({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [iconColor, iconColor.withValues(alpha: 0.7)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(icon, color: Colors.white, size: 64),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Contenido
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descripción corta
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: iconColor, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Detalles completos
                  const Text(
                    'Información Detallada',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
