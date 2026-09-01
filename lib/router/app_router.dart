import 'package:go_router/go_router.dart';
import '../core/constants/routes.dart';
import '../core/services/navigation_service.dart';
import '../features/onboarding/onboarding_module.dart';
import '../features/dashboard/dashboard_module.dart';
import '../features/qr_scanner/pages/qr_scanner_page.dart';
import '../features/market/presentation/market_page.dart';
import '../features/collection/pages/collection_page.dart';
import '../features/map/pages/map_page.dart';
import '../features/rewards/pages/rewards_page.dart';
import '../features/profile/pages/profile_page.dart';
import '../features/user_mode/user_mode_selector_page.dart';
import '../shared/widgets/splash_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: NavigationService.navigatorKey,
    initialLocation: Routes.splash,
    routes: [
      // Splash Screen
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Onboarding Module
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),

      // Dashboard Module
      GoRoute(
        path: Routes.dashboard,
        builder: (context, state) => const DashboardPage(),
      ),

      // Scanner Module
      GoRoute(
        path: Routes.scanner,
        builder: (context, state) => const QRScannerPage(),
      ),

      // Collection Module
      GoRoute(
        path: Routes.collection,
        builder: (context, state) => const CollectionPage(),
      ),

      // Map Module
      GoRoute(path: Routes.map, builder: (context, state) => const MapPage()),

      // Market Module
      GoRoute(
        path: Routes.market,
        builder: (context, state) => const MarketPage(),
      ),

      // Rewards Module
      GoRoute(
        path: Routes.rewards,
        builder: (context, state) => const RewardsPage(),
      ),

      // Profile Module
      GoRoute(
        path: Routes.profile,
        builder: (context, state) => const ProfilePage(),
      ),

      // User Mode Selector (post-logout)
      GoRoute(
        path: '/user-mode-selector',
        builder: (context, state) => const UserModeSelectorPage(),
      ),
    ],
  );
}
