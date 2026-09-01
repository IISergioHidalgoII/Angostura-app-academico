import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/offline_storage_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/season_detector_service.dart';
import '../../../core/theme/season_theme.dart';
import '../../../core/utils/qr_navigation_helper.dart';
import '../../../core/utils/collection_refresh_notifier.dart';
import '../models/species_card.dart';
import '../widgets/card_3d_widget.dart';
import '../pages/species_detail_page.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage>
    with WidgetsBindingObserver {
  _CollectionPageState() {
    debugPrint('⭐ _CollectionPageState CONSTRUCTOR llamado');
  }
  late Future<List<Map<String, dynamic>>> _collectionFuture;
  String? _selectedSeason; // null = todas las temporadas (menú superior)
  String? _selectedRarity; // null = todas las rarezas (FilterChips)
  String? _selectedCardType; // null = todas, 'fauna', 'flora'
  String? _highlightCardId;
  Map<String, dynamic>? _highlightCard;
  late SeasonColors _seasonColors; // Colores de la temporada actual

  @override
  void initState() {
    debugPrint('🚀 ============================================');
    debugPrint('🚀 CollectionPage.initState() INICIADO');
    debugPrint('🚀 ============================================');
    super.initState();

    try {
      // Auto-detectar temporada actual
      debugPrint('🌡️ Detectando temporada...');
      final currentSeason = SeasonDetectorService.getCurrentSeason();
      _selectedSeason = currentSeason;
      _seasonColors = SeasonTheme.getColorsForSeason(currentSeason);
      debugPrint('✅ Temporada: $currentSeason');

      SeasonDetectorService.logCurrentSeason();
      debugPrint('🎨 Tema aplicado: $currentSeason');

      // Consumir el ID de la carta destacada si existe
      debugPrint('🔍 Consumiendo highlightCard...');
      _highlightCardId = QRNavigationHelper.consumeHighlightCard();

      if (_highlightCardId != null) {
        debugPrint(
          '🎯 CollectionPage recibió highlightCardId: $_highlightCardId',
        );
      } else {
        debugPrint('ℹ️ CollectionPage sin carta para destacar');
      }

      // Escuchar cambios globales de la colección
      debugPrint('🔔 Registrando listener...');
      CollectionRefreshNotifier().addListener(_onCollectionChanged);

      // Observar ciclo de vida de la app para detectar cuando regresa a primer plano
      debugPrint('👀 Registrando observer...');
      WidgetsBinding.instance.addObserver(this);

      debugPrint('🏁 Llamando _initializeGuestCollection...');
      _initializeGuestCollection();
      debugPrint('✅ initState completado exitosamente');
    } catch (e, stackTrace) {
      debugPrint('💥 CRASH EN initState: $e');
      debugPrint('📍 StackTrace: $stackTrace');
      rethrow;
    }
  }

  @override
  void dispose() {
    CollectionRefreshNotifier().removeListener(_onCollectionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cuando la app regresa a primer plano, refrescar
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed, refrescando colección...');
      if (mounted) {
        _refreshCollection();
      }
    }
  }

  /// Callback cuando hay cambios en la colección desde otras pantallas
  void _onCollectionChanged() {
    debugPrint('🔄 CollectionPage: detectado cambio, refrescando...');
    if (mounted) {
      _refreshCollection();
    }
  }

  /// Limpia la colección guest al iniciar para empezar siempre limpio
  void _initializeGuestCollection() {
    debugPrint('🔵 _initializeGuestCollection INICIADO');
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id ?? 'guest-user-id';
      debugPrint('   userId: $userId');

      // Verificar si es guest con child_user (invitado de household)
      final userData = StorageService.userData ?? {};
      final isGuestWithChildUser = userData['child_user_id'] != null;

      // Si es usuario guest SIN child_user (guest antiguo), limpiar su colección
      if (userId == 'guest-user-id' && !isGuestWithChildUser) {
        debugPrint(
          '🧹 Usuario guest legacy: limpiando colección para empezar limpio',
        );
        _collectionFuture = SupabaseService.resetUserCollection(userId)
            .then((_) {
              debugPrint('✅ Colección guest reseteada');
              return _loadCardsWithFallback(userId);
            })
            .catchError((e) {
              debugPrint('⚠️ Error al resetear guest: $e');
              return _loadCardsWithFallback(userId);
            });
      } else {
        // Guest con child_user o usuario normal: cargar normalmente
        if (isGuestWithChildUser) {
          debugPrint('👶 Guest con child_user: cargando colección normalmente');
        }
        _loadCollection();
      }

      // Auto-refresh cada vez que se entra a la colección
      debugPrint('⏰ Registrando postFrameCallback...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('⏰ postFrameCallback ejecutándose...');
        _refreshCollection();
      });
      debugPrint('✅ _initializeGuestCollection completado');
    } catch (e, stackTrace) {
      debugPrint('💥 CRASH EN _initializeGuestCollection: $e');
      debugPrint('📍 StackTrace: $stackTrace');
      rethrow;
    }
  }

  void _loadCollection() {
    debugPrint('🟢 _loadCollection INICIADO');
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id ?? 'guest-user-id';
      debugPrint('🔄 _loadCollection iniciado');
    debugPrint('   Usuario ID: $userId');
    if (user != null) {
      debugPrint('   Usuario autenticado: ${user.email}');
    } else {
      debugPrint('   ⚠️ Sin autenticación, usando guest-user-id');
    }

      // Intentar cargar desde Supabase, usar cache offline si falla
      debugPrint('🔄 Llamando setState...');
      setState(() {
        _collectionFuture = _loadCardsWithFallback(userId);
      });
      debugPrint('✅ _loadCollection completado');
    } catch (e, stackTrace) {
      debugPrint('💥 CRASH EN _loadCollection: $e');
      debugPrint('📍 StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Refresca la colección (llamado desde pull-to-refresh o manualmente)
  Future<void> _refreshCollection() async {
    debugPrint('🔄 _refreshCollection: recargando datos...');
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'guest-user-id';

    setState(() {
      _collectionFuture = _loadCardsWithFallback(userId);
    });
  }

  /// Carga TODAS las cartas y marca cuáles están desbloqueadas
  /// Las cartas bloqueadas se muestran con efecto locked (silueta + candado)
  Future<List<Map<String, dynamic>>> _loadCardsWithFallback(
    String userId,
  ) async {
    try {
      // Verificar conectividad primero
      final isOnline = await ConnectivityService.checkConnectivity();

      if (!isOnline) {
        debugPrint('📵 Sin conexión - Cargando desde cache offline');
        return _loadFromCache();
      }

      debugPrint(
        '🌐 Conexión disponible - Sincronizando datos pendientes antes de cargar',
      );

      // 🔄 SINCRONIZAR QRs PENDIENTES ANTES DE CARGAR DESDE SUPABASE
      final pendingQRs = OfflineStorageService.getPendingQRs();
      if (pendingQRs.isNotEmpty) {
        debugPrint('🔄 Sincronizando ${pendingQRs.length} QRs pendientes...');

        for (var qrData in pendingQRs) {
          final token = qrData['token'] as String;
          final timestamp = qrData['timestamp'].toString();

          try {
            await SupabaseService.redeemQrToken(token, userId);
            await OfflineStorageService.removePendingQR(timestamp);
            debugPrint('   ✅ Sincronizado: $token');
          } catch (e) {
            final errorStr = e.toString().toLowerCase();
            if (errorStr.contains('duplicate key') ||
                errorStr.contains('unique constraint') ||
                errorStr.contains('23505')) {
              // Ya existe, eliminar de pendientes
              await OfflineStorageService.removePendingQR(timestamp);
              debugPrint('   ℹ️ Ya existía: $token');
            } else {
              debugPrint('   ❌ Error: $token - $e');
            }
          }
        }
        debugPrint('✅ Sincronización completada');

        // Limpiar cartas temporales ya que ahora tendremos las reales
        await OfflineStorageService.cleanTemporaryCards();
      }

      debugPrint('📚 Cargando cartas desde Supabase...');

      // 1. Obtener TODAS las cartas activas con información de temporada
      // Usar JOIN para obtener el nombre de la temporada
      final allCardsResponse = await SupabaseService.client
          .from('cards')
          .select(
            'id, title, description, image_url, rarity, code, area_id, season_id, scientific_name, technical_data, curiosities, card_type, seasons(id, name)',
          )
          .eq('is_active', true)
          .order('rarity', ascending: false)
          .order('title', ascending: true);

      final allCards = List<Map<String, dynamic>>.from(allCardsResponse);
      debugPrint('🎴 Total de cartas activas: ${allCards.length}');

      if (allCards.isEmpty) {
        debugPrint('⚠️ No hay cartas activas en la base de datos');
        return [];
      }

      // 2. Obtener las cartas que el usuario ha desbloqueado
      debugPrint('🔍 Llamando getUserCards para userId: $userId');
      final unlockedUserCards = await SupabaseService.getUserCards(userId);
      debugPrint(
        '📦 getUserCards devolvió: ${unlockedUserCards.length} registros',
      );

      // Debug: verificar que los datos sean válidos
      if (unlockedUserCards.isEmpty) {
        debugPrint('ℹ️ Usuario no tiene cartas desbloqueadas');
      } else {
        debugPrint('📋 Primera carta: ${unlockedUserCards.first}');
      }

      final unlockedCardIds = unlockedUserCards
          .map((uc) {
            try {
              final card = uc['cards'] as Map<String, dynamic>?;
              if (card == null) {
                debugPrint('⚠️ Card data null en user_card: ${uc['id']}');
                debugPrint('   user_card completo: $uc');
                return null;
              }
              final cardId = card['id'] as String?;
              if (cardId == null) {
                debugPrint('⚠️ Card ID null en card: ${card['title']}');
                return null;
              }
              debugPrint('   - Desbloqueada: ${card['title']} (ID: $cardId)');
              return cardId;
            } catch (e, stackTrace) {
              debugPrint('❌ Error procesando user_card: $e');
              debugPrint('📍 StackTrace: $stackTrace');
              debugPrint('📦 Datos: $uc');
              return null;
            }
          })
          .whereType<String>()
          .toSet();
      debugPrint('🔓 Total cartas desbloqueadas: ${unlockedCardIds.length}');

      // 3. Crear lista combinada con estado locked/unlocked
      final cardsWithState = allCards.map((card) {
        final cardId = card['id'] as String;
        final isUnlocked = unlockedCardIds.contains(cardId);
        final cardTitle = card['title'] as String?;

        // Buscar información de desbloqueo si existe
        String? unlockedAt;
        String? source;

        if (isUnlocked) {
          try {
            final userCardData = unlockedUserCards.firstWhere((uc) {
              final card = uc['cards'] as Map<String, dynamic>?;
              return card != null && card['id'] == cardId;
            });
            unlockedAt = userCardData['unlocked_at']?.toString();
            source = userCardData['source']?.toString();
          } catch (e) {
            debugPrint(
              '⚠️ Error buscando datos de desbloqueo para $cardId: $e',
            );
            // Si no se encuentra, dejar null
          }
        }

        debugPrint('🃏 Carta "$cardTitle": locked=${!isUnlocked}');

        return {
          'id': cardId,
          'locked': !isUnlocked,
          'unlocked_at': unlockedAt,
          'source': source,
          'cards': card,
        };
      }).toList();

      // 4. Ordenar: desbloqueadas primero, bloqueadas al final
      cardsWithState.sort((a, b) {
        final aLocked = a['locked'] as bool;
        final bLocked = b['locked'] as bool;

        // Si tienen diferente estado, las desbloqueadas van primero
        if (aLocked != bLocked) {
          return aLocked ? 1 : -1; // locked=true va al final
        }

        // Si ambas están en el mismo estado, ordenar por título
        final aTitle = (a['cards'] as Map<String, dynamic>)['title'] as String?;
        final bTitle = (b['cards'] as Map<String, dynamic>)['title'] as String?;
        return (aTitle ?? '').compareTo(bTitle ?? '');
      });

      // 💾 GUARDAR EN CACHE para uso offline
      await OfflineStorageService.cacheAllCards(cardsWithState);
      await OfflineStorageService.saveUnlockedCardIds(unlockedCardIds);

      // 🖼️ PRECARGAR IMÁGENES para uso offline
      _preloadCardImages(cardsWithState);

      debugPrint(
        '✅ Preparadas ${cardsWithState.length} cartas (desbloqueadas primero) + guardadas en cache',
      );
      return cardsWithState;
    } catch (e) {
      debugPrint('⚠️ Error cargando cartas: $e - Usando cache');
      return _loadFromCache();
    }
  }

  /// Carga cartas desde cache local con estado locked/unlocked
  List<Map<String, dynamic>> _loadFromCache() {
    return OfflineStorageService.getCachedCardsWithState();
  }

  /// Precarga imágenes en segundo plano para cache offline usando CachedNetworkImage
  void _preloadCardImages(List<Map<String, dynamic>> cards) {
    debugPrint(
      '🖼️ Iniciando precarga de ${cards.length} imágenes con CachedNetworkImage...',
    );

    int precargadas = 0;
    int contadorCartas = 0;

    for (final cardData in cards) {
      final card = cardData['cards'] as Map<String, dynamic>?;
      if (card == null) continue;

      final imageUrl = card['image_url'] as String?;
      final cardCode = card['code'] as String?;

      if (imageUrl != null && imageUrl.isNotEmpty && cardCode != null) {
        contadorCartas++;
        try {
          // Usar CachedNetworkImageProvider con el mismo cacheKey que el widget
          final cacheKey = 'card_${cardCode}_${imageUrl.hashCode}';
          precacheImage(
                CachedNetworkImageProvider(imageUrl, cacheKey: cacheKey),
                context,
              )
              .then((_) {
                precargadas++;
                if (precargadas % 5 == 0 || precargadas == contadorCartas) {
                  debugPrint(
                    '   📥 Precargadas $precargadas/$contadorCartas imágenes',
                  );
                }
              })
              .catchError((e) {
                debugPrint('   ⚠️ Error precargando ${card['title']}: $e');
              });
        } catch (e) {
          debugPrint('   ❌ Error al intentar precargar ${card['title']}: $e');
        }
      }
    }

    debugPrint('✅ Precarga de $contadorCartas imágenes iniciada en background');
  }

  /// Busca la carta destacada dentro de allCards y la guarda en _highlightCard
  /// NO modifica allCards, solo lee
  void _findHighlightCard(List<Map<String, dynamic>> allCards) {
    if (_highlightCardId == null) {
      _highlightCard = null;
      return;
    }

    debugPrint(
      '🔎 Buscando carta $_highlightCardId en ${allCards.length} cartas...',
    );

    // Buscar la carta en la lista completa
    for (final userCard in allCards) {
      final card = userCard['cards'] as Map<String, dynamic>?;
      if (card != null && card['id'] == _highlightCardId) {
        _highlightCard = card;
        debugPrint('✅ Carta encontrada: ${card['title']}');
        return;
      }
    }

    debugPrint('⚠️ Carta $_highlightCardId NO encontrada en la colección');
    _highlightCard = null;
  }

  /// Aplica filtros sobre allCards y devuelve lista filtrada
  /// Aplica filtros de temporada Y rareza simultáneamente
  /// NO modifica allCards, NO inserta ni elimina elementos
  List<Map<String, dynamic>> _filterCards(List<Map<String, dynamic>> allCards) {
    return allCards.where((userCard) {
      final card = userCard['cards'] as Map<String, dynamic>?;
      if (card == null) return false;

      // Filtro 1: Temporada (si está activo)
      if (_selectedSeason != null && _selectedSeason!.isNotEmpty) {
        // Obtener el nombre de la temporada desde el JOIN
        final seasonData = card['seasons'];
        String? cardSeasonName;

        if (seasonData != null && seasonData is Map) {
          cardSeasonName = seasonData['name']?.toString().toLowerCase();
        }

        // Comparar con la temporada seleccionada
        if (cardSeasonName == null ||
            !cardSeasonName.contains(_selectedSeason!.toLowerCase())) {
          return false;
        }
      }

      // Filtro 2: Rareza o Estado de Conservación (si está activo)
      if (_selectedRarity != null && _selectedRarity!.isNotEmpty) {
        if (_selectedRarity == 'amenazado') {
          // Filtro especial: mostrar cartas amenazadas o en extinción
          final threatLevel =
              card['threat_level']?.toString() ??
              card['threatLevel']?.toString() ??
              card['conservation_threat']?.toString();

          if (threatLevel == null) return false;

          final normalized = threatLevel.toLowerCase().trim();
          final isEndangered =
              normalized.contains('amenaz') ||
              normalized.contains('extinc') ||
              normalized.contains('endanger') ||
              normalized.contains('critical') ||
              normalized.contains('vulnerable') ||
              normalized.contains('threat');

          if (!isEndangered) return false;
        } else {
          // Filtro normal de rareza
          final rarity = (card['rarity'] as String?)?.toLowerCase().trim();
          if (rarity == null) return false;

          // Normalizar para comparación sin tildes ni mayúsculas
          final normalizedRarity = rarity
              .toLowerCase()
              .replaceAll('é', 'e')
              .replaceAll('í', 'i')
              .replaceAll('ó', 'o')
              .replaceAll('ú', 'u')
              .replaceAll('á', 'a');

          final normalizedFilter = _selectedRarity!
              .toLowerCase()
              .replaceAll('é', 'e')
              .replaceAll('í', 'i')
              .replaceAll('ó', 'o')
              .replaceAll('ú', 'u')
              .replaceAll('á', 'a');

          debugPrint(
            '🔍 Comparando rareza: "$normalizedRarity" vs filtro "$normalizedFilter"',
          );

          if (normalizedRarity != normalizedFilter) {
            return false;
          }
        }
      }

      // Filtro 3: Tipo de carta (Flora/Fauna)
      if (_selectedCardType != null && _selectedCardType!.isNotEmpty) {
        // Intentar acceder desde ambas estructuras posibles
        final cardData = card['cards'] ?? card;
        final cardType = cardData['card_type']?.toString();

        debugPrint(
          '🔍 Filtro card_type: buscando "$_selectedCardType", encontrado: "$cardType"',
        );

        if (cardType == null ||
            cardType.toLowerCase().trim() != _selectedCardType) {
          return false;
        }
      }

      return true; // Pasa todos los filtros
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 CollectionPage.build() llamado');
    return Scaffold(
      backgroundColor: _seasonColors.cardBackground,
      appBar: AppBar(
        title: Text(
          '🎴 Mi Colección ${SeasonDetectorService.getSeasonEmoji(_selectedSeason ?? "")}',
        ),
        backgroundColor: _seasonColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar colección',
            onPressed: _refreshCollection,
          ),
          PopupMenuButton<String?>(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Filtrar por temporada',
            onSelected: (value) {
              setState(() {
                _selectedSeason = value;
                // Actualizar colores del tema según temporada seleccionada
                if (value != null) {
                  _seasonColors = SeasonTheme.getColorsForSeason(value);
                  debugPrint('🎨 Tema cambiado a: $value');
                } else {
                  // Si es "Todas", usar temporada actual
                  final currentSeason =
                      SeasonDetectorService.getCurrentSeason();
                  _seasonColors = SeasonTheme.getColorsForSeason(currentSeason);
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20),
                    SizedBox(width: 8),
                    Text('Todas las temporadas'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: Season.verano,
                child: Row(
                  children: [
                    const Icon(Icons.wb_sunny, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(Season.labels[Season.verano]!),
                  ],
                ),
              ),
              PopupMenuItem(
                value: Season.otono,
                child: Row(
                  children: [
                    const Icon(Icons.eco, size: 18, color: Colors.brown),
                    const SizedBox(width: 8),
                    Text(Season.labels[Season.otono]!),
                  ],
                ),
              ),
              PopupMenuItem(
                value: Season.invierno,
                child: Row(
                  children: [
                    const Icon(Icons.ac_unit, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(Season.labels[Season.invierno]!),
                  ],
                ),
              ),
              PopupMenuItem(
                value: Season.primavera,
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_florist,
                      size: 18,
                      color: Colors.pink,
                    ),
                    const SizedBox(width: 8),
                    Text(Season.labels[Season.primavera]!),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros por rareza (chips - siempre visibles)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text(
                    'Todas',
                    style: TextStyle(color: Colors.black),
                  ),
                  selected: _selectedRarity == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedRarity = null;
                    });
                  },
                  avatar: _selectedRarity == null
                      ? const Icon(Icons.check_circle, size: 18)
                      : const Icon(Icons.circle_outlined, size: 18),
                ),
                FilterChip(
                  label: const Text(
                    'Común',
                    style: TextStyle(color: Colors.black),
                  ),
                  selected: _selectedRarity == 'común',
                  onSelected: (selected) {
                    setState(() {
                      _selectedRarity = selected ? 'común' : null;
                    });
                  },
                  avatar: Icon(
                    Icons.circle,
                    size: 16,
                    color: _selectedRarity == 'común'
                        ? Colors.white
                        : Colors.grey,
                  ),
                  selectedColor: Colors.grey,
                  checkmarkColor: Colors.white,
                ),
                FilterChip(
                  label: const Text(
                    'Rara',
                    style: TextStyle(color: Colors.black),
                  ),
                  selected: _selectedRarity == 'rara',
                  onSelected: (selected) {
                    setState(() {
                      _selectedRarity = selected ? 'rara' : null;
                    });
                  },
                  avatar: Icon(
                    Icons.circle,
                    size: 16,
                    color: _selectedRarity == 'rara'
                        ? Colors.white
                        : Colors.blue,
                  ),
                  selectedColor: Colors.blue,
                  checkmarkColor: Colors.white,
                ),
                FilterChip(
                  label: const Text(
                    'Épica',
                    style: TextStyle(color: Colors.black),
                  ),
                  selected: _selectedRarity == 'épica',
                  onSelected: (selected) {
                    setState(() {
                      _selectedRarity = selected ? 'épica' : null;
                    });
                  },
                  avatar: Icon(
                    Icons.circle,
                    size: 16,
                    color: _selectedRarity == 'épica'
                        ? Colors.white
                        : Colors.purple,
                  ),
                  selectedColor: Colors.purple,
                  checkmarkColor: Colors.white,
                ),
                FilterChip(
                  label: const Text(
                    'Amenazadas',
                    style: TextStyle(color: Colors.black),
                  ),
                  selected: _selectedRarity == 'amenazado',
                  onSelected: (selected) {
                    setState(() {
                      _selectedRarity = selected ? 'amenazado' : null;
                    });
                  },
                  avatar: Icon(
                    Icons.warning,
                    size: 16,
                    color: _selectedRarity == 'amenazado'
                        ? Colors.white
                        : const Color(0xFFFFA726),
                  ),
                  selectedColor: const Color(0xFFFFA726),
                  checkmarkColor: Colors.white,
                ),
              ],
            ),
          ),
          // Filtros por tipo (Flora/Fauna)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text(
                    '🦌 Fauna',
                    style: TextStyle(color: Colors.black),
                  ),
                  selected: _selectedCardType == 'fauna',
                  onSelected: (selected) {
                    setState(() {
                      _selectedCardType = selected ? 'fauna' : null;
                    });
                  },
                  selectedColor: Colors.green.shade100,
                  checkmarkColor: Colors.green.shade800,
                ),
                FilterChip(
                  label: const Text(
                    '🌿 Flora',
                    style: TextStyle(color: Colors.black),
                  ),
                  selected: _selectedCardType == 'flora',
                  onSelected: (selected) {
                    setState(() {
                      _selectedCardType = selected ? 'flora' : null;
                    });
                  },
                  selectedColor: Colors.teal.shade100,
                  checkmarkColor: Colors.teal.shade800,
                ),
              ],
            ),
          ),
          // Grid de cartas
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _collectionFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint('❌ Error en FutureBuilder: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                // 1. Obtener TODAS las cartas del usuario desde Supabase
                final allCards = snapshot.data ?? [];
                debugPrint(
                  '🎴 FutureBuilder recibió ${allCards.length} cartas en snapshot.data',
                );

                // 2. Buscar la carta destacada (sin modificar allCards)
                _findHighlightCard(allCards);

                // 3. Aplicar filtros (sin modificar allCards)
                final filteredCards = _filterCards(allCards);

                if (filteredCards.isEmpty) {
                  final hasFilters =
                      _selectedSeason != null ||
                      _selectedRarity != null ||
                      _selectedCardType != null;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasFilters
                              ? Icons.search_off
                              : Icons.collections_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          hasFilters
                              ? 'No hay cartas con esta rareza'
                              : 'Tu colección está vacía',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasFilters
                              ? 'Intenta seleccionar otra rareza'
                              : 'Escanea códigos QR en el parque\npara comenzar a coleccionar',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Vista destacada de la carta recién escaneada
                    if (_highlightCard != null)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.amber, width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 24,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '¡Nueva carta obtenida!',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Colors.amber[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _highlightCard!['title'] ?? 'Sin título',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                if (_highlightCard!['rarity'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getRarityColor(
                                        _highlightCard!['rarity'],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _highlightCard!['rarity']
                                          .toString()
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                if (_highlightCard!['description'] != null)
                                  Text(
                                    _highlightCard!['description'],
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _highlightCardId = null;
                                        _highlightCard = null;
                                      });
                                    },
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Cerrar'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Grid de cartas - SIEMPRE mostrar todas las cartas filtradas
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                        itemCount: filteredCards.length,
                        itemBuilder: (context, index) {
                          final userCard = filteredCards[index];

                          // Crear SpeciesCard desde los datos
                          final species = SpeciesCard.fromSupabase(userCard);

                          // Verificar si es la carta destacada
                          final isHighlighted =
                              _highlightCardId != null &&
                              species.id == _highlightCardId;

                          return Stack(
                            children: [
                              Card3DWidget(
                                species: species,
                                compact: true,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SpeciesDetailPage(species: species),
                                    ),
                                  );
                                },
                              ),

                              // Badge de "Nueva" si es destacada
                              if (isHighlighted)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'NUEVA',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(String? rarity) {
    switch (rarity?.toLowerCase()) {
      case 'legendary':
      case 'legendaria':
        return Colors.amber;
      case 'epic':
      case 'épica':
        return Colors.purple;
      case 'rare':
      case 'rara':
        return Colors.blue;
      case 'common':
      case 'común':
        return Colors.grey;
      default:
        return Colors.teal;
    }
  }
}
