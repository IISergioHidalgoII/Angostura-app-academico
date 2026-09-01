import 'package:flutter/material.dart';

/// Modelo de datos para cada página del onboarding
class OnboardingPageData {
  final String icon;
  final String title;
  final String description;
  final Color color;

  OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

/// Onboarding simplificado de 3 páginas según requerimientos Eva03
/// Página 1: Reglas del parque
/// Página 2: Tips y consejos
/// Página 3: Bienvenida
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      icon: '📋',
      title: 'Reglas del Parque',
      description:
          'Respeta los senderos marcados y cuida la flora y fauna del humedal. '
          'No alimentes a los animales ni dejes basura. Mantén el silencio para '
          'no alterar el ecosistema. Sigue siempre las indicaciones del personal '
          'del parque y disfruta tu visita de forma responsable.',
      color: Color(0xFF2E7D32),
    ),
    OnboardingPageData(
      icon: '💡',
      title: 'Tips para tu Visita',
      description:
          'Lleva agua suficiente, protector solar y ropa cómoda para caminar. '
          'Revisa el clima antes de tu recorrido. Trae binoculares para observar '
          'aves y una cámara sin flash. Los mejores horarios para avistar fauna '
          'son temprano en la mañana o al atardecer.',
      color: Color(0xFF1976D2),
    ),
    OnboardingPageData(
      icon: '🌿',
      title: 'Bienvenido a Angostura App',
      description:
          '¡Explora el Parque Humedal Angostura del Biobío! Descubre especies '
          'únicas escaneando códigos QR, colecciona cartas de flora y fauna, '
          'conoce emprendedores locales en el Mercado y gana puntos EcoAngostura '
          'canjeables por recompensas. ¡Tu aventura comienza ahora!',
      color: Color(0xFF4CAF50),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // PageView con las 3 páginas
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Barra inferior con controles
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPageData pageData) {
    return Container(
      padding: const EdgeInsets.all(40.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [pageData.color.withValues(alpha: 0.1), Colors.white],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícono grande
          Text(pageData.icon, style: const TextStyle(fontSize: 120)),
          const SizedBox(height: 40),

          // Título
          Text(
            pageData.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: pageData.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Descripción
          Text(
            pageData.description,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Espacio vacío a la izquierda (antes estaba "Saltar")
          const SizedBox(width: 60),

          // Indicadores de página (dots)
          Row(
            children: List.generate(
              _pages.length,
              (index) => _buildPageIndicator(index),
            ),
          ),

          // Botón "Siguiente" o "Comenzar"
          _currentPage == _pages.length - 1
              ? ElevatedButton(
                  onPressed: _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Comenzar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )
              : TextButton(
                  onPressed: _nextPage,
                  child: const Row(
                    children: [
                      Text(
                        'Siguiente',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        color: Color(0xFF4CAF50),
                        size: 20,
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF4CAF50) : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
