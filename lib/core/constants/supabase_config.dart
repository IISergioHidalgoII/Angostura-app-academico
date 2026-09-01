class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void validate() {
    final missingVariables = <String>[
      if (url.trim().isEmpty) 'SUPABASE_URL',
      if (anonKey.trim().isEmpty) 'SUPABASE_ANON_KEY',
    ];

    if (missingVariables.isNotEmpty) {
      throw StateError(
        'Falta configurar ${missingVariables.join(' y ')}. '
        'Ejecuta Flutter con --dart-define-from-file=dart_defines.json '
        'o proporciona cada variable mediante --dart-define.',
      );
    }
  }

  static const String usersTable = 'users';
  static const String sitesTable = 'sites';
  static const String householdsTable = 'households';
  static const String householdMembersTable = 'household_members';
  static const String cardsTable = 'cards';
  static const String redemptionsTable = 'redemptions';
  static const String rewardsTable = 'rewards';

  static const String getHouseholdPointsFunction = 'get_household_points';
  static const String checkQrCooldownFunction = 'check_qr_cooldown';
}
