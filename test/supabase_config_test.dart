import 'package:angostura_appv1/core/constants/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detecta una configuración de Supabase ausente o completa', () {
    final isComplete =
        SupabaseConfig.url.trim().isNotEmpty &&
        SupabaseConfig.anonKey.trim().isNotEmpty;

    if (isComplete) {
      expect(SupabaseConfig.validate, returnsNormally);
    } else {
      expect(
        SupabaseConfig.validate,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('SUPABASE_'),
          ),
        ),
      );
    }
  });
}
