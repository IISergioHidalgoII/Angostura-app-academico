import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/routes.dart';
import 'storage_service.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static GoRouter? _router;

  static BuildContext? get currentContext => navigatorKey.currentContext;

  static void setRouter(GoRouter router) {
    _router = router;
  }

  // Navigation helpers
  static void goToOnboarding() {
    _router?.go(Routes.onboarding);
  }

  static void goToDashboard() {
    _router?.go(Routes.dashboard);
  }

  static void goToScanner() {
    currentContext?.go(Routes.scanner);
  }

  static void goToCollection() {
    currentContext?.go(Routes.collection);
  }

  static void goToMap() {
    currentContext?.go(Routes.map);
  }

  static void goToRewards() {
    currentContext?.go(Routes.rewards);
  }

  static void goToProfile() {
    currentContext?.go(Routes.profile);
  }

  static void navigateTo(String route) {
    currentContext?.go(route);
  }

  // Authentication navigation
  static void logout() async {
    await StorageService.clearAll();
    currentContext?.go(Routes.onboarding);
  }

  // Determine initial route based on app state
  static String getInitialRoute() {
    if (!StorageService.isOnboardingCompleted) {
      return Routes.onboarding;
    }

    if (!StorageService.isLoggedIn) {
      return Routes.onboarding;
    }

    return Routes.dashboard;
  }
}
