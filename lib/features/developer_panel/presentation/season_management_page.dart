import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

/// CAP 8 - Season Management
/// Gestión de temporadas activas
class SeasonManagementPage extends ConsumerStatefulWidget {
  const SeasonManagementPage({super.key});

  @override
  ConsumerState<SeasonManagementPage> createState() =>
      _SeasonManagementPageState();
}

class _SeasonManagementPageState extends ConsumerState<SeasonManagementPage> {
  List<Map<String, dynamic>> _seasons = [];
  bool _isLoading = true;
  String? _currentSeasonId;

  @override
  void initState() {
    super.initState();
    _loadSeasons();
  }

  Future<void> _loadSeasons() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client
          .from('seasons')
          .select('*')
          .order('start_date', ascending: false);

      setState(() {
        _seasons = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      // Determinar temporada actual por fechas
      final now = DateTime.now();
      for (final season in _seasons) {
        final startDate = DateTime.parse(season['start_date']);
        final endDate = DateTime.parse(season['end_date']);
        if (now.isAfter(startDate) && now.isBefore(endDate)) {
          setState(() => _currentSeasonId = season['id']);
          break;
        }
      }
    } catch (e) {
      debugPrint('❌ Error cargando temporadas: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showCreateEditSeasonDialog([
    Map<String, dynamic>? season,
  ]) async {
    final isEdit = season != null;
    final nameController = TextEditingController(text: season?['name'] ?? '');
    final descriptionController = TextEditingController(
      text: season?['description'] ?? '',
    );
    DateTime? startDate = season != null && season['start_date'] != null
        ? DateTime.parse(season['start_date'])
        : null;
    DateTime? endDate = season != null && season['end_date'] != null
        ? DateTime.parse(season['end_date'])
        : null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Editar Temporada' : 'Crear Nueva Temporada'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre (ej: verano, invierno)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text(
                    startDate == null
                        ? 'Fecha de inicio'
                        : 'Inicio: ${startDate!.toLocal().toString().split(' ')[0]}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                ),
                ListTile(
                  title: Text(
                    endDate == null
                        ? 'Fecha de fin'
                        : 'Fin: ${endDate!.toLocal().toString().split(' ')[0]}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: startDate ?? DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => endDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    startDate == null ||
                    endDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Complete todos los campos')),
                  );
                  return;
                }

                try {
                  final data = {
                    'name': nameController.text,
                    'description': descriptionController.text.isEmpty
                        ? null
                        : descriptionController.text,
                    'start_date': startDate!.toIso8601String(),
                    'end_date': endDate!.toIso8601String(),
                  };

                  if (isEdit) {
                    await SupabaseService.client
                        .from('seasons')
                        .update(data)
                        .eq('id', season['id'].toString());
                  } else {
                    await SupabaseService.client.from('seasons').insert(data);
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? '✅ Temporada actualizada'
                              : '✅ Temporada creada',
                        ),
                      ),
                    );
                    _loadSeasons();
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

  Future<void> _deleteSeason(String seasonId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Temporada'),
        content: const Text(
          '¿Está seguro? Esto eliminará todas las cartas asociadas.',
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
        await SupabaseService.client
            .from('seasons')
            .delete()
            .eq('id', seasonId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Temporada eliminada')),
          );
          _loadSeasons();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Temporadas'),
        backgroundColor: Colors.orange,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateEditSeasonDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Temporada'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _seasons.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay temporadas',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea la primera temporada para empezar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _seasons.length,
              itemBuilder: (context, index) {
                final season = _seasons[index];
                final isActive = season['id'] == _currentSeasonId;
                final startDate = DateTime.parse(
                  season['start_date'],
                ).toLocal();
                final endDate = DateTime.parse(season['end_date']).toLocal();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: isActive ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isActive
                        ? const BorderSide(color: Colors.orange, width: 2)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: isActive ? Colors.orange : Colors.grey,
                      child: Icon(
                        isActive ? Icons.star : Icons.calendar_today,
                        color: Colors.white,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          season['name'] ?? 'Sin nombre',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'ACTIVA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (season['description'] != null) ...[
                          const SizedBox(height: 4),
                          Text(season['description']),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '📅 ${startDate.toString().split(' ')[0]} → ${endDate.toString().split(' ')[0]}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${season['id']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: const [
                              Icon(Icons.edit, color: Colors.blue, size: 20),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: const [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Eliminar'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          // Crear copia explícita del Map para evitar null issues
                          final seasonData = Map<String, dynamic>.from(season);
                          _showCreateEditSeasonDialog(seasonData);
                        } else if (value == 'delete') {
                          _deleteSeason(season['id'].toString());
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
