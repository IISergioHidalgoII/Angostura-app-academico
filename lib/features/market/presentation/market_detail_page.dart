import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'market_edit_page.dart';
import '../../../core/services/supabase_service.dart';

class MarketDetailPage extends StatelessWidget {
  final Map<String, dynamic> marketItem;

  const MarketDetailPage({super.key, required this.marketItem});

  Future<void> _handleContact(BuildContext context) async {
    final phoneNumber = marketItem['phone_number']?.toString().trim();

    if (phoneNumber == null || phoneNumber.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay teléfono de contacto disponible'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Limpiar y preparar número de teléfono
    final cleanNumber = _cleanPhoneNumber(phoneNumber);
    final uri = Uri.parse('tel:$cleanNumber');
    const errorMessage = 'No se pudo abrir el marcador telefónico';

    // Intentar abrir
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _cleanPhoneNumber(String phone) {
    // Remover todo excepto dígitos y el signo +
    return phone.replaceAll(RegExp(r'[^\d\+]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = marketItem['is_active'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Emprendedor'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MarketEditPage(marketItem: marketItem),
                ),
              );
              if (result == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de portada (si existe)
            if (marketItem['image_url'] != null &&
                marketItem['image_url'].toString().isNotEmpty)
              Container(
                width: double.infinity,
                height: 250,
                color: Colors.grey.shade200,
                child: Image.network(
                  marketItem['image_url'],
                  fit: BoxFit.cover,
                  cacheHeight: 500,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _buildHeaderPlaceholder();
                  },
                ),
              )
            else
              _buildHeaderPlaceholder(),

            // Header con gradiente
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (marketItem['category'] != null &&
                      marketItem['category'].toString().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        marketItem['category'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    marketItem['title'] ?? 'Sin título',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        isVerified ? Icons.verified : Icons.error_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isVerified ? 'Verificado' : 'Sin verificar',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Contenido principal
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descripción
                  if (marketItem['description'] != null &&
                      marketItem['description'].toString().isNotEmpty) ...[
                    const Text(
                      'Descripción',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      marketItem['description'],
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF666666),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Ubicación
                  if (marketItem['location_label'] != null &&
                      marketItem['location_label'].toString().isNotEmpty) ...[
                    _buildInfoSection(
                      icon: Icons.place,
                      title: 'Ubicación',
                      content: marketItem['location_label'],
                      color: Colors.red,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Teléfono
                  if (marketItem['phone_number'] != null &&
                      marketItem['phone_number'].toString().isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoSection(
                            icon: Icons.phone,
                            title: 'Teléfono',
                            content: marketItem['phone_number'],
                            color: Colors.green,
                          ),
                        ),
                        if (marketItem['is_verified'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Verificado',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Dirección
                  if (marketItem['address'] != null &&
                      marketItem['address'].toString().isNotEmpty) ...[
                    _buildInfoSection(
                      icon: Icons.location_on,
                      title: 'Dirección',
                      content: marketItem['address'],
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Otro contacto
                  if (marketItem['contact_info'] != null &&
                      marketItem['contact_info'].toString().isNotEmpty) ...[
                    _buildInfoSection(
                      icon: Icons.email,
                      title: 'Email/Otro Contacto',
                      content: marketItem['contact_info'],
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Sección de productos
                  _buildProductsSection(),

                  const SizedBox(height: 24),

                  // Botón de acción
                  if (marketItem['phone_number'] != null &&
                      marketItem['phone_number'].toString().isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleContact(context),
                        icon: const Icon(Icons.phone, size: 24),
                        label: const Text(
                          'Llamar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50).withValues(alpha: 0.3),
            const Color(0xFF2E7D32).withValues(alpha: 0.3),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.store, size: 80, color: Colors.white70),
      ),
    );
  }

  Widget _buildProductsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.getProductItemsByMarketId(marketItem['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Productos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          );
        }

        final productsList = snapshot.data ?? [];

        if (productsList.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Productos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sin productos disponibles',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Mostrar lista de productos (máximo 6)
        final limitedProducts = productsList.take(6).toList();
        final hasMoreProducts = productsList.length > 6;
        final additionalCount = productsList.length - 6;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Productos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 16),
            ...limitedProducts.map((product) {
              final name = product['name']?.toString() ?? 'Sin nombre';
              final description = product['description']?.toString() ?? '';
              final imageUrl = product['image_url']?.toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen del producto (opcional)
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 12),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade200,
                          ),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 120,
                            cacheHeight: 120,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey.shade400,
                                  size: 24,
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.green.shade700,
                            size: 28,
                          ),
                        ),
                      // Info del producto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Mostrar contador si hay más de 6 productos
            if (hasMoreProducts) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+$additionalCount productos más',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
