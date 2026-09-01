import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cached_image_service.dart';

class AreasManagementPage extends StatefulWidget {
  const AreasManagementPage({super.key});

  @override
  State<AreasManagementPage> createState() => _AreasManagementPageState();
}

class _AreasManagementPageState extends State<AreasManagementPage> {
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _sites = [];
  bool _isLoading = true;
  String? _selectedSiteFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadSites();
    await _loadAreas();
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando sitios: $e')));
      }
    }
  }

  Future<void> _loadAreas() async {
    setState(() => _isLoading = true);

    try {
      var query = SupabaseService.client
          .from('areas')
          .select('*, sites(name, region)');

      // Aplicar filtro por sitio si está seleccionado
      if (_selectedSiteFilter != null) {
        query = query.eq('site_id', _selectedSiteFilter!);
      }

      final response = await query.order('name', ascending: true);

      setState(() {
        _areas = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando áreas: $e')));
      }
    }
  }

  Future<void> _showAreaDialog({Map<String, dynamic>? area}) async {
    final nameController = TextEditingController(text: area?['name'] ?? '');
    final descriptionController = TextEditingController(
      text: area?['description'] ?? '',
    );
    final imageUrlController = TextEditingController(text: area?['image_url']);
    String? selectedSiteId = area?['site_id'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(area == null ? 'Crear Área' : 'Editar Área'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del área',
                    hintText: 'Ej: Sendero del Bosque Nativo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintText: 'Describe qué hay en esta área...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
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
                    child: CachedImageService.buildAreaImage(
                      imageUrl: imageUrlController.text,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: selectedSiteId,
                  decoration: const InputDecoration(
                    labelText: 'Sitio',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sin sitio asignado'),
                    ),
                    ..._sites.map(
                      (site) => DropdownMenuItem(
                        value: site['id'],
                        child: Text('${site['name']} (${site['region']})'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedSiteId = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es obligatorio')),
                  );
                  return;
                }

                final data = {
                  'name': nameController.text,
                  'description': descriptionController.text,
                  'image_url': imageUrlController.text.isEmpty
                      ? null
                      : imageUrlController.text,
                  'site_id': selectedSiteId,
                };

                try {
                  if (area == null) {
                    // Crear
                    await SupabaseService.client.from('areas').insert(data);
                  } else {
                    // Actualizar
                    await SupabaseService.client
                        .from('areas')
                        .update(data)
                        .eq('id', area['id']);
                  }

                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: Text(area == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadAreas();
    }
  }

  Future<void> _confirmDeleteArea(String areaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text(
          '¿Estás seguro de eliminar esta área?\nEsta acción no se puede deshacer.',
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
        await SupabaseService.client.from('areas').delete().eq('id', areaId);
        _loadAreas();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Área eliminada')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error eliminando área: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Áreas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAreas,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtro por sitio
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String?>(
              initialValue: _selectedSiteFilter,
              decoration: const InputDecoration(
                labelText: 'Filtrar por sitio',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.filter_list),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todos los sitios'),
                ),
                ..._sites.map(
                  (site) => DropdownMenuItem(
                    value: site['id'],
                    child: Text('${site['name']} (${site['region']})'),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedSiteFilter = value);
                _loadAreas();
              },
            ),
          ),

          // Lista de áreas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _areas.isEmpty
                ? const Center(
                    child: Text(
                      'No hay áreas creadas',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _areas.length,
                    itemBuilder: (context, index) {
                      final area = _areas[index];
                      final siteName = area['sites'] != null
                          ? '${area['sites']['name']} (${area['sites']['region']})'
                          : 'Sin sitio';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Icon(
                              Icons.map_outlined,
                              color: Colors.green.shade700,
                            ),
                          ),
                          title: Text(
                            area['name'] ?? 'Sin nombre',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (area['description'] != null &&
                                  area['description'].toString().isNotEmpty)
                                Text(
                                  area['description'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      siteName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            icon: const Icon(Icons.more_vert),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Eliminar'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showAreaDialog(area: area);
                              } else if (value == 'delete') {
                                _confirmDeleteArea(area['id']);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAreaDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Área'),
      ),
    );
  }
}
