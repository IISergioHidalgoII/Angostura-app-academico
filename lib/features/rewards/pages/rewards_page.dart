import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  Map<String, dynamic>? _familyInfo;
  bool _loadingFamilyInfo = true;

  @override
  void initState() {
    super.initState();
    _loadFamilyInfo();
  }

  Future<void> _loadFamilyInfo() async {
    try {
      final info = await SupabaseService.getCurrentUserFamilyInfo();
      if (mounted) {
        setState(() {
          _familyInfo = info;
          _loadingFamilyInfo = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando info familiar: $e');
      if (mounted) {
        setState(() {
          _loadingFamilyInfo = false;
        });
      }
    }
  }

  bool get _isChild {
    // Si no es owner (padre), entonces es hijo
    return !(_familyInfo?['is_owner'] ?? true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recompensas'),
        backgroundColor: const Color(AppConstants.primaryGreen),
        foregroundColor: Colors.white,
      ),
      body: _loadingFamilyInfo
          ? const Center(child: CircularProgressIndicator())
          : _isChild
          ? _buildChildRestrictedView()
          : _buildRewardsView(),
    );
  }

  Widget _buildChildRestrictedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.child_care,
                size: 64,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Cuenta de Invitado',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Solo el padre puede reclamar recompensas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(height: 8),
                  Text(
                    'Puedes escanear QRs y ver tu colección, pero las recompensas las gestiona el padre de la familia.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardsView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Módulo de Recompensas', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('En construcción...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
