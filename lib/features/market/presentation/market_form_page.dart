import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:angostura_appv1/core/services/supabase_service.dart';

class MarketFormPage extends StatefulWidget {
  const MarketFormPage({super.key});

  @override
  State<MarketFormPage> createState() => _MarketFormPageState();
}

class _MarketFormPageState extends State<MarketFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _locationController = TextEditingController();
  // final _verificationCodeController = TextEditingController(); // Para verificación futura
  final _picker = ImagePicker();

  bool _isLoading = false;
  // VERIFICACIÓN TELEFÓNICA - FUNCIONALIDAD FUTURA
  // bool _isVerified = false;
  // bool _showVerificationSection = false;
  String? _mainImagePath;
  String? _profileImagePath;
  // String? _generatedCode;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _locationController.dispose();
    // _verificationCodeController.dispose(); // Para verificación futura
    super.dispose();
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

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? mainImageUrl;
      String? profileImageUrl;

      // Subir imagen principal si existe
      if (_mainImagePath != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'main_$timestamp.jpg';
        mainImageUrl = await SupabaseService.uploadMarketImage(
          _mainImagePath!,
          fileName,
        );
      }

      // Subir imagen de perfil si existe
      if (_profileImagePath != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'profile_$timestamp.jpg';
        profileImageUrl = await SupabaseService.uploadMarketImage(
          _profileImagePath!,
          fileName,
        );
      }

      await SupabaseService.insertMarketItem(
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
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Emprendedor creado y verificado correctamente'),
          backgroundColor: Colors.green,
        ),
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

  // ========== MÉTODOS DE VERIFICACIÓN TELEFÓNICA - FUNCIONALIDAD FUTURA ==========
  // Descomenta estos métodos para habilitar verificación por SMS

  /*
  Future<void> _sendVerificationCode() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un número de teléfono')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generar código de 6 dígitos localmente
      final random = Random();
      final code = (100000 + random.nextInt(900000)).toString();
      
      setState(() {
        _generatedCode = code;
      });

      if (!mounted) return;

      // En producción, aquí se enviaría el SMS al número _phoneController.text
      // Por ahora mostrar el código en un diálogo
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código de verificación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SMS enviado a:',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              Text(
                _phoneController.text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Código (simulado):',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa este código abajo',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar código: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  */

  /*
  void _verifyCode() {
    if (_verificationCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el código de verificación')),
      );
      return;
    }

    if (_generatedCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero envía el código')),
      );
      return;
    }

    // Verificar que el código coincida
    if (_verificationCodeController.text.trim() == _generatedCode) {
      setState(() {
        _isVerified = true;
        _showVerificationSection = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Teléfono verificado correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Código incorrecto, intenta nuevamente'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }  */
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo emprendedor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Nombre o título *',
                  hintText: 'Ej: Artesanías María',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  if (value.trim().length < 3) {
                    return 'Mínimo 3 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Describe el emprendimiento o producto',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Imagen Principal
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.image, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Imagen Principal',
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
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_circle, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Imagen de Perfil (Circular)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_profileImagePath != null)
                        Center(
                          child: Stack(
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
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _pickProfileImage,
                          icon: const Icon(Icons.add_a_photo),
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

              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Rubro / Categoría',
                  hintText: 'Ej: Artesanía, Gastronomía, Turismo',
                ),
              ),
              const SizedBox(height: 12),
              // TELÉFONO
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (máx 12 dígitos)',
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
                    _phoneController.text = digitsOnly;
                    _phoneController.selection = TextSelection.fromPosition(
                      TextPosition(offset: digitsOnly.length),
                    );
                  }
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

              // ========== VERIFICACIÓN TELEFÓNICA - FUNCIONALIDAD FUTURA ==========
              // Descomenta este bloque para habilitar verificación por SMS:
              /*
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: /* campo de teléfono arriba */),
                  const SizedBox(width: 12),
                  if (!_isVerified && _phoneController.text.replaceAll(RegExp(r'\D'), '').length >= 8)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _showVerificationSection = !_showVerificationSection),
                        icon: Icon(_showVerificationSection ? Icons.keyboard_arrow_up : Icons.verified_user),
                        label: Text(_showVerificationSection ? 'Ocultar' : 'Verificar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
              if (_showVerificationSection && !_isVerified)
                Container(
                  // Sección azul con campo de código y botones
                  // Ver métodos: _sendVerificationCode() y _verifyCode()
                ),
              */
              // =====================================================================
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  hintText: 'Ej: Av. Principal 123, Angostura',
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Otro Contacto (Email, WhatsApp, etc)',
                  hintText: 'Ej: contacto@example.com',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Ubicación / Sector',
                  hintText: 'Ej: Sector Mirador, Santa Bárbara',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
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
                      : const Text('Guardar emprendedor'),
                ),
              ),

              // NOTA: Para requerir verificación antes de guardar,
              // cambia: onPressed: _isLoading ? null : _saveProduct,
              // por: onPressed: (_isLoading || !_isVerified) ? null : _saveProduct,
            ],
          ),
        ),
      ),
    );
  }
}
