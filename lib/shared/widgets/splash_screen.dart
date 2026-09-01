import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/navigation_service.dart';
import '../../core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize services
      await StorageService.init();
      await SupabaseService.init();

      // Small delay for splash effect
      await Future.delayed(const Duration(seconds: 2));

      // Determine where to navigate
      if (mounted) {
        final isOnboardingCompleted = StorageService.isOnboardingCompleted;
        final isLoggedIn = StorageService.isLoggedIn;

        if (isOnboardingCompleted && isLoggedIn) {
          NavigationService.goToDashboard();
        } else {
          NavigationService.goToOnboarding();
        }
      }
    } catch (e) {
      debugPrint('Error initializing app: $e');
      // On error, go to onboarding
      if (mounted) {
        NavigationService.goToOnboarding();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryGreen),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(AppConstants.primaryGreen),
              Color(AppConstants.secondaryGreen),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🌿', style: TextStyle(fontSize: 80)),
              SizedBox(height: 24),
              Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Cargando...',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}
