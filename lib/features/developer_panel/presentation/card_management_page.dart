import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cached_image_service.dart';

/// CAP 8 - Card Management
/// CRUD de cartas con soft delete (is_active)
class CardManagementPage extends ConsumerStatefulWidget {
  const CardManagementPage({super.key});

  @override
  ConsumerState<CardManagementPage> createState() => _CardManagementPageState();
}

class _CardManagementPageState extends ConsumerState<CardManagementPage> {
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _seasons = [];
  List<Map<String, dynamic>> _sites = [];
  bool _isLoading = true;
  String? _selectedSeasonId;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _loadSites();
    _loadSeasons();
  }

  Future<void> _loadSites() async {
    try {
      final response = await SupabaseService.client
          .from('sites')
          .select('id, name, region')
          .order('name', ascending: true);

      setState(() {
        _sites = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('❌ Error cargando sites: $e');
    }
  }

  Future<void> _loadSeasons() async {
    try {
      debugPrint('🔄 Cargando temporadas...');
      final response = await SupabaseService.client
          .from('seasons')
          .select('*')
          .order('start_date', ascending: false);

      debugPrint('📊 Temporadas obtenidas: ${response.length}');
      for (var season in response) {
        debugPrint('   - ${season['name']} (ID: ${season['id']})');
      }

      setState(() {
        _seasons = List<Map<String, dynamic>>.from(response);
        if (_seasons.isNotEmpty) {
          _selectedSeasonId = _seasons.first['season_id'];
          debugPrint('✅ Temporada seleccionada: $_selectedSeasonId');
          _loadCards();
        } else {
          debugPrint('⚠️ No hay temporadas disponibles');
        }
      });
    } catch (e) {
      debugPrint('❌ Error cargando temporadas: $e');
    }
  }

  Future<void> _loadCards() async {
    if (_selectedSeasonId == null) {
      debugPrint('⚠️ No se puede cargar cartas: _selectedSeasonId es null');
      return;
    }

    debugPrint('🔄 Cargando cartas para temporada: $_selectedSeasonId');
    debugPrint('   Mostrar inactivas: $_showInactive');

    setState(() => _isLoading = true);
    try {
      final query = SupabaseService.client
          .from('cards')
          .select('*, seasons(name)')
          .eq('season_id', _selectedSeasonId!);

      // Si NO queremos mostrar inactivas, filtramos por is_active = true
      final response = _showInactive
          ? await query.order('title', ascending: true)
          : await query.eq('is_active', true).order('title', ascending: true);

      debugPrint('📊 Cartas obtenidas: ${response.length}');
      if (response.isEmpty) {
        debugPrint('⚠️ No se encontraron cartas para esta temporada');
      } else {
        for (var card in response) {
          debugPrint(
            '   - ${card['title']} (${card['code']}) - Active: ${card['is_active']}',
          );
        }
      }

      setState(() {
        _cards = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      debugPrint('✅ Cartas cargadas exitosamente: ${_cards.length}');
    } catch (e) {
      debugPrint('❌ Error cargando cartas: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showCreateEditDialog([Map<String, dynamic>? card]) async {
    final isEdit = card != null;
    final titleController = TextEditingController(text: card?['title']);
    final codeController = TextEditingController(text: card?['code']);
    final scientificNameController = TextEditingController(
      text: card?['scientific_name'],
    );
    final descriptionController = TextEditingController(
      text: card?['description'],
    );
    final technicalDataController = TextEditingController(
      text: card?['technical_data'],
    );
    final curiositiesController = TextEditingController(
      text: card?['curiosities'],
    );
    final imageUrlController = TextEditingController(text: card?['image_url']);

    // Validar tipo de carta
    final validCardTypes = ['fauna', 'flora'];
    String selectedCardType = card?['card_type'] ?? 'fauna';
    if (!validCardTypes.contains(selectedCardType)) {
      selectedCardType = 'fauna';
    }

    // Validar rareza - usar 'comun' si el valor no es válido
    final validRarities = ['comun', 'rara', 'epica', 'amenazada'];
    String selectedRarity = card?['rarity'] ?? 'comun';
    if (!validRarities.contains(selectedRarity)) {
      selectedRarity = 'comun';
    }

    // Validar season_id - usar la primera temporada disponible si el valor no existe
    String? selectedSeasonId = card?['season_id'] ?? _selectedSeasonId;
    if (selectedSeasonId != null && _seasons.isNotEmpty) {
      final seasonExists = _seasons.any(
        (s) => s['season_id'] == selectedSeasonId,
      );
      if (!seasonExists) {
        selectedSeasonId = _seasons.first['season_id'];
      }
    }

    // Validar site_id - usar null si el valor no existe
    String? selectedSiteId = card?['site_id'];
    if (selectedSiteId != null && _sites.isNotEmpty) {
      final siteExists = _sites.any((s) => s['id'] == selectedSiteId);
      if (!siteExists) {
        selectedSiteId = null;
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Editar Carta' : 'Nueva Carta'),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Código (ej: AVE001)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scientificNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Científico',
                      hintText: 'ej: Hippocamelus bisulcus',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.science),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Descripción general de la especie',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: technicalDataController,
                    decoration: const InputDecoration(
                      labelText: 'Datos Técnicos',
                      hintText:
                          'Familia: Cervidae\nPeso: 70-90 kg\nAltura: 1.5-1.7 m\nDieta: Herbívoro\nEstado: En Peligro\nEsperanza de vida: 12-15 años',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.list_alt),
                    ),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: curiositiesController,
                    decoration: const InputDecoration(
                      labelText: 'Curiosidades (Opcional)',
                      hintText: 'Datos interesantes sobre la especie',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.lightbulb_outline),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL de Imagen',
                      border: OutlineInputBorder(),
                      hintText: 'https://ejemplo.com/imagen.jpg',
                      prefixIcon: Icon(Icons.image),
                    ),
                    onChanged: (value) {
                      setDialogState(() {});
                    },
                  ),
                  if (imageUrlController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrlController.text,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 150,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'URL inválida',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCardType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Carta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'fauna',
                        child: Text('🦌 Fauna (Animales)'),
                      ),
                      DropdownMenuItem(
                        value: 'flora',
                        child: Text('🌿 Flora (Plantas)'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => selectedCardType = value!);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRarity,
                    decoration: const InputDecoration(
                      labelText: 'Rareza',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'comun', child: Text('⚪ Común')),
                      DropdownMenuItem(value: 'rara', child: Text('🔵 Rara')),
                      DropdownMenuItem(value: 'epica', child: Text('🟣 Épica')),
                      DropdownMenuItem(
                        value: 'amenazada',
                        child: Text('🔴 Amenazada'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => selectedRarity = value!);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_seasons.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No hay temporadas disponibles. Crea una temporada primero en Gestión de Temporadas.',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedSeasonId ?? _seasons.first['season_id'],
                      decoration: const InputDecoration(
                        labelText: 'Temporada',
                        border: OutlineInputBorder(),
                      ),
                      items: _seasons.map((season) {
                        return DropdownMenuItem<String>(
                          value: season['season_id'],
                          child: Text(season['name'] ?? 'Sin nombre'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedSeasonId = value);
                      },
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedSiteId,
                    decoration: const InputDecoration(
                      labelText: 'Sitio/Lugar (Opcional)',
                      border: OutlineInputBorder(),
                      hintText: 'Seleccionar sitio donde escanear',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin sitio específico'),
                      ),
                      ..._sites.map((site) {
                        return DropdownMenuItem<String>(
                          value: site['id'],
                          child: Text('${site['name']} (${site['region']})'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setDialogState(() => selectedSiteId = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty ||
                    codeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Título y Código son requeridos'),
                    ),
                  );
                  return;
                }

                if (selectedSeasonId == null || _seasons.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Debe seleccionar una temporada. Crea una temporada primero.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  final data = {
                    'title': titleController.text,
                    'code': codeController.text,
                    'scientific_name': scientificNameController.text.isEmpty
                        ? null
                        : scientificNameController.text,
                    'description': descriptionController.text,
                    'technical_data': technicalDataController.text.isEmpty
                        ? null
                        : technicalDataController.text,
                    'curiosities': curiositiesController.text.isEmpty
                        ? null
                        : curiositiesController.text,
                    'image_url': imageUrlController.text.isEmpty
                        ? null
                        : imageUrlController.text,
                    'card_type': selectedCardType,
                    'rarity': selectedRarity,
                    'season_id': selectedSeasonId,
                    'site_id': selectedSiteId,
                    'is_active': true,
                  };

                  if (isEdit) {
                    await SupabaseService.client
                        .from('cards')
                        .update(data)
                        .eq('id', card['id']);
                  } else {
                    await SupabaseService.client.from('cards').insert(data);
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit ? '✅ Carta actualizada' : '✅ Carta creada',
                        ),
                      ),
                    );
                    _loadCards();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: Text(isEdit ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCardActive(Map<String, dynamic> card) async {
    final newState = !(card['is_active'] ?? true);
    try {
      await SupabaseService.client
          .from('cards')
          .update({'is_active': newState})
          .eq('id', card['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newState ? '✅ Carta activada' : '🔒 Carta desactivada',
            ),
          ),
        );
        _loadCards();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteCard(String cardId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Carta'),
        content: const Text(
          '¿Está seguro? Esta acción es permanente.\n\n'
          'Recomendación: Use desactivar en lugar de eliminar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService.client.from('cards').delete().eq('id', cardId);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('✅ Carta eliminada')));
          _loadCards();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  String _getRarityEmoji(String? rarity) {
    switch (rarity) {
      case 'comun':
        return '⚪';
      case 'rara':
        return '🔵';
      case 'epica':
        return '🟣';
      case 'amenazada':
        return '🔴';
      default:
        return '⚪';
    }
  }

  Color _getRarityColor(String? rarity) {
    switch (rarity) {
      case 'comun':
        return Colors.grey;
      case 'rara':
        return Colors.blue;
      case 'epica':
        return Colors.purple;
      case 'amenazada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Cartas'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() => _showInactive = !_showInactive);
              _loadCards();
            },
            tooltip: _showInactive ? 'Ocultar inactivas' : 'Mostrar inactivas',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Carta'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          if (_seasons.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.purple.shade50,
              child: Row(
                children: [
                  const Text(
                    'Temporada:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedSeasonId,
                      isExpanded: true,
                      items: _seasons.map((season) {
                        return DropdownMenuItem<String>(
                          value: season['season_id'],
                          child: Text(season['name'] ?? 'Sin nombre'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedSeasonId = value);
                        _loadCards();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cards.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.style_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay cartas',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Crea la primera carta para esta temporada',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cards.length,
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      final isActive = card['is_active'] ?? true;
                      final rarity = card['rarity'] as String?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: isActive ? 2 : 1,
                        color: isActive ? null : Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _getRarityColor(rarity).withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading:
                              card['image_url'] != null &&
                                  card['image_url'].toString().isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedImageService.buildCardImage(
                                    imageUrl: card['image_url'],
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    cardId: card['id'],
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: _getRarityColor(rarity),
                                  child: Text(
                                    _getRarityEmoji(rarity),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  card['title'] ?? 'Sin título',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    decoration: isActive
                                        ? null
                                        : TextDecoration.lineThrough,
                                    color: isActive ? null : Colors.grey[600],
                                  ),
                                ),
                              ),
                              if (!isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'INACTIVA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Código: ${card['code'] ?? 'N/A'}',
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                              if (card['description'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  card['description'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Rareza: ${rarity ?? 'comun'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getRarityColor(rarity),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  _showCreateEditDialog(card);
                                  break;
                                case 'toggle':
                                  _toggleCardActive(card);
                                  break;
                                case 'delete':
                                  _deleteCard(card['id']);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 20),
                                    SizedBox(width: 8),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(
                                  children: [
                                    Icon(
                                      isActive
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(isActive ? 'Desactivar' : 'Activar'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Eliminar',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
