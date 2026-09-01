import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';

/// Servicio para almacenar cartas offline y sincronizarlas después
class OfflineStorageService {
  static const String _pendingQRBox = 'pending_qr_redemptions';
  static const String _cachedCardsBox = 'cached_cards';
  static const String _unlockedCardsBox =
      'unlocked_cards'; // IDs de cartas desbloqueadas

  /// Inicializar cajas de Hive
  static Future<void> init() async {
    await Hive.openBox(_pendingQRBox);
    await Hive.openBox(_cachedCardsBox);
    await Hive.openBox(_unlockedCardsBox);
    debugPrint('✅ Offline Storage inicializado');
  }

  /// Guardar QR pendiente de canje (cuando no hay internet)
  static Future<void> savePendingQR(String token, String userId) async {
    final box = Hive.box(_pendingQRBox);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await box.put(timestamp.toString(), {
      'token': token,
      'userId': userId,
      'timestamp': timestamp,
    });

    debugPrint('💾 QR guardado offline: $token (pendiente de sincronizar)');
  }

  /// Guardar TODAS las cartas disponibles en cache (bloqueadas y desbloqueadas)
  static Future<void> cacheAllCards(List<Map<String, dynamic>> cards) async {
    final box = Hive.box(_cachedCardsBox);
    await box.clear(); // Limpiar cache antiguo

    for (var card in cards) {
      final cardData = card['cards'] as Map<String, dynamic>?;
      if (cardData != null) {
        final cardId = cardData['id'];
        await box.put(cardId, cardData);
      }
    }
    debugPrint('💾 ${cards.length} cartas guardadas en cache (todas)');
  }

  /// Guardar IDs de cartas desbloqueadas por el usuario
  static Future<void> saveUnlockedCardIds(Set<String> unlockedIds) async {
    final box = Hive.box(_unlockedCardsBox);
    await box.put('unlocked_ids', unlockedIds.toList());
    debugPrint(
      '🔓 ${unlockedIds.length} IDs de cartas desbloqueadas guardados',
    );
  }

  /// Obtener IDs de cartas desbloqueadas desde cache
  static Set<String> getUnlockedCardIds() {
    final box = Hive.box(_unlockedCardsBox);
    final list = box.get('unlocked_ids', defaultValue: <String>[]);
    return Set<String>.from(list);
  }

  /// Desbloquear una carta en modo offline (agregar a la lista de desbloqueadas)
  static Future<void> unlockCardOffline(String cardId) async {
    final unlockedIds = getUnlockedCardIds();
    unlockedIds.add(cardId);
    await saveUnlockedCardIds(unlockedIds);
    debugPrint('🔓 Carta $cardId desbloqueada en modo offline');
  }

  /// Crear y guardar una carta temporal cuando no existe en cache
  /// Usa el código QR como ID temporal
  static Future<String> createTemporaryCard(String qrCode) async {
    final box = Hive.box(_cachedCardsBox);

    // Crear ID temporal basado en el código QR
    final tempCardId = 'temp_$qrCode';

    // Crear carta temporal con información básica
    final tempCard = {
      'id': tempCardId,
      'code': qrCode,
      'title': 'Carta Escaneada',
      'description':
          'Carta escaneada offline. Se actualizará con información completa al sincronizar.',
      'rarity': 'común',
      'image_url': null,
      'is_temporary': true, // Marca para identificar cartas temporales
    };

    // Guardar en cache
    await box.put(tempCardId, tempCard);

    // Marcar como desbloqueada
    await unlockCardOffline(tempCardId);

    debugPrint('📦 Carta temporal creada: $tempCardId ($qrCode)');
    return tempCardId;
  }

  /// Limpiar cartas temporales del cache
  /// Se llama después de sincronizar para reemplazar con cartas reales
  static Future<void> cleanTemporaryCards() async {
    final box = Hive.box(_cachedCardsBox);

    // Buscar y eliminar cartas temporales
    final keysToRemove = <String>[];
    for (var key in box.keys) {
      final card = box.get(key);
      if (card is Map && card['is_temporary'] == true) {
        keysToRemove.add(key.toString());
      }
    }

    // Eliminar cartas temporales del cache
    for (var key in keysToRemove) {
      await box.delete(key);
    }

    // Limpiar IDs temporales de la lista de desbloqueadas
    final unlockedIds = getUnlockedCardIds();
    unlockedIds.removeWhere((id) => id.toString().startsWith('temp_'));
    await saveUnlockedCardIds(unlockedIds);

    if (keysToRemove.isNotEmpty) {
      debugPrint('🧹 ${keysToRemove.length} carta(s) temporal(es) limpiadas');
    }
  }

  /// Obtener todas las cartas desde cache con estado locked/unlocked
  static List<Map<String, dynamic>> getCachedCardsWithState() {
    final cardsBox = Hive.box(_cachedCardsBox);
    final unlockedIds = getUnlockedCardIds();
    final cards = <Map<String, dynamic>>[];

    for (var key in cardsBox.keys) {
      final card = cardsBox.get(key);
      if (card is Map) {
        final cardData = Map<String, dynamic>.from(card);
        final cardId = cardData['id'] as String;
        final isUnlocked = unlockedIds.contains(cardId);

        cards.add({
          'id': cardId,
          'locked': !isUnlocked,
          'unlocked_at': isUnlocked ? DateTime.now().toIso8601String() : null,
          'source': isUnlocked ? 'offline_cache' : null,
          'cards': cardData,
        });
      }
    }

    // Ordenar: desbloqueadas primero
    cards.sort((a, b) {
      final aLocked = a['locked'] as bool;
      final bLocked = b['locked'] as bool;
      if (aLocked != bLocked) {
        return aLocked ? 1 : -1;
      }
      final aTitle = (a['cards'] as Map<String, dynamic>)['title'] as String?;
      final bTitle = (b['cards'] as Map<String, dynamic>)['title'] as String?;
      return (aTitle ?? '').compareTo(bTitle ?? '');
    });

    debugPrint(
      '📦 ${cards.length} cartas cargadas desde cache (${unlockedIds.length} desbloqueadas)',
    );
    return cards;
  }

  /// Obtener QRs pendientes de sincronizar
  static List<Map<String, dynamic>> getPendingQRs() {
    final box = Hive.box(_pendingQRBox);
    final pending = <Map<String, dynamic>>[];

    for (var key in box.keys) {
      final qr = box.get(key);
      if (qr is Map) {
        pending.add(Map<String, dynamic>.from(qr));
      }
    }

    return pending;
  }

  /// Obtener número de QRs pendientes de sincronizar
  static int getPendingCount() {
    final box = Hive.box(_pendingQRBox);
    return box.length;
  }

  /// Eliminar un QR pendiente después de sincronizarlo
  static Future<void> removePendingQR(String timestamp) async {
    final box = Hive.box(_pendingQRBox);
    await box.delete(timestamp);
    debugPrint('✅ QR sincronizado, eliminado de pendientes');
  }

  /// Limpiar todos los QRs pendientes
  static Future<void> clearPendingQRs() async {
    final box = Hive.box(_pendingQRBox);
    await box.clear();
    debugPrint('🧹 Cola de sincronización limpiada');
  }

  /// Limpiar cache de cartas
  static Future<void> clearCachedCards() async {
    final box = Hive.box(_cachedCardsBox);
    await box.clear();
    debugPrint('🧹 Cache de cartas limpiado');
  }

  /// Obtener cantidad de cartas en cache
  static Future<int> getCachedCardsCount() async {
    try {
      final box = Hive.box(_cachedCardsBox);
      return box.length;
    } catch (e) {
      debugPrint('Error getCachedCardsCount: $e');
      return 0;
    }
  }

  /// Limpiar cache de mercado
  static Future<void> clearMarketCache() async {
    try {
      // El mercado usa una caja diferente, busquémosla
      if (Hive.isBoxOpen('market_items')) {
        final box = Hive.box('market_items');
        await box.clear();
        debugPrint('🧹 Cache de mercado limpiado');
      } else {
        debugPrint('ℹ️ No hay cache de mercado abierto');
      }
    } catch (e) {
      debugPrint('Error clearMarketCache: $e');
      rethrow;
    }
  }
}
