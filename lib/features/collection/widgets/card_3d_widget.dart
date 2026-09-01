import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/species_card.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/season_theme.dart';

/// Widget de carta 3D con animación de volteo
/// Muestra el frente con imagen y rareza, reverso con información detallada
class Card3DWidget extends StatefulWidget {
  final SpeciesCard species;
  final VoidCallback? onTap;
  final bool compact; // Si es true, muestra versión reducida para grid

  const Card3DWidget({
    super.key,
    required this.species,
    this.onTap,
    this.compact = false,
  });

  @override
  State<Card3DWidget> createState() => _Card3DWidgetState();
}

class _Card3DWidgetState extends State<Card3DWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentRotation = 0.0; // Ángulo actual en radianes
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Inicializar animación con valores por defecto
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard({bool toRight = true}) {
    if (_isAnimating) return; // Prevenir animaciones simultáneas

    setState(() {
      _isAnimating = true;
    });

    // Calcular nuevo ángulo objetivo
    final targetRotation = _currentRotation + (toRight ? math.pi : -math.pi);

    // Crear nueva animación desde ángulo actual al objetivo
    _animation = Tween<double>(
      begin: _currentRotation,
      end: targetRotation,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.reset();
    _controller.forward().then((_) {
      _currentRotation = targetRotation;
      setState(() {
        _isAnimating = false;
      });
    });
  }

  /// Construye el widget de imagen con soporte para URLs remotas y assets locales
  Widget _buildImage({required BoxFit fit, double? height, double? width}) {
    // Priorizar imageUrl de la BD si está disponible
    if (widget.species.imageUrl != null &&
        widget.species.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.species.imageUrl!,
        cacheKey:
            'card_${widget.species.code}_${widget.species.imageUrl!.hashCode}',
        fit: fit,
        height: height,
        width: width,
        // Optimización de memoria: reducir tamaño en cache
        memCacheHeight: height != null ? (height * 2).toInt() : 600,
        memCacheWidth: width != null ? (width * 2).toInt() : 400,
        // Animaciones suaves sin superposición
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
        // Placeholder mientras carga
        placeholder: (context, url) => Container(
          height: height,
          width: width,
          color: widget.species.rarityColor.withOpacity(0.1),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.species.rarityColor,
            ),
          ),
        ),
        // Widget de error si falla la carga
        errorWidget: (context, url, error) => Container(
          height: height,
          width: width,
          color: widget.species.rarityColor.withOpacity(0.2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 48,
                color: widget.species.rarityColor,
              ),
              const SizedBox(height: 8),
              Text(
                'Error al cargar',
                style: TextStyle(
                  fontSize: 10,
                  color: widget.species.rarityColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Fallback a asset local si no hay URL
    return Image.asset(
      widget.species.imageAsset ?? 'assets/images/species/placeholder.png',
      fit: fit,
      height: height,
      width: width,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: height,
          width: width,
          color: widget.species.rarityColor.withOpacity(0.2),
          child: Icon(
            Icons.image_not_supported,
            size: 48,
            color: widget.species.rarityColor,
          ),
        );
      },
    );
  }

  /// Obtiene el color de fondo para la carta según la temporada
  Color _getCardBackground() {
    final season = widget.species.season;
    if (season != null && season.isNotEmpty) {
      final seasonColors = SeasonTheme.getColorsForSeason(season);
      return seasonColors.cardBackground; // Sin opacidad adicional
    }
    // Fallback a blanco si no hay temporada
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      // Versión compacta para grid de colección
      return _buildCompactCard();
    } else {
      // Versión completa con volteo 3D
      return _buildFullCard();
    }
  }

  Widget _buildCompactCard() {
    // Si está bloqueada, mostrar versión locked
    if (widget.species.locked) {
      return _buildLockedCard();
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          gradient: widget.species.rarityGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: widget.species.rarityColor.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 2),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen de la especie
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: _buildImage(fit: BoxFit.cover),
              ),
            ),
            // Info de la carta
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.species.commonName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge de rareza
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.species.rarityColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.species.rarityText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Badge de conservación (si aplica)
                        if (widget.species.threatLevel ==
                                ConservationStatus.amenazado ||
                            widget.species.threatLevel ==
                                ConservationStatus.extincion)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Color(
                                widget.species.threatLevel ==
                                        ConservationStatus.extincion
                                    ? ConservationStatus.dangerRed
                                    : ConservationStatus.warningYellow,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('⚠️', style: TextStyle(fontSize: 8)),
                                const SizedBox(width: 2),
                                Text(
                                  widget.species.threatLevel ==
                                          ConservationStatus.extincion
                                      ? 'Extinción'
                                      : 'Amenazado',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }

  Widget _buildFullCard() {
    return GestureDetector(
      onTap: () => _flipCard(toRight: true),
      onHorizontalDragEnd: (details) {
        // Detectar deslizamiento horizontal (swipe)
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity!.abs() > 300) {
            // Swipe detectado (velocidad > 300)
            // Swipe hacia la derecha = velocidad positiva
            // Swipe hacia la izquierda = velocidad negativa
            bool swipeToRight = details.primaryVelocity! > 0;
            _flipCard(toRight: swipeToRight);
          }
        }
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value;

          // Determinar qué lado mostrar basado en el ángulo
          // Normalizar el ángulo entre 0 y 2π para determinar el lado
          final normalizedAngle =
              (angle % (2 * math.pi) + (2 * math.pi)) % (2 * math.pi);
          final isFront =
              normalizedAngle < math.pi / 2 ||
              normalizedAngle > (3 * math.pi / 2);

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFront ? _buildFront() : _buildBack(),
          );
        },
      ),
    );
  }

  Widget _buildFront() {
    // Tamaño responsive: 40% más grande y adaptable a la pantalla
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.575).clamp(
      425.0,
      530.0,
    ); // Min 425, Max 530 (40% total)
    final cardHeight = cardWidth * 1.5; // Ratio 2:3

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: _getCardBackground(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 25,
            offset: const Offset(0, 12),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: widget.species.rarityColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Efecto de brillo
          if (widget.species.rarity == Rarity.epic ||
              widget.species.rarity == Rarity.legendary)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.3),
                      Colors.transparent,
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header con nombre
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getCardBackground(),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: widget.species.rarityColor,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  widget.species.commonName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Imagen de la especie flotante
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: widget.species.rarityColor.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: _buildImage(fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),

              // Footer con rareza
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getCardBackground(),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: widget.species.rarityColor,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.species.rarityColor,
                            widget.species.rarityColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: widget.species.rarityColor.withOpacity(0.6),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.species.rarityText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.refresh, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'Voltear',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Badge de rareza especial
          if (widget.species.rarity == Rarity.legendary)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Text(
                  '👑 LEGENDARIA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Badge de conservación (amenazado/extinción)
          if (widget.species.threatLevel == ConservationStatus.amenazado ||
              widget.species.threatLevel == ConservationStatus.extincion)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Color(
                    widget.species.threatLevel == ConservationStatus.extincion
                        ? ConservationStatus.dangerRed
                        : ConservationStatus.warningYellow,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(
                        widget.species.threatLevel ==
                                ConservationStatus.extincion
                            ? ConservationStatus.dangerRed
                            : ConservationStatus.warningYellow,
                      ).withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      widget.species.threatLevel == ConservationStatus.extincion
                          ? 'En Extinción'
                          : 'Amenazado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    // Tamaño responsive: 40% más grande y adaptable a la pantalla
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.575).clamp(
      425.0,
      530.0,
    ); // Min 425, Max 530 (40% total)
    final cardHeight = cardWidth * 1.5; // Ratio 2:3

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          gradient: widget.species.rarityGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 25,
              offset: const Offset(0, 12),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: widget.species.rarityColor.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 0),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header con nombre científico
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getCardBackground(),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: widget.species.rarityColor,
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    widget.species.scientificName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: widget.species.rarityColor,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.species.rarityColor,
                          widget.species.rarityColor.withOpacity(0.7),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.species.cardType == 'fauna'
                          ? Icons.pets
                          : Icons.eco,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // Contenido scrollable
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.species.description.isNotEmpty) ...[
                        _buildInfoSection(
                          '📖 Descripción',
                          widget.species.description,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (widget.species.habitat.isNotEmpty) ...[
                        _buildInfoSection(
                          '📊 Datos Técnicos',
                          widget
                              .species
                              .habitat, // habitat ahora contiene technical_data
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (widget.species.curiosities.isNotEmpty) ...[
                        _buildCuriositiesSection(),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _getCardBackground(),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: widget.species.rarityColor, width: 3),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'Volver al frente',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: widget.species.rarityColor,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            height: 1.6,
          ),
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }

  Widget _buildCuriositiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🎯 Curiosidades',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: widget.species.rarityColor,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.species.curiosities.first,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
            height: 1.6,
          ),
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }

  /// Widget para cartas bloqueadas (silueta + candado)
  Widget _buildLockedCard() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF424242), Color(0xFF212121)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Silueta de la imagen (oscurecida)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.black,
                  BlendMode.color,
                ),
                child: Opacity(
                  opacity: 0.15,
                  child: _buildImage(fit: BoxFit.cover),
                ),
              ),
            ),
          ),

          // Contenido central (candado + texto)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 48, color: Colors.white54),
                const SizedBox(height: 12),
                const Text(
                  '???',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'BLOQUEADA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Badge de rareza (visible pero oscuro)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Text(
                '???',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white38,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
