import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: const Color(AppConstants.primaryGreen),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Módulo de Perfil', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('En construcción...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
