import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:angostura_appv1/core/services/supabase_service.dart';

class MarketEditPage extends StatefulWidget {
  final Map<String, dynamic> marketItem;

  const MarketEditPage({super.key, required this.marketItem});

  @override
  State<MarketEditPage> createState() => _MarketEditPageState();
}

class _MarketEditPageState extends State<MarketEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _locationController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _picker = ImagePicker();

  bool _isLoading = false;
  bool _isVerified = false;
  bool _showVerificationSection = false;
  String? _mainImagePath;
  String? _profileImagePath;
  String? _existingMainImageUrl;
  String? _existingProfileImageUrl;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadItemData();
  }

  void _loadItemData() {
    _titleController.text = widget.marketItem['title'] ?? '';
    _descriptionController.text = widget.marketItem['description'] ?? '';
    _categoryController.text = widget.marketItem['category'] ?? '';
    _phoneController.text = widget.marketItem['phone_number'] ?? '';
    _addressController.text = widget.marketItem['address'] ?? '';
    _contactController.text = widget.marketItem['contact_info'] ?? '';
    _locationController.text = widget.marketItem['location_label'] ?? '';
    _existingMainImageUrl = widget.marketItem['image_url'];
    _existingProfileImageUrl = widget.marketItem['profile_image_url'];
    _isVerified = widget.marketItem['is_verified'] ?? false;

    // Cargar productos existentes
    final productsData = widget.marketItem['products'];
    if (productsData != null) {
      if (productsData is List) {
        _products = List<Map<String, dynamic>>.from(
          productsData.map((p) => Map<String, dynamic>.from(p)),
        );
      }
    }
  }

  @override
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _locationController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un número de teléfono')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final code = await SupabaseService.generateVerificationCode(
        widget.marketItem['id'],
      );

      if (!mounted) return;

      // En producción, aquí se enviaría el SMS
      // Por ahora mostrar el código en un diálogo
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código de verificación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Código enviado (simulado):',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa este código en el campo de verificación',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al enviar código: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickMainImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _mainImagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seleccionando imagen: $e')),
        );
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seleccionando imagen: $e')),
        );
      }
    }
  }

  Future<void> _pickProductImage(int index) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _products[index]['image_path'] = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seleccionando imagen: $e')),
        );
      }
    }
  }

  void _addProduct() {
    setState(() {
      _products.add({
        'name': '',
        'description': '',
        'image_url': null,
        'image_path': null,
      });
    });
  }

  void _removeProduct(int index) {
    setState(() {
      _products.removeAt(index);
    });
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? mainImageUrl = _existingMainImageUrl;
      String? profileImageUrl = _existingProfileImageUrl;

      // Subir nueva imagen principal si se seleccionó una
      if (_mainImagePath != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'main_$timestamp.jpg';
        mainImageUrl = await SupabaseService.uploadMarketImage(
          _mainImagePath!,
          fileName,
        );
      }

      // Subir nueva imagen de perfil si se seleccionó una
      if (_profileImagePath != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'profile_$timestamp.jpg';
        profileImageUrl = await SupabaseService.uploadMarketImage(
          _profileImagePath!,
          fileName,
        );
      }

      // Procesar productos y subir imágenes si es necesario
      final List<Map<String, dynamic>> processedProducts = [];
      for (var product in _products) {
        String? productImageUrl = product['image_url'];

        // Si hay una nueva imagen seleccionada, subirla
        if (product['image_path'] != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final productName =
              (product['name'] as String?)
                  ?.replaceAll(' ', '_')
                  .toLowerCase() ??
              'product';
          final fileName = 'product_${productName}_$timestamp.jpg';
          productImageUrl = await SupabaseService.uploadMarketImage(
            product['image_path'],
            fileName,
          );
        }

        processedProducts.add({
          'name': product['name'],
          'description': product['description'],
          'image_url': productImageUrl,
        });
      }

      await SupabaseService.updateMarketItem(
        id: widget.marketItem['id'],
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        imageUrl: mainImageUrl,
        profileImageUrl: profileImageUrl,
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        contactInfo: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        locationLabel: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        verificationCode: _verificationCodeController.text.trim().isEmpty
            ? null
            : _verificationCodeController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emprendedor actualizado correctamente')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Editar Item del Mercado'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Título
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El título es obligatorio';
                }
                if (value.trim().length < 3) {
                  return 'Mínimo 3 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Descripción
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Imagen Principal
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.image, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'URL de Imagen Principal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_mainImagePath != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_mainImagePath!),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _mainImagePath = null;
                                });
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (_existingMainImageUrl != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _existingMainImageUrl!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 50),
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: ElevatedButton.icon(
                              onPressed: _pickMainImage,
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Cambiar'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _pickMainImage,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Seleccionar imagen'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Imagen de Perfil (Circular)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_circle, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'URL de Imagen de Perfil (Circular)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: _profileImagePath != null
                          ? Stack(
                              children: [
                                ClipOval(
                                  child: Image.file(
                                    File(_profileImagePath!),
                                    height: 120,
                                    width: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _profileImagePath = null;
                                      });
                                    },
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _existingProfileImageUrl != null
                          ? Stack(
                              children: [
                                ClipOval(
                                  child: Image.network(
                                    _existingProfileImageUrl!,
                                    height: 120,
                                    width: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 120,
                                        width: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey.shade200,
                                        ),
                                        child: const Icon(
                                          Icons.person_outline,
                                          size: 50,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: FloatingActionButton.small(
                                    onPressed: _pickProfileImage,
                                    child: const Icon(Icons.edit, size: 16),
                                  ),
                                ),
                              ],
                            )
                          : OutlinedButton.icon(
                              onPressed: _pickProfileImage,
                              icon: const Icon(Icons.add_a_photo),
                              label: const Text('Seleccionar imagen'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Categoría
            DropdownButtonFormField<String>(
              initialValue: _categoryController.text.isEmpty
                  ? null
                  : _categoryController.text,
              decoration: const InputDecoration(
                labelText: 'Categoría de Emprendimiento',
                prefixIcon: Icon(Icons.category),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Artesanía',
                  child: Text('🎨 Artesanía'),
                ),
                DropdownMenuItem(
                  value: 'Gastronomía',
                  child: Text('🍴 Gastronomía'),
                ),
                DropdownMenuItem(value: 'Turismo', child: Text('🏔️ Turismo')),
                DropdownMenuItem(
                  value: 'Servicios',
                  child: Text('🛠️ Servicios'),
                ),
                DropdownMenuItem(value: 'Otros', child: Text('📦 Otros')),
              ],
              onChanged: (value) {
                _categoryController.text = value ?? '';
              },
            ),
            const SizedBox(height: 16),

            // Productos Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Productos (${_products.length}/6)',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton.filled(
                          onPressed: _products.length < 6 ? _addProduct : null,
                          icon: const Icon(Icons.add),
                          tooltip: 'Agregar producto',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_products.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('No hay productos agregados'),
                        ),
                      )
                    else
                      ..._products.asMap().entries.map((entry) {
                        final index = entry.key;
                        final product = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.shopping_bag,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Producto ${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _removeProduct(index),
                                      tooltip: 'Eliminar',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: product['name'],
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre (llave)',
                                    hintText: 'Ej: ppan',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  onChanged: (value) {
                                    product['name'] = value;
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: product['description'],
                                  decoration: const InputDecoration(
                                    labelText: 'Descripción',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  maxLines: 2,
                                  onChanged: (value) {
                                    product['description'] = value;
                                  },
                                ),
                                const SizedBox(height: 8),
                                // Imagen del producto
                                if (product['image_path'] != null)
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(product['image_path']),
                                          height: 100,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              product['image_path'] = null;
                                            });
                                          },
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            padding: const EdgeInsets.all(4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else if (product['image_url'] != null)
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          product['image_url'],
                                          height: 100,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  height: 100,
                                                  color: Colors.grey.shade200,
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                    ),
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 4,
                                        right: 4,
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _pickProductImage(index),
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 14,
                                          ),
                                          label: const Text('Cambiar'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  OutlinedButton.icon(
                                    onPressed: () => _pickProductImage(index),
                                    icon: const Icon(Icons.add_photo_alternate),
                                    label: const Text('Agregar imagen'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(
                                        double.infinity,
                                        40,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Teléfono con botón de verificar al lado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Teléfono (máx 12 dígitos)',
                      hintText: '56912345678',
                      prefixIcon: const Icon(Icons.phone),
                      suffixIcon: _isVerified
                          ? const Icon(Icons.verified, color: Colors.green)
                          : null,
                      helperText: _isVerified ? '✓ Verificado' : null,
                      helperStyle: const TextStyle(color: Colors.green),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 12,
                    onChanged: (value) {
                      // Solo números
                      final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                      if (digitsOnly != value) {
                        _phoneController.text = digitsOnly;
                        _phoneController.selection = TextSelection.fromPosition(
                          TextPosition(offset: digitsOnly.length),
                        );
                      }
                      setState(() {}); // Actualizar botón
                    },
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                        if (digitsOnly.length < 8) {
                          return 'Mínimo 8 dígitos';
                        }
                        if (digitsOnly.length > 12) {
                          return 'Máximo 12 dígitos';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Botón Verificar al lado
                if (!_isVerified &&
                    _phoneController.text
                            .replaceAll(RegExp(r'\D'), '')
                            .length >=
                        8)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showVerificationSection = !_showVerificationSection;
                        });
                      },
                      icon: Icon(
                        _showVerificationSection
                            ? Icons.keyboard_arrow_up
                            : Icons.verified_user,
                      ),
                      label: Text(
                        _showVerificationSection ? 'Ocultar' : 'Verificar',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Sección de verificación desplegable
            if (_showVerificationSection && !_isVerified) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Verificación por SMS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enviaremos un código de 6 dígitos al número ${_phoneController.text}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _sendVerificationCode,
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar código SMS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _verificationCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Código de verificación',
                        hintText: 'Ingresa los 6 dígitos',
                        prefixIcon: Icon(Icons.pin),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onChanged: (value) {
                        // Solo números
                        final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                        if (digitsOnly != value) {
                          _verificationCodeController.text = digitsOnly;
                          _verificationCodeController.selection =
                              TextSelection.fromPosition(
                                TextPosition(offset: digitsOnly.length),
                              );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 8),

            // Dirección
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                hintText: 'Ej: Av. Principal 123, Angostura',
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Otro contacto
            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Otro Contacto (Email, WhatsApp, etc)',
                hintText: 'Ej: contacto@example.com',
                prefixIcon: Icon(Icons.alternate_email),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Ubicación
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Ubicación / Sector',
                hintText: 'Ej: Sector Mirador, Santa Bárbara',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
