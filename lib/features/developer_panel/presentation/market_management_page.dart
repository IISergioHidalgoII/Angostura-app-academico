import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cached_image_service.dart';

/// CAP 8 - Market Management
/// CRUD de items del mercado con products (JSONB)
/// Max 6 productos por item
class MarketManagementPage extends ConsumerStatefulWidget {
  const MarketManagementPage({super.key});

  @override
  ConsumerState<MarketManagementPage> createState() =>
      _MarketManagementPageState();
}

class _MarketManagementPageState extends ConsumerState<MarketManagementPage> {
  List<Map<String, dynamic>> _marketItems = [];
  List<Map<String, dynamic>> _filteredMarketItems = [];
  bool _isLoading = true;
  bool _showInactive = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMarketItems();
    _searchController.addListener(_filterMarketItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMarketItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMarketItems = _marketItems.where((item) {
        final title = item['title']?.toString().toLowerCase() ?? '';
        final description = item['description']?.toString().toLowerCase() ?? '';
        return title.contains(query) || description.contains(query);
      }).toList();
    });
  }

  Future<void> _loadMarketItems() async {
    setState(() => _isLoading = true);
    try {
      final query = SupabaseService.client.from('market_items').select('*');

      // Si NO queremos mostrar inactivos, filtramos por is_active = true
      final response = _showInactive
          ? await query.order('title', ascending: true)
          : await query.eq('is_active', true).order('title', ascending: true);

      setState(() {
        _marketItems = List<Map<String, dynamic>>.from(response);
        _filteredMarketItems = _marketItems;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error cargando items del mercado: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showCreateEditDialog([Map<String, dynamic>? item]) async {
    final isEdit = item != null;
    final titleController = TextEditingController(text: item?['title']);
    final descriptionController = TextEditingController(
      text: item?['description'],
    );
    final phoneController = TextEditingController(text: item?['phone_number']);
    final addressController = TextEditingController(text: item?['address']);
    final imageUrlController = TextEditingController(text: item?['image_url']);
    final profileImageUrlController = TextEditingController(
      text: item?['profile_image_url'],
    );
    final picker = ImagePicker();
    String? mainImagePath;
    String? profileImagePath;
    Map<int, String> productImagePaths = {};

    String selectedCategory =
        (item?['category'] != null &&
            ['gastronomia', 'artesania', 'turismo'].contains(item!['category']))
        ? item['category']
        : 'gastronomia';

    // Cargar productos desde products_items si estamos editando
    List<Map<String, dynamic>> products = [];
    if (isEdit) {
      try {
        products = await SupabaseService.getProductItemsByMarketId(item['id']);
      } catch (e) {
        debugPrint('Error loading products: $e');
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Editar Item del Mercado' : 'Nuevo Item'),
          content: SingleChildScrollView(
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
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de Contacto (máx 12 dígitos)',
                    border: OutlineInputBorder(),
                    hintText: '56912345678',
                    prefixIcon: Icon(Icons.phone),
                    helperText: 'Ej: 56912345678 (solo números, 8-12 dígitos)',
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 12,
                  onChanged: (value) {
                    // Solo números
                    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                    if (digitsOnly != value) {
                      phoneController.text = digitsOnly;
                      phoneController.selection = TextSelection.fromPosition(
                        TextPosition(offset: digitsOnly.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Av. Principal 123, Angostura',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL de Imagen Principal',
                          border: OutlineInputBorder(),
                          hintText: 'https://ejemplo.com/imagen.jpg',
                          prefixIcon: Icon(Icons.image),
                        ),
                        onChanged: (value) {
                          setDialogState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.add_photo_alternate),
                      tooltip: 'Seleccionar desde galería',
                      onPressed: () async {
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1920,
                          maxHeight: 1080,
                          imageQuality: 85,
                        );
                        if (image != null) {
                          setDialogState(() {
                            mainImagePath = image.path;
                            imageUrlController.text =
                                'archivo_seleccionado.jpg';
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (mainImagePath != null) ...[
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(mainImagePath!),
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setDialogState(() {
                              mainImagePath = null;
                              imageUrlController.clear();
                            });
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (imageUrlController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedImageService.buildMarketItemImage(
                      imageUrl: imageUrlController.text,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: profileImageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL de Imagen de Perfil (Circular)',
                          border: OutlineInputBorder(),
                          hintText: 'https://ejemplo.com/perfil.jpg',
                          prefixIcon: Icon(Icons.account_circle),
                        ),
                        onChanged: (value) {
                          setDialogState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.add_a_photo),
                      tooltip: 'Seleccionar desde galería',
                      onPressed: () async {
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 500,
                          maxHeight: 500,
                          imageQuality: 85,
                        );
                        if (image != null) {
                          setDialogState(() {
                            profileImagePath = image.path;
                            profileImageUrlController.text =
                                'archivo_seleccionado.jpg';
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (profileImagePath != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Stack(
                      children: [
                        ClipOval(
                          child: Image.file(
                            File(profileImagePath!),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              setDialogState(() {
                                profileImagePath = null;
                                profileImageUrlController.clear();
                              });
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (profileImageUrlController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: ClipOval(
                      child: CachedImageService.buildMarketItemImage(
                        imageUrl: profileImageUrlController.text,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Categoría de Emprendimiento',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'gastronomia',
                      child: Text('🍽️ Gastronomía'),
                    ),
                    DropdownMenuItem(
                      value: 'artesania',
                      child: Text('🎨 Artesanía'),
                    ),
                    DropdownMenuItem(
                      value: 'turismo',
                      child: Text('🏞️ Turismo'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedCategory = value!);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Productos (${products.length}/6)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (products.length < 6)
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        color: Colors.green,
                        onPressed: () {
                          setDialogState(() {
                            products.add({
                              'name': '',
                              'description': '',
                              'image_url': null,
                            });
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(products.length, (index) {
                  final product = products[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          if (product['image_url'] != null &&
                              product['image_url'].toString().isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedImageService.buildMarketItemImage(
                                imageUrl: product['image_url'],
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            const Icon(Icons.shopping_bag, size: 40),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name']?.toString().isNotEmpty == true
                                      ? product['name']
                                      : 'Sin nombre',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (product['description'] != null &&
                                    product['description']
                                        .toString()
                                        .isNotEmpty)
                                  Text(
                                    product['description'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () async {
                              await _showProductEditDialog(context, product, (
                                updated,
                              ) {
                                setDialogState(() {
                                  products[index] = updated;
                                });
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                products.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
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
                if (titleController.text.isEmpty ||
                    descriptionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Complete el título y la descripción'),
                    ),
                  );
                  return;
                }

                try {
                  String? finalMainImageUrl = imageUrlController.text.isEmpty
                      ? null
                      : imageUrlController.text;
                  String? finalProfileImageUrl =
                      profileImageUrlController.text.isEmpty
                      ? null
                      : profileImageUrlController.text;

                  // Subir imagen principal si se seleccionó una
                  if (mainImagePath != null) {
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    final fileName = 'main_$timestamp.jpg';
                    finalMainImageUrl = await SupabaseService.uploadMarketImage(
                      mainImagePath!,
                      fileName,
                    );
                  }

                  // Subir imagen de perfil si se seleccionó una
                  if (profileImagePath != null) {
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    final fileName = 'profile_$timestamp.jpg';
                    finalProfileImageUrl =
                        await SupabaseService.uploadMarketImage(
                          profileImagePath!,
                          fileName,
                        );
                  }

                  // Guardar o actualizar market_item
                  String marketItemId;
                  if (isEdit) {
                    marketItemId = item['id'];
                    await SupabaseService.updateMarketItem(
                      id: marketItemId,
                      title: titleController.text,
                      description: descriptionController.text,
                      category: selectedCategory,
                      imageUrl: finalMainImageUrl,
                      profileImageUrl: finalProfileImageUrl,
                      phoneNumber: phoneController.text.trim().isEmpty
                          ? null
                          : phoneController.text.trim(),
                      address: addressController.text.trim().isEmpty
                          ? null
                          : addressController.text.trim(),
                    );

                    // Eliminar productos existentes
                    await SupabaseService.deleteAllProductItemsByMarketId(
                      marketItemId,
                    );
                  } else {
                    marketItemId = await SupabaseService.insertMarketItem(
                      title: titleController.text,
                      description: descriptionController.text,
                      category: selectedCategory,
                      imageUrl: finalMainImageUrl,
                      profileImageUrl: finalProfileImageUrl,
                      phoneNumber: phoneController.text.trim().isEmpty
                          ? null
                          : phoneController.text.trim(),
                      address: addressController.text.trim().isEmpty
                          ? null
                          : addressController.text.trim(),
                    );
                  }

                  // Guardar productos en products_items
                  for (var i = 0; i < products.length; i++) {
                    final product = products[i];
                    String? productImageUrl = product['image_url'];

                    // Subir imagen del producto si se seleccionó una
                    if (productImagePaths.containsKey(i)) {
                      final timestamp = DateTime.now().millisecondsSinceEpoch;
                      final productName =
                          (product['name'] as String?)
                              ?.replaceAll(' ', '_')
                              .toLowerCase() ??
                          'product';
                      final fileName = 'product_${productName}_$timestamp.jpg';
                      productImageUrl = await SupabaseService.uploadMarketImage(
                        productImagePaths[i]!,
                        fileName,
                      );
                    }

                    await SupabaseService.insertProductItem(
                      marketItemId: marketItemId,
                      name: product['name'] ?? '',
                      description: product['description'],
                      imageUrl: productImageUrl,
                    );
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit ? '✅ Item actualizado' : '✅ Item creado',
                        ),
                      ),
                    );
                    _loadMarketItems();
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

  Future<void> _showProductEditDialog(
    BuildContext context,
    Map<String, dynamic> product,
    Function(Map<String, dynamic>) onUpdate,
  ) async {
    final nameController = TextEditingController(
      text: product['name']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: product['description']?.toString() ?? '',
    );
    final imageUrlController = TextEditingController(
      text: product['image_url']?.toString() ?? '',
    );

    final picker = ImagePicker();
    String? productImagePath;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Producto *',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Llavero artesanal',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción *',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Hecho a mano con madera local',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL de Imagen',
                          border: OutlineInputBorder(),
                          hintText: 'https://ejemplo.com/producto.jpg',
                          prefixIcon: Icon(Icons.image),
                        ),
                        onChanged: (value) {
                          setDialogState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.image),
                      tooltip: 'Seleccionar del dispositivo',
                      onPressed: () async {
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 800,
                          maxHeight: 800,
                          imageQuality: 85,
                        );
                        if (image != null) {
                          setDialogState(() {
                            productImagePath = image.path;
                            imageUrlController.text =
                                'archivo_seleccionado.jpg';
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (productImagePath != null) ...[
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(productImagePath!),
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            setDialogState(() {
                              productImagePath = null;
                              imageUrlController.clear();
                            });
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (imageUrlController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedImageService.buildMarketItemImage(
                      imageUrl: imageUrlController.text,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
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
                    descriptionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Complete el nombre y la descripción'),
                    ),
                  );
                  return;
                }

                String? finalImageUrl = imageUrlController.text.isEmpty
                    ? null
                    : imageUrlController.text;

                // Si seleccionó una imagen del dispositivo, subirla
                if (productImagePath != null) {
                  try {
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    final fileName =
                        'product_${nameController.text.replaceAll(' ', '_')}_$timestamp.jpg';
                    finalImageUrl = await SupabaseService.uploadMarketImage(
                      productImagePath!,
                      fileName,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al subir imagen: $e')),
                      );
                      return;
                    }
                  }
                }

                onUpdate({
                  'name': nameController.text,
                  'description': descriptionController.text,
                  'image_url': finalImageUrl,
                });

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleItemActive(Map<String, dynamic> item) async {
    final newState = !(item['is_active'] ?? true);
    try {
      await SupabaseService.client
          .from('market_items')
          .update({'is_active': newState})
          .eq('id', item['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newState ? '✅ Item activado' : '🔒 Item desactivado'),
          ),
        );
        _loadMarketItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Item'),
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
        await SupabaseService.client
            .from('market_items')
            .delete()
            .eq('id', itemId);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('✅ Item eliminado')));
          _loadMarketItems();
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
        title: const Text('Gestión del Mercado'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() => _showInactive = !_showInactive);
              _loadMarketItems();
            },
            tooltip: _showInactive ? 'Ocultar inactivos' : 'Mostrar inactivos',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Item'),
        backgroundColor: Colors.green,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Campo de búsqueda
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Buscar emprendimiento',
                      hintText: 'Nombre o descripción',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                // Lista
                Expanded(
                  child: _filteredMarketItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.store_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No se encontraron resultados'
                                    : 'No hay items en el mercado',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'Intenta con otros términos de búsqueda'
                                    : 'Crea el primer item para empezar',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredMarketItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredMarketItems[index];
                            final isActive = item['is_active'] ?? true;

                            // Parse products
                            List<dynamic> products = [];
                            if (item['products'] != null) {
                              try {
                                if (item['products'] is List) {
                                  products = item['products'];
                                } else if (item['products'] is String) {
                                  products = jsonDecode(item['products']);
                                }
                              } catch (e) {
                                debugPrint('Error parsing products: $e');
                              }
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: isActive ? 2 : 1,
                              color: isActive ? null : Colors.grey.shade100,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading:
                                    item['profile_image_url'] != null &&
                                        item['profile_image_url']
                                            .toString()
                                            .isNotEmpty
                                    ? ClipOval(
                                        child:
                                            CachedImageService.buildMarketItemImage(
                                              imageUrl:
                                                  item['profile_image_url'],
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                              itemId: item['id'],
                                            ),
                                      )
                                    : CircleAvatar(
                                        backgroundColor: isActive
                                            ? Colors.green
                                            : Colors.grey,
                                        child: const Icon(
                                          Icons.store,
                                          color: Colors.white,
                                        ),
                                      ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['title'] ?? 'Sin título',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          decoration: isActive
                                              ? null
                                              : TextDecoration.lineThrough,
                                          color: isActive
                                              ? null
                                              : Colors.grey[600],
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          'INACTIVO',
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
                                    if (item['description'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item['description'],
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          item['category'] == 'gastronomia'
                                              ? Icons.restaurant
                                              : item['category'] == 'artesania'
                                              ? Icons.palette
                                              : Icons.tour,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item['category'] == 'gastronomia'
                                              ? 'Gastronomía'
                                              : item['category'] == 'artesania'
                                              ? 'Artesanía'
                                              : 'Turismo',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '📦 ${products.length} producto(s)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        _showCreateEditDialog(item);
                                        break;
                                      case 'toggle':
                                        _toggleItemActive(item);
                                        break;
                                      case 'delete':
                                        _deleteItem(item['id']);
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
                                          Text(
                                            isActive ? 'Desactivar' : 'Activar',
                                          ),
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
