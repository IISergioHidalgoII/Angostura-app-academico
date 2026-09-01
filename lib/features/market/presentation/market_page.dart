import 'package:flutter/material.dart';
import 'package:angostura_appv1/core/services/supabase_service.dart';
import 'package:angostura_appv1/core/services/connectivity_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/season_theme.dart';
import '../../../core/services/season_detector_service.dart';
import 'market_detail_page.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  late Future<List<Map<String, dynamic>>> _itemsFuture;
  String _searchQuery = '';
  String? _selectedCategory; // null = todas

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    _itemsFuture = _loadItemsWithFallback();
  }

  /// Intenta cargar desde Supabase, usa cache offline si no hay conexión
  Future<List<Map<String, dynamic>>> _loadItemsWithFallback() async {
    try {
      // Verificar conectividad
      final isOnline = await ConnectivityService.checkConnectivity();

      if (!isOnline) {
        debugPrint('📵 Market sin conexión - Cargando desde cache');
        return _loadFromCache();
      }

      // Intentar cargar desde Supabase
      debugPrint('🌐 Market cargando desde Supabase');
      final items = await SupabaseService.getMarketItems();

      // Cachear para uso offline futuro
      await _cacheItems(items);

      return items;
    } catch (e) {
      // Si falla, usar cache
      debugPrint('⚠️ Error cargando market desde Supabase: $e');
      debugPrint('📦 Usando cache offline de market...');
      return _loadFromCache();
    }
  }

  /// Guardar items en cache local con upsert por id
  Future<void> _cacheItems(List<Map<String, dynamic>> items) async {
    try {
      final box = await Hive.openBox('market_cache');

      // Obtener cache actual
      final existingCache = box.get(
        'items_map',
        defaultValue: <String, dynamic>{},
      );
      final itemsMap = Map<String, dynamic>.from(existingCache);

      // Upsert: actualizar o insertar por id (con products limitado)
      for (final item in items) {
        final id = item['id']?.toString();
        if (id != null) {
          // Limitar products a máximo 6 items antes de cachear
          final itemToCache = Map<String, dynamic>.from(item);
          itemToCache['products'] = _limitProducts(item['products']);
          itemsMap[id] = itemToCache;
        }
      }

      // Guardar mapa actualizado
      await box.put('items_map', itemsMap);
      debugPrint(
        '💾 ${items.length} items de market cacheados/actualizados (${itemsMap.length} total)',
      );
    } catch (e) {
      debugPrint('⚠️ Error cacheando market: $e');
    }
  }

  /// Limitar products a máximo 6 items para cache liviana
  dynamic _limitProducts(dynamic products) {
    if (products == null) return null;

    if (products is List) {
      return products.take(6).toList();
    }

    if (products is String) {
      try {
        // Intentar parsear y limitar
        final decoded = Uri.decodeComponent(products);
        final parsed = Uri.splitQueryString(decoded).values.toList();
        return parsed.take(6).toList();
      } catch (e) {
        return products; // Retornar original si falla parsing
      }
    }

    return products;
  }

  /// Cargar items desde cache local
  Future<List<Map<String, dynamic>>> _loadFromCache() async {
    try {
      final box = await Hive.openBox('market_cache');

      // Intentar leer desde mapa (nuevo formato)
      final itemsMap = box.get('items_map');
      if (itemsMap != null && itemsMap is Map) {
        final items = List<Map<String, dynamic>>.from(
          itemsMap.values.map((item) => Map<String, dynamic>.from(item)),
        );
        debugPrint('📦 ${items.length} items cargados desde cache (mapa)');
        return items;
      }

      // Fallback: leer formato antiguo (lista)
      final cached = box.get('items');
      if (cached != null && cached is List) {
        final items = List<Map<String, dynamic>>.from(
          cached.map((item) => Map<String, dynamic>.from(item)),
        );
        debugPrint(
          '📦 ${items.length} items cargados desde cache (lista legacy)',
        );
        return items;
      }

      debugPrint('ℹ️ No hay items en cache de market');
      return [];
    } catch (e) {
      debugPrint('❌ Error leyendo cache de market: $e');
      return [];
    }
  }

  bool _isNew(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      return difference.inDays <= 7;
    } catch (e) {
      return false;
    }
  }

  List<Map<String, dynamic>> _filterItems(List<Map<String, dynamic>> items) {
    var filtered = items;

    // Filtrar por categoría
    if (_selectedCategory != null) {
      filtered = filtered.where((item) {
        final category = (item['category'] ?? '').toString();
        return category == _selectedCategory;
      }).toList();
    }

    // Filtrar por nombre (búsqueda de texto)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        return title.contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final seasonColors = SeasonTheme.getColorsForSeason(
      SeasonDetectorService.getCurrentSeason(),
    );

    return Scaffold(
      backgroundColor: seasonColors.cardBackground,
      appBar: AppBar(
        title: const Text('Mercado local'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () {
              setState(() {
                _loadItems();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Filtros de categoría
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Todas'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                  avatar: _selectedCategory == null
                      ? const Icon(Icons.check_circle, size: 18)
                      : const Icon(Icons.circle_outlined, size: 18),
                ),
                FilterChip(
                  label: const Text('Gastronomía'),
                  selected: _selectedCategory == 'Gastronomía',
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? 'Gastronomía' : null;
                    });
                  },
                  avatar: Icon(
                    Icons.restaurant,
                    size: 16,
                    color: _selectedCategory == 'Gastronomía'
                        ? Colors.white
                        : Colors.orange,
                  ),
                  selectedColor: Colors.orange,
                  checkmarkColor: Colors.white,
                ),
                FilterChip(
                  label: const Text('Artesanía'),
                  selected: _selectedCategory == 'Artesanía',
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? 'Artesanía' : null;
                    });
                  },
                  avatar: Icon(
                    Icons.palette,
                    size: 16,
                    color: _selectedCategory == 'Artesanía'
                        ? Colors.white
                        : Colors.purple,
                  ),
                  selectedColor: Colors.purple,
                  checkmarkColor: Colors.white,
                ),
                FilterChip(
                  label: const Text('Turismo'),
                  selected: _selectedCategory == 'Turismo',
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? 'Turismo' : null;
                    });
                  },
                  avatar: Icon(
                    Icons.tour,
                    size: 16,
                    color: _selectedCategory == 'Turismo'
                        ? Colors.white
                        : Colors.blue,
                  ),
                  selectedColor: Colors.blue,
                  checkmarkColor: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final allItems = snapshot.data ?? [];
                final items = _filterItems(allItems);

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No hay emprendedores registrados todavía'
                          : 'No se encontraron resultados',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isVerified = item['is_active'] == true;
                    final isNew = _isNew(
                      item['updated_at'] ?? item['created_at'],
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MarketDetailPage(marketItem: item),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Thumbnail
                                  if (item['image_url'] != null &&
                                      item['image_url'].toString().isNotEmpty)
                                    Container(
                                      width: 80,
                                      height: 80,
                                      margin: const EdgeInsets.only(right: 12),
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.grey.shade200,
                                      ),
                                      child: Image.network(
                                        item['image_url'],
                                        fit: BoxFit.cover,
                                        cacheWidth: 160,
                                        cacheHeight: 160,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                              strokeWidth: 2,
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return _buildPlaceholder(
                                                item['category'],
                                              );
                                            },
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 80,
                                      height: 80,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: _buildPlaceholder(
                                        item['category'],
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'] ?? '',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        if (item['category'] != null &&
                                            item['category']
                                                .toString()
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              item['category'],
                                              style: TextStyle(
                                                color: Colors.purple.shade900,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isNew)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'NUEVO',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (item['description'] != null &&
                                  item['description']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  item['description'],
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (item['location_label'] != null &&
                                      item['location_label']
                                          .toString()
                                          .isNotEmpty) ...[
                                    Icon(
                                      Icons.place,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        item['location_label'],
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (item['contact_info'] != null &&
                                      item['contact_info']
                                          .toString()
                                          .isNotEmpty)
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.phone,
                                            size: 16,
                                            color: Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item['contact_info'],
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isVerified
                                          ? Colors.green.shade50
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isVerified
                                            ? Colors.green.shade300
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isVerified
                                              ? Icons.verified
                                              : Icons.error_outline,
                                          size: 18,
                                          color: isVerified
                                              ? Colors.green.shade700
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isVerified
                                              ? 'Verificado'
                                              : 'Sin verificar',
                                          style: TextStyle(
                                            color: isVerified
                                                ? Colors.green.shade900
                                                : Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Placeholder para items sin imagen
  Widget _buildPlaceholder(String? category) {
    IconData icon;
    Color color;

    switch (category?.toLowerCase()) {
      case 'gastronomía':
      case 'gastronomia':
        icon = Icons.restaurant;
        color = Colors.orange;
        break;
      case 'artesanía':
      case 'artesania':
        icon = Icons.palette;
        color = Colors.purple;
        break;
      case 'turismo':
        icon = Icons.tour;
        color = Colors.blue;
        break;
      default:
        icon = Icons.store;
        color = Colors.green;
    }

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Icon(icon, size: 40, color: color)),
    );
  }
}
