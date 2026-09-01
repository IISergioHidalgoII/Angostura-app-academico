import 'package:flutter/material.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/sync_service.dart';

/// Banner que muestra el estado de conectividad y QRs pendientes
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOnline = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _listenToConnectivity();
  }

  void _checkStatus() {
    setState(() {
      _isOnline = ConnectivityService.isOnline;
      _pendingCount = SyncService.getPendingCount();
    });
  }

  void _listenToConnectivity() {
    ConnectivityService.onConnectivityChanged.listen((isOnline) {
      setState(() {
        _isOnline = isOnline;
      });

      // Si volvió la conexión y hay pendientes, sincronizar
      if (isOnline && _pendingCount > 0) {
        _syncPending();
      }
    });
  }

  Future<void> _syncPending() async {
    final synced = await SyncService.syncPendingQRs();
    if (synced > 0 && mounted) {
      setState(() {
        _pendingCount = SyncService.getPendingCount();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $synced cartas sincronizadas con Supabase'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si está online y no hay pendientes, no mostrar nada
    if (_isOnline && _pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.orange.shade100 : Colors.red.shade100,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isOnline ? Icons.sync : Icons.cloud_off,
            color: _isOnline ? Colors.orange.shade700 : Colors.red.shade700,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline && _pendingCount > 0
                ? 'Sincronizando $_pendingCount ${_pendingCount == 1 ? 'carta' : 'cartas'}...'
                : 'Sin conexión - Esperando sync',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: _isOnline ? Colors.orange.shade900 : Colors.red.shade900,
              fontSize: 13,
            ),
          ),
          if (_isOnline && _pendingCount > 0) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
