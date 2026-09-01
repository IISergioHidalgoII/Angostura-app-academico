class Routes {
  // Rutas principales
  static const String splash = '/';
  static const String boot = '/boot';
  static const String onboarding = '/onboarding';
  static const String dashboard = '/dashboard';

  // Rutas de funcionalidades
  static const String scanner = '/scanner';
  static const String collection = '/collection';
  static const String collectionDetail = '/collection/:cardId';
  static const String map = '/map';
  static const String market = '/market';
  static const String rewards = '/rewards';
  static const String rewardsRedeem = '/rewards/redeem/:rewardId';
  static const String profile = '/profile';
  static const String settings = '/profile/settings';

  // Rutas de autenticación y setup
  static const String login = '/login';
  static const String logout = '/logout';
  static const String userModeSelector = '/user-mode-selector';
}
