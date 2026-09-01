import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa del Parque'),
        backgroundColor: const Color(AppConstants.primaryGreen),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Módulo de Mapa', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('En construcción...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
