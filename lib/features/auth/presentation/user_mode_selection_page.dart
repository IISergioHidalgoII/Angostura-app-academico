import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/user_mode_provider.dart';

/// Pantalla de selección de modo de usuario
class UserModeSelectionPage extends ConsumerWidget {
  const UserModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundLight),
      appBar: AppBar(
        title: const Text('Bienvenido'),
        backgroundColor: const Color(AppConstants.primaryGreen),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo o ilustración
              const Icon(
                Icons.park,
                size: 100,
                color: Color(AppConstants.primaryGreen),
              ),
              const SizedBox(height: 24),
              const Text(
                'Elige cómo quieres explorar',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(AppConstants.primaryGreen),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Botón: Visitante Individual
              _buildModeCard(
                context,
                ref,
                mode: UserMode.individual,
                icon: Icons.person,
                title: 'Visitante Individual',
                description: 'Explora por tu cuenta',
                color: const Color(0xFF2196F3),
              ),
              const SizedBox(height: 16),

              // Botón: Crear Grupo Familiar
              _buildModeCard(
                context,
                ref,
                mode: UserMode.createFamily,
                icon: Icons.family_restroom,
                title: 'Crear Grupo Familiar',
                description: 'Experiencia grupal con actividades especiales',
                color: const Color(0xFFFF8F00),
              ),
              const SizedBox(height: 16),

              // Botón: Unirse a Grupo Familiar
              _buildModeCard(
                context,
                ref,
                mode: UserMode.joinFamily,
                icon: Icons.group_add,
                title: 'Unirse a Grupo Familiar',
                description: 'Ya tienes un código de grupo',
                color: const Color(0xFF9C27B0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context,
    WidgetRef ref, {
    required UserMode mode,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          debugPrint('[MODE] selected=$mode');

          // Guardar modo seleccionado
          ref.read(userModeProvider.notifier).state = mode;

          // Navegar al flujo de autenticación
          Navigator.of(context).pushNamed('/auth');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(icon, size: 32, color: color),
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
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
