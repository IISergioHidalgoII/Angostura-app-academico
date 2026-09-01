import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/offline_storage_service.dart';
import '../../../core/utils/qr_navigation_helper.dart';
import '../../../core/utils/collection_refresh_notifier.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage>
    with WidgetsBindingObserver {
  bool _isProcessing = false;
  bool _isCooldown = false;
  DateTime? _lastScanTime;
  String? _lastScannedCode;
  bool _isInitializing = true; // Nuevo estado de inicialización
  bool _hasPermission = true; // Estado de permisos

  // Cooldown de 3 segundos entre escaneos
  static const Duration _cooldownDuration = Duration(seconds: 3);

  final MobileScannerController _scannerController = MobileScannerController(
    formats: [BarcodeFormat.qrCode], // Solo escanear QR codes
    detectionSpeed: DetectionSpeed.normal,
  );

  @override
  void initState() {
    debugPrint('📷 _QRScannerPageState.initState() INICIADO');
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Asegurar que el estado está limpio al abrir el scanner
    _isProcessing = false;
    _isCooldown = false;
    _lastScannedCode = null;
    _lastScanTime = null;
    _isInitializing = true;
    _hasPermission = true;

    // Iniciar cámara explícitamente
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Reanudar scanner cuando la app vuelve al foreground
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 App resumed - reiniciando scanner');
      _scannerController.start();
    } else if (state == AppLifecycleState.paused) {
      // Pausar scanner cuando la app va a background
      debugPrint('⏸️ App paused - pausando scanner');
      _scannerController.stop();
    }
  }

  /// Inicializa la cámara con manejo de errores y estados
  Future<void> _initializeCamera() async {
    try {
      debugPrint('📷 Iniciando cámara...');

      // Iniciar el scanner
      await _scannerController.start();

      debugPrint('✅ Cámara iniciada correctamente');

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasPermission = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Error al iniciar cámara: $e');

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasPermission = false;
        });
      }
    }
  }

  /// Callback principal del escáner - maneja detección con cooldown
  Future<void> _onDetect(BarcodeCapture capture) async {
    debugPrint('🎯 ============================================');
    debugPrint('🎯 _onDetect LLAMADO - QR detectado por cámara');
    debugPrint('🎯 ============================================');
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) {
      debugPrint('⚠️ _onDetect: barcodes vacío, retornando');
      return;
    }

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) {
      debugPrint('⚠️ _onDetect: rawValue vacío, retornando');
      return;
    }

    debugPrint('✅ QR válido detectado: ${rawValue.trim()}');
    // Llamar al handler centralizado
    _handleRawScan(rawValue.trim());
  }

  /// Handler centralizado para procesar escaneos con cooldown
  void _handleRawScan(String rawValue) {
    debugPrint('🔄 ============================================');
    debugPrint('🔄 _handleRawScan INICIADO');
    debugPrint('🔄 rawValue: $rawValue');
    debugPrint('🔄 ============================================');
    
    // 1. Bloquear si ya está procesando
    if (_isProcessing) {
      debugPrint('⏸️ Ya procesando, ignorando...');
      return;
    }

    // 2. Bloquear si está en cooldown
    if (_isCooldown) {
      debugPrint('⏱️ En cooldown, ignorando...');
      return;
    }

    // 3. Evitar duplicados del mismo código (con ventana de 5 segundos)
    if (_lastScannedCode == rawValue) {
      final now = DateTime.now();
      if (_lastScanTime != null &&
          now.difference(_lastScanTime!) < const Duration(seconds: 5)) {
        debugPrint('🔁 Código duplicado ignorado: $rawValue');
        return;
      }
    }

    debugPrint('🔍 QR detectado: $rawValue');

    // BLOQUEAR INMEDIATAMENTE antes de procesar
    debugPrint('🔒 Bloqueando procesamiento (_isProcessing = true, _isCooldown = true)');
    _isProcessing = true;
    _isCooldown = true;
    _lastScannedCode = rawValue;
    _lastScanTime = DateTime.now();

    // Procesar el código
    debugPrint('⏩ Llamando a _onQrDetected con: $rawValue');
    _onQrDetected(rawValue);
  }

  /// Procesa el código QR detectado con validación
  Future<void> _onQrDetected(String rawValue) async {
    debugPrint('🎬 ============================================');
    debugPrint('🎬 _onQrDetected INICIADO');
    debugPrint('🎬 rawValue: "$rawValue"');
    debugPrint('🎬 ============================================');
    
    // Ya se bloqueó en _handleRawScan, solo actualizar UI
    if (mounted) {
      debugPrint('🎬 Widget mounted, actualizando UI con setState');
      setState(() {
        _isProcessing = true;
        _isCooldown = true;
      });
    } else {
      debugPrint('⚠️ Widget NO mounted, saltando setState');
    }

    try {
      debugPrint('📋 Procesando QR: "$rawValue"');

      // 1. VALIDAR: Rechazar URLs
      if (rawValue.startsWith('http://') || rawValue.startsWith('https://')) {
        debugPrint('❌ Rechazado: Es una URL');
        _showError('Este QR no pertenece a Angostura App.');
        await _startCooldown(isError: true);
        return;
      }

      // 2. VALIDAR: Solo aceptar tokens con formato ANG-*
      // Acepta: ANG-CARD-001, ANG-CARD-PATOJERGON-VERANO06-25, ANG002, etc.
      // Permite cualquier combinación de letras, números y guiones después de ANG
      final angosturaPattern = RegExp(
        r'^ANG-[A-Z0-9-]+$',
        caseSensitive: false,
      );
      if (!angosturaPattern.hasMatch(rawValue)) {
        debugPrint('❌ Rechazado: Formato inválido (esperado: ANG-XXXX)');
        _showError('Código QR inválido. Formato esperado: ANG-XXXX');
        await _startCooldown(isError: true);
        return;
      }

      debugPrint('✅ Token válido, procesando canje...');

      // 3. Token válido: procesar canje
      await _redeemToken(rawValue);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Inicia el cooldown - más corto para errores, normal para éxitos
  Future<void> _startCooldown({bool isError = false}) async {
    final cooldownTime = isError
        ? const Duration(milliseconds: 1500) // 1.5 seg para errores
        : _cooldownDuration; // 3 seg para procesamiento exitoso

    await Future.delayed(cooldownTime);

    if (mounted) {
      setState(() => _isCooldown = false);
    }
  }

  /// Canjea el token validado y redirige a la colección
  Future<void> _redeemToken(String token) async {
    debugPrint('💳 ============================================');
    debugPrint('💳 _redeemToken INICIADO');
    debugPrint('💳 token: "$token"');
    debugPrint('💳 ============================================');
    
    try {
      // Obtener usuario actual
      final currentUser = Supabase.instance.client.auth.currentUser;
      final userId = currentUser?.id ?? 'guest-user-id';

      debugPrint('👤 Usuario ID: $userId');
      debugPrint('📧 Usuario Email: ${currentUser?.email ?? "No autenticado"}');
      debugPrint('🎫 Token a canjear: "$token"');

      // Advertencia si no hay usuario autenticado
      if (currentUser == null) {
        debugPrint(
          '⚠️ ADVERTENCIA: Usuario no autenticado, usando guest-user-id',
        );
      }

      // Verificar conectividad
      final isOnline = await ConnectivityService.checkConnectivity();

      if (!isOnline) {
        // MODO OFFLINE: Intentar desbloquear desde cache local
        debugPrint('📵 Sin conexión - Buscando carta en cache local');

        // Verificar si este QR ya está en la cola de pendientes
        final pendingQRs = OfflineStorageService.getPendingQRs();
        final alreadyPending = pendingQRs.any((qr) => qr['token'] == token);

        if (alreadyPending) {
          debugPrint('⚠️ Este QR ya está en la cola de sincronización');
          _showError(
            'Este QR ya fue escaneado. Se sincronizará cuando haya conexión.',
          );
          await _startCooldown(isError: true);
          return;
        }

        // Buscar carta en cache por token/código
        final cachedCards = OfflineStorageService.getCachedCardsWithState();
        Map<String, dynamic>? matchingCard;

        for (var cardData in cachedCards) {
          final card = cardData['cards'] as Map<String, dynamic>;
          final cardCode = card['code']?.toString().toUpperCase();

          if (cardCode == token.toUpperCase()) {
            matchingCard = cardData;
            break;
          }
        }

        if (matchingCard != null) {
          final card = matchingCard['cards'] as Map<String, dynamic>;
          final cardId = card['id'] as String;
          final title = card['title'] ?? 'Carta';
          final isLocked = matchingCard['locked'] as bool;

          if (isLocked) {
            // Desbloquear carta offline
            await OfflineStorageService.unlockCardOffline(cardId);

            // Guardar QR para sincronizar después
            await OfflineStorageService.savePendingQR(token, userId);

            if (!mounted) return;

            // Notificar cambios
            CollectionRefreshNotifier().notifyCollectionChanged();

            _showSuccess('🎉 ¡"$title" desbloqueada! (offline)');
            debugPrint('🎊 Carta desbloqueada offline: $title');

            await Future.delayed(const Duration(milliseconds: 800));

            if (!mounted) return;

            // Navegar a colección
            _navigateToCollection(cardId);
          } else {
            // Ya tenía la carta
            _showError('Ya tenías "$title" en tu colección.');
            await _startCooldown(isError: true);
          }
        } else {
          // Carta no encontrada en cache - CREAR CARTA TEMPORAL
          debugPrint('⚠️ Carta no encontrada en cache, creando carta temporal');

          // Crear carta temporal y obtener ID
          final tempCardId = await OfflineStorageService.createTemporaryCard(
            token,
          );

          // Guardar QR para sincronizar después
          await OfflineStorageService.savePendingQR(token, userId);

          if (!mounted) return;

          // Notificar cambios
          CollectionRefreshNotifier().notifyCollectionChanged();

          _showSuccess('🎉 ¡Carta desbloqueada! (offline)');
          debugPrint('🎊 Carta temporal creada y desbloqueada: $tempCardId');

          await Future.delayed(const Duration(milliseconds: 800));

          if (!mounted) return;

          // Navegar a colección para ver la carta temporal
          _navigateToCollection(tempCardId);
        }
        return;
      }

      // MODO ONLINE: Canjear QR token normalmente
      debugPrint('🌐 Conexión disponible - Canjeando online');
      debugPrint('📞 ANTES de llamar a SupabaseService.redeemQrToken');
      final result = await SupabaseService.redeemQrToken(token, userId);
      debugPrint('📞 DESPUÉS de llamar a SupabaseService.redeemQrToken - result: $result');

      final alreadyOwned = result['alreadyOwned'] as bool;
      final card = result['card'] as Map<String, dynamic>;
      final cardId = card['id'] as String;
      final title = card['title'] ?? 'Carta';

      debugPrint('✅ Canje exitoso!');
      debugPrint('   📌 Carta ID: $cardId');
      debugPrint('   📛 Título: $title');
      debugPrint('   🔄 Ya tenía: $alreadyOwned');

      if (!mounted) return;

      // Siempre notificar cambios para mantener sincronizada la UI
      CollectionRefreshNotifier().notifyCollectionChanged();
      debugPrint('🔔 Notificación enviada a Collection y Dashboard');

      if (alreadyOwned) {
        // Si ya tenía la carta, mostrar mensaje y volver
        _showError('Ya tenías "$title" en tu colección.');
        await _startCooldown(isError: true);
      } else {
        // NUEVA CARTA: Mostrar éxito y cambiar al tab de Colección
        _showSuccess('¡Carta desbloqueada! 🎉');
        debugPrint('🎊 Nueva carta desbloqueada, navegando a colección...');

        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;

        // Cambiar al tab de Colección (índice 3) manteniendo el BottomNavigationBar
        debugPrint('🧭 Navegando a colección con cardId: $cardId');
        _navigateToCollection(cardId);
      }
    } catch (e) {
      debugPrint('❌ Error en _redeemToken: $e');

      if (!mounted) return;

      // Mensaje de error específico según el tipo de error
      String errorMessage;
      final errorStr = e.toString().toLowerCase();

      // Errores de clave duplicada = ya tenía la carta
      if (errorStr.contains('duplicate key') ||
          errorStr.contains('unique constraint') ||
          errorStr.contains('23505')) {
        debugPrint('ℹ️ Carta ya estaba en la colección (duplicate key)');
        // Notificar de todos modos por si hay cambios
        CollectionRefreshNotifier().notifyCollectionChanged();
        _showSuccess('Ya tienes esta carta en tu colección.');
        await _startCooldown(isError: false);
        return;
      }

      if (errorStr.contains('qr inválido') ||
          errorStr.contains('desactivado')) {
        errorMessage = 'Este código QR no existe en el sistema.';
      } else if (errorStr.contains('connection') ||
          errorStr.contains('network')) {
        errorMessage = 'Error de conexión. Verifica tu internet.';
      } else if (errorStr.contains('timeout')) {
        errorMessage = 'La petición tardó demasiado. Intenta de nuevo.';
      } else if (errorStr.contains('user_cards')) {
        errorMessage = 'Error al guardar la carta. Intenta de nuevo.';
      } else {
        errorMessage = 'Error al procesar QR: ${e.toString()}';
      }

      _showError(errorMessage);

      // Iniciar cooldown incluso con error
      await _startCooldown(isError: true);
    }
  }

  /// Navega al tab de Colección manteniendo el BottomNavigationBar
  void _navigateToCollection(String highlightCardId) {
    debugPrint('🚀 ============================================');
    debugPrint('🚀 _navigateToCollection INICIADO');
    debugPrint('🚀 ============================================');
    debugPrint('🎯 _navigateToCollection llamado con cardId: $highlightCardId');

    // Guardar el ID globalmente para que CollectionPage lo recoja
    QRNavigationHelper.setHighlightCard(highlightCardId);
    debugPrint('💾 Carta guardada en QRNavigationHelper');

    // Retornar al MainApp indicando que debe cambiar al tab de Colección
    debugPrint('🔙 Haciendo pop con resultado navigateToCollection=true');
    Navigator.of(
      context,
    ).pop({'navigateToCollection': true, 'cardId': highlightCardId});
  }

  /// Muestra un mensaje de éxito en SnackBar
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Muestra un mensaje de error en SnackBar
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        backgroundColor: const Color(AppConstants.primaryGreen),
        foregroundColor: Colors.white,
        actions: [
          if (!_isInitializing && _hasPermission) ...[
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _scannerController.toggleTorch(),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // Mostrar loader mientras inicializa (evita el símbolo "!")
          if (_isInitializing)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 80,
                      color: Colors.white70,
                    ),
                    SizedBox(height: 24),
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Inicializando cámara...',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          // Mostrar error de permisos
          else if (!_hasPermission)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 80,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '📷 Necesitamos acceso a la cámara',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Para escanear códigos QR, necesitamos permiso para usar tu cámara.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Stub: Sin permission_handler, solo mostrar mensaje
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '⚙️ Por favor, abre los ajustes de tu dispositivo y '
                              'otorga permiso de cámara a esta aplicación.',
                            ),
                            duration: Duration(seconds: 5),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Dar permiso'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppConstants.primaryGreen),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _initializeCamera,
                      child: const Text(
                        'Reintentar',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // Escáner normal (cuando todo está listo)
          else ...[
            // Escáner de QR con configuración optimizada
            MobileScanner(controller: _scannerController, onDetect: _onDetect),

            // Marco de escaneo visual con indicador de estado
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isProcessing
                        ? Colors.orange
                        : _isCooldown
                        ? Colors.grey
                        : Colors.white,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // Overlay con instrucciones dinámicas
            if (!_isProcessing)
              Positioned(
                bottom: 32,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isCooldown
                        ? 'Esperando... Puedes escanear otro QR en unos segundos'
                        : 'Apunta la cámara al código QR de Angostura App',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Overlay de procesamiento
            if (_isProcessing)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Procesando QR...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
