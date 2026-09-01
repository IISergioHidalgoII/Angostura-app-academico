import 'package:flutter/material.dart';
import 'season_management_page.dart';
import 'card_management_page.dart';
import 'market_management_page.dart';
import 'areas_management_page.dart';
import 'local_maintenance_page.dart';

/// CAP 8 - Developer Panel
/// Panel de administración para desarrolladores con acceso completo
class DeveloperPanelPage extends StatelessWidget {
  const DeveloperPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠️ Developer Panel'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade50, Colors.blue.shade50],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 20),
            _buildSectionTitle('Gestión de Contenido'),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.calendar_today,
              title: 'Temporadas',
              subtitle: 'Gestionar temporadas activas',
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SeasonManagementPage()),
              ),
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.style,
              title: 'Cartas',
              subtitle: 'CRUD de cartas y rareza',
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CardManagementPage()),
              ),
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.store,
              title: 'Mercado',
              subtitle: 'Items y productos del mercado',
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MarketManagementPage()),
              ),
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.map_outlined,
              title: 'Áreas / Explorar',
              subtitle: 'Gestión de puntos de interés',
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AreasManagementPage()),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Mantenimiento'),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.build_circle,
              title: 'Mantenimiento Local',
              subtitle: 'Limpiar caché y resetear datos',
              color: Colors.red,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LocalMaintenancePage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade500],
          ),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Panel de Desarrollo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Acceso completo a gestión de contenido y mantenimiento del sistema',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
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

  Widget _buildMenuCard(
    BuildContext context, {
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
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
