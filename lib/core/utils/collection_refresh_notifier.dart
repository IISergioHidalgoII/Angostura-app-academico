import 'package:flutter/foundation.dart';

/// Notificador global para refrescar la colección después de cambios
class CollectionRefreshNotifier extends ChangeNotifier {
  static final CollectionRefreshNotifier _instance =
      CollectionRefreshNotifier._internal();

  factory CollectionRefreshNotifier() => _instance;

  CollectionRefreshNotifier._internal();

  /// Notifica que la colección debe refrescarse
  void notifyCollectionChanged() {
    debugPrint('🔔 CollectionRefreshNotifier: notificando cambios');
    notifyListeners();
  }
}
