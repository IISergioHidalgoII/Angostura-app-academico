import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

class StorageService {
  static late Box _appBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _appBox = await Hive.openBox('app_data');
  }

  // Onboarding
  static bool get isOnboardingCompleted =>
      _appBox.get(AppConstants.onboardingCompletedKey, defaultValue: false);

  static Future<void> setOnboardingCompleted(bool completed) =>
      _appBox.put(AppConstants.onboardingCompletedKey, completed);

  // User data
  static Map<String, dynamic>? get userData =>
      _appBox.get(AppConstants.userDataKey)?.cast<String, dynamic>();

  static Future<void> setUserData(Map<String, dynamic> data) =>
      _appBox.put(AppConstants.userDataKey, data);

  // Selected site
  static Map<String, dynamic>? get selectedSite =>
      _appBox.get(AppConstants.selectedSiteKey)?.cast<String, dynamic>();

  static Future<void> setSelectedSite(Map<String, dynamic> site) =>
      _appBox.put(AppConstants.selectedSiteKey, site);

  // Household data
  static Map<String, dynamic>? get householdData =>
      _appBox.get(AppConstants.householdDataKey)?.cast<String, dynamic>();

  static Future<void> setHouseholdData(Map<String, dynamic> data) =>
      _appBox.put(AppConstants.householdDataKey, data);

  // Clear user data only
  static Future<void> clearUserData() async {
    await _appBox.delete(AppConstants.userDataKey);
    await _appBox.delete(AppConstants.householdDataKey);
  }

  // Clear all data (logout)
  static Future<void> clearAll() async {
    await _appBox.clear();
  }

  // Check if user is logged in
  static bool get isLoggedIn => userData != null;

  // ============================================
  // SMART START - Persistencia de estado de app
  // ============================================

  /// Ha visto la pantalla de bienvenida/onboarding
  static bool get hasSeenWelcome =>
      _appBox.get('has_seen_welcome', defaultValue: false);

  static Future<void> setHasSeenWelcome(bool value) =>
      _appBox.put('has_seen_welcome', value);

  /// Modo de usuario seleccionado ('UserType.guest', 'UserType.family', etc.)
  static String? get userMode => _appBox.get('user_mode');

  static Future<void> setUserMode(String? mode) =>
      _appBox.put('user_mode', mode);

  /// Setup inicial completo (región, parque, modo usuario configurados)
  static bool get hasCompletedInitialSetup =>
      _appBox.get('has_completed_setup', defaultValue: false);

  static Future<void> setHasCompletedInitialSetup(bool value) =>
      _appBox.put('has_completed_setup', value);
}
