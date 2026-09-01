import 'package:flutter/material.dart';
import 'connectivity_service.dart';
import 'offline_storage_service.dart';
import 'supabase_service.dart';

/// Servicio para sincronizar datos offline con Supabase
class SyncService {
  static bool _isSyncing = false;

  /// Sincronizar QRs pendientes con Supabase
  static Future<int> syncPendingQRs() async {
    if (_isSyncing) {
      debugPrint('⏳ Sincronización ya en progreso...');
      return 0;
    }

    if (!ConnectivityService.isOnline) {
      debugPrint('📵 Sin conexión, no se puede sincronizar');
      return 0;
    }

    _isSyncing = true;
    int syncedCount = 0;

    try {
      final pendingQRs = OfflineStorageService.getPendingQRs();

      if (pendingQRs.isEmpty) {
        debugPrint('✅ No hay QRs pendientes de sincronizar');
        return 0;
      }

      debugPrint('🔄 Sincronizando ${pendingQRs.length} QRs pendientes...');

      for (final qr in pendingQRs) {
        try {
          final token = qr['token'] as String;
          final userId = qr['userId'] as String;
          final timestamp = qr['timestamp'].toString();

          // Intentar canjear el QR en Supabase
          await SupabaseService.redeemQrToken(token, userId);

          // Si fue exitoso, eliminar de pendientes
          await OfflineStorageService.removePendingQR(timestamp);

          syncedCount++;
          debugPrint('✅ QR sincronizado: $token');
        } catch (e) {
          debugPrint('⚠️ Error sincronizando QR individual: $e');
          // Continuar con el siguiente QR
        }
      }

      debugPrint(
        '🎉 Sincronización completada: $syncedCount/${pendingQRs.length} QRs',
      );
      return syncedCount;
    } catch (e) {
      debugPrint('❌ Error en sincronización: $e');
      return syncedCount;
    } finally {
      _isSyncing = false;
    }
  }

  /// Verificar si hay QRs pendientes
  static bool hasPendingSync() {
    return OfflineStorageService.getPendingCount() > 0;
  }

  /// Obtener número de items pendientes
  static int getPendingCount() {
    return OfflineStorageService.getPendingCount();
  }
}
