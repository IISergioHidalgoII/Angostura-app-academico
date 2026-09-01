import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../constants/supabase_config.dart';
import 'offline_storage_service.dart';
import 'storage_service.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    SupabaseConfig.validate();
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  // Sites
  static Future<List<Map<String, dynamic>>> getSites() async {
    final response = await client
        .from(SupabaseConfig.sitesTable)
        .select('id, name, region, description, latitude, longitude')
        .eq('is_active', true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Users
  static Future<Map<String, dynamic>> createOrGetUser({
    required String email,
    String? displayName,
    String? username,
  }) async {
    try {
      // Obtener el userId del usuario autenticado
      final authUser = client.auth.currentUser;
      if (authUser == null) {
        debugPrint('⚠️ createOrGetUser: No hay usuario autenticado');
        throw Exception('No hay usuario autenticado');
      }
      final userId = authUser.id;

      debugPrint('  📝 Verificando si usuario existe en tabla users...');
      debugPrint('     Auth User ID: $userId');
      debugPrint('     Auth User Email: ${authUser.email}');

      // Check if user exists usando el UUID del auth
      final existingUserResponse = await client
          .from(SupabaseConfig.usersTable)
          .select('*')
          .eq('id', userId)
          .limit(1);

      if (existingUserResponse.isNotEmpty) {
        debugPrint('  ✅ Usuario ya existe en tabla users');
        debugPrint('     ID: ${existingUserResponse.first['id']}');
        return existingUserResponse.first;
      }

      // Create new user con el UUID del auth
      debugPrint('  🆕 Creando nuevo usuario en tabla users...');
      debugPrint('     User ID: $userId');
      debugPrint('     Email: $email');
      debugPrint('     Display Name: ${displayName ?? email.split('@')[0]}');

      final insertData = {
        'id': userId, // Usar el UUID del auth
        'email': email,
        'display_name': displayName ?? email.split('@')[0],
        'username': username ?? email.split('@')[0].replaceAll('.', '_'),
      };

      debugPrint('     Datos a insertar: $insertData');

      final newUser = await client
          .from(SupabaseConfig.usersTable)
          .insert(insertData)
          .select()
          .single();

      debugPrint('  ✅ Usuario creado en tabla users exitosamente');
      debugPrint('     ID retornado: ${newUser['id']}');
      debugPrint('     Email retornado: ${newUser['email']}');

      // Verificar que realmente se creó
      final verifyUser = await client
          .from(SupabaseConfig.usersTable)
          .select('id')
          .eq('id', userId)
          .single();

      debugPrint(
        '  ✅ Verificación: Usuario existe en BD con ID: ${verifyUser['id']}',
      );

      return newUser;
    } catch (e, stackTrace) {
      debugPrint('  ❌ Error en createOrGetUser: $e');
      debugPrint('  📚 Stack: $stackTrace');

      // Información adicional para debugging
      final authUser = client.auth.currentUser;
      if (authUser != null) {
        debugPrint('  🔍 Debug info:');
        debugPrint('     Auth User ID: ${authUser.id}');
        debugPrint('     Auth User Email: ${authUser.email}');
        debugPrint('     Param Email: $email');
      }

      rethrow;
    }
  }

  // Households
  static Future<Map<String, dynamic>> createHousehold({
    required String userId,
    required String siteId,
    required String name,
    required String redeemCode,
  }) async {
    final household = await client
        .from(SupabaseConfig.householdsTable)
        .insert({
          'site_id': siteId,
          'name': name,
          'owner_user_id': userId,
          'redeem_code': redeemCode,
          'activated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return household;
  }

  // Cards
  static Future<List<Map<String, dynamic>>> getCardsBySite(
    String siteId,
  ) async {
    final response = await client
        .from(SupabaseConfig.cardsTable)
        .select('id, title, code, rarity, areas(name)')
        .eq('site_id', siteId);
    return List<Map<String, dynamic>>.from(response);
  }

  // Points
  static Future<int> getHouseholdPoints(String householdId) async {
    final response = await client.rpc(
      SupabaseConfig.getHouseholdPointsFunction,
      params: {'p_household_uuid': householdId},
    );
    return response ?? 0;
  }

  // ==================== FUNCIONALIDAD FAMILIAR ====================

  /// Obtiene la información de la familia del usuario actual
  /// Retorna: {
  ///   'household_id': String,
  ///   'household_name': String,
  ///   'redeem_code': String,
  ///   'role': 'owner' | 'member' | 'child' | 'admin',
  ///   'is_child': bool,
  ///   'member_count': int
  /// }
  static Future<Map<String, dynamic>?> getCurrentUserFamilyInfo() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await client
          .from('household_members')
          .select('''
            household_id,
            role,
            is_child,
            households!inner(
              id,
              name,
              redeem_code
            )
          ''')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      // Contar miembros de la familia
      final memberCount = await client
          .from('household_members')
          .select('id')
          .eq('household_id', response['household_id'])
          .count();

      return {
        'household_id': response['household_id'],
        'household_name': response['households']['name'],
        'redeem_code': response['households']['redeem_code'],
        'role': response['role'], // 'owner' o 'member'
        'is_child': response['is_child'],
        'is_owner': response['role'] == 'owner',
        'member_count': memberCount.count,
      };
    } catch (e) {
      debugPrint('Error obteniendo info familiar: $e');
      return null;
    }
  }

  /// Obtiene todas las cartas desbloqueadas por la familia (sin duplicados)
  /// Incluye las cartas de todos los miembros (padre e hijos)
  static Future<List<Map<String, dynamic>>> getFamilyUnlockedCards(
    String householdId,
  ) async {
    try {
      // Obtener todos los user_ids de la familia
      final members = await client
          .from('household_members')
          .select('user_id')
          .eq('household_id', householdId);

      if (members.isEmpty) return [];

      final userIds = members.map((m) => m['user_id']).toList();

      // Obtener cartas únicas desbloqueadas por cualquier miembro
      final unlockedCards = await client
          .from('user_cards')
          .select('''
            card_id,
            unlocked_at,
            cards!inner(
              id,
              title,
              code,
              rarity,
              image_url
            )
          ''')
          .inFilter('user_id', userIds)
          .order('unlocked_at', ascending: false);

      // Eliminar duplicados (quedarse con la primera vez que se desbloqueó)
      final uniqueCards = <String, Map<String, dynamic>>{};
      for (var card in unlockedCards) {
        final cardId = card['card_id'];
        if (!uniqueCards.containsKey(cardId)) {
          uniqueCards[cardId] = card;
        }
      }

      return uniqueCards.values.toList();
    } catch (e) {
      debugPrint('Error obteniendo cartas familiares: $e');
      return [];
    }
  }

  /// Obtiene los miembros de la familia
  static Future<List<Map<String, dynamic>>> getFamilyMembers(
    String householdId,
  ) async {
    try {
      final members = await client
          .from('household_members')
          .select('''
            user_id,
            display_name,
            role,
            is_child,
            created_at
          ''')
          .eq('household_id', householdId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(members);
    } catch (e) {
      debugPrint('Error obteniendo miembros familiares: $e');
      return [];
    }
  }

  /// Sincroniza las cartas locales de un hijo con el servidor
  /// Los hijos pueden escanear offline y luego sincronizar cuando hay internet
  static Future<bool> syncLocalCardsToFamily(List<String> cardCodes) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;

      // Por cada código, intentar desbloquear la carta
      for (var code in cardCodes) {
        try {
          await client.rpc(
            'unlock_card_by_code',
            params: {'p_user_uuid': userId, 'p_card_code': code},
          );
        } catch (e) {
          debugPrint('Error desbloqueando carta $code: $e');
          // Continuar con las demás cartas
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error sincronizando cartas: $e');
      return false;
    }
  }

  // ================================================================

  // Test connection
  static Future<bool> testConnection() async {
    try {
      await client.auth.getUser();
      return true;
    } catch (e) {
      // AuthSessionMissing is expected when no user is logged in
      return e.toString().contains('AuthSessionMissing') ||
          e.toString().contains('session missing');
    }
  }

  // Family Code Validation
  static Future<bool> validateFamilyCode(String code) async {
    try {
      final response = await client
          .from('households')
          .select('id, redeem_code')
          .eq('redeem_code', code)
          .limit(1);
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Complete User Creation
  static Future<String?> createUserComplete({
    required String email,
    required String region,
    required String park,
    required String userType,
    String? familyCode,
  }) async {
    try {
      debugPrint('\n🚀 === INICIO createUserComplete ===');
      debugPrint('📧 Email: $email');
      debugPrint('🌍 Region: $region, Park: $park');
      debugPrint('👥 User Type: $userType');
      debugPrint('🔑 Family Code: $familyCode');

      // 1. Obtener el userId del usuario autenticado (de Supabase Auth)
      final authUser = client.auth.currentUser;
      debugPrint('🔍 Auth User: ${authUser?.email}');
      debugPrint('🔍 Auth User ID: ${authUser?.id}');
      debugPrint('🔍 Email Confirmed: ${authUser?.emailConfirmedAt}');

      if (authUser == null) {
        debugPrint('❌ No hay usuario autenticado en Supabase Auth');
        return null;
      }
      final userId = authUser.id;

      // 2. Crear entrada en tabla users (si no existe)
      debugPrint('📝 === PASO 2: Crear usuario en tabla public.users ===');
      debugPrint('   Llamando createOrGetUser con email: $email');

      Map<String, dynamic> userEntry;
      try {
        userEntry = await createOrGetUser(email: email);
        debugPrint('✅ Usuario en tabla public.users:');
        debugPrint('   ID: ${userEntry['id']}');
        debugPrint('   Email: ${userEntry['email']}');
        debugPrint('   Display Name: ${userEntry['display_name']}');

        // VERIFICACIÓN CRÍTICA: Asegurar que el ID coincide
        if (userEntry['id'] != userId) {
          debugPrint('⚠️ ADVERTENCIA: IDs no coinciden!');
          debugPrint('   Auth ID: $userId');
          debugPrint('   Users table ID: ${userEntry['id']}');
          throw Exception('User ID mismatch between auth and users table');
        }

        // Esperar un momento para asegurar que la BD procesó la transacción
        await Future.delayed(const Duration(milliseconds: 100));

        // Verificación adicional: Confirmar que el usuario existe antes de continuar
        final verifyExists = await client
            .from(SupabaseConfig.usersTable)
            .select('id')
            .eq('id', userId)
            .maybeSingle();

        if (verifyExists == null) {
          debugPrint('❌ ERROR: Usuario no encontrado después de creación');
          throw Exception('User not found in database after creation');
        }

        debugPrint('✅ Verificación final: Usuario confirmado en BD');
      } catch (e, stackTrace) {
        debugPrint('❌ ERROR CRÍTICO creando usuario en tabla users: $e');
        debugPrint('❌ Stack trace: $stackTrace');
        debugPrint('❌ Detalles:');
        debugPrint('   - Auth User ID: $userId');
        debugPrint('   - Email: $email');
        debugPrint('   - Tipo de error: ${e.runtimeType}');
        rethrow;
      }

      // 3. Handle different user types
      Map<String, dynamic>? householdData;

      if (userType == 'UserType.family') {
        debugPrint('📝 === PASO 3: Crear household familiar ===');
        debugPrint('   Usuario verificado en BD, procediendo...');

        try {
          householdData = await _createHouseholdForUser(userId, email, park);
        } catch (e, stackTrace) {
          debugPrint('❌ ERROR creando household: $e');
          debugPrint('❌ Stack trace: $stackTrace');
          rethrow;
        }

        // Guardar household_data en storage para mostrar después
        if (householdData != null) {
          await StorageService.setHouseholdData({
            'household_id': householdData['household_id'],
            'family_code': householdData['family_code'],
            'verification_code': householdData['verification_code'],
            'owner_email': householdData['owner_email'],
            'is_new': householdData['is_new'],
          });
        }
      } else if (userType == 'UserType.joinFamily' && familyCode != null) {
        debugPrint('🤝 Uniéndose a household existente...');
        await _joinExistingHousehold(userId, email, familyCode);
      } else {
        debugPrint('👤 Usuario individual (sin household)');
      }

      debugPrint('✅ === FIN createUserComplete (userId: $userId) ===\n');
      return userId;
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating user complete: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _createHouseholdForUser(
    String userId,
    String email,
    String park,
  ) async {
    debugPrint('  🏠 === Creando Household con nuevo sistema ===');
    debugPrint('  👤 User ID: $userId');
    debugPrint('  📧 Email: $email');
    debugPrint('  🏞️ Park: $park');

    // Find the site
    final siteName = park == 'angostura'
        ? 'Parque Humedal Angostura del Biobío'
        : park;
    debugPrint('  🔍 Buscando sitio: $siteName');

    final siteResponse = await client
        .from('sites')
        .select('id, name')
        .eq('name', siteName)
        .limit(1);

    debugPrint('  📍 Sites encontrados: ${siteResponse.length}');

    if (siteResponse.isEmpty) {
      debugPrint('  ⚠️ No se encontró el sitio: $siteName');
      throw Exception('Sitio no encontrado: $siteName');
    }

    final siteId = siteResponse.first['id'];

    // Usar HouseholdService para crear household
    // (importar HouseholdService en el futuro, por ahora llamar RPC directamente)
    debugPrint('  📝 Llamando a create_household_for_owner RPC...');

    final result = await client.rpc(
      'create_household_for_owner',
      params: {
        'p_site_id': siteId,
        'p_household_name': 'Familia de ${email.split('@')[0]}',
      },
    );

    debugPrint('  ✅ Household creado/recuperado');
    debugPrint('  🎫 Family Code: ${result['family_code']}');
    debugPrint('  🔐 Verification Code: ${result['verification_code']}');
    debugPrint('  📧 IMPORTANTE: Enviar código de verificación por email');

    return Map<String, dynamic>.from(result);
  }

  static Future<void> _joinExistingHousehold(
    String userId,
    String email,
    String familyCode,
  ) async {
    // Find the household by code
    final householdResponse = await client
        .from('households')
        .select('id')
        .eq('redeem_code', familyCode)
        .single();

    // Add user as household member
    await client.from('household_members').upsert({
      'household_id': householdResponse['id'],
      'user_id': userId,
      'role': 'member',
      'display_name': email.split('@')[0],
      'is_child': false,
    });

    // Usuario agregado al household con código: $familyCode
  }

  static Future<String?> getHouseholdCodeForUser(String userId) async {
    try {
      final response = await client
          .from('households')
          .select('redeem_code')
          .eq('owner_user_id', userId)
          .limit(1);

      if (response.isNotEmpty) {
        return response.first['redeem_code'];
      }
      return null;
    } catch (e) {
      // Error getting household code: $e
      return null;
    }
  }

  // Market Items
  static Future<List<Map<String, dynamic>>> getMarketItems() async {
    try {
      final response = await client
          .from('market_items')
          .select(
            'id, title, description, category, image_url, profile_image_url, contact_info, phone_number, address, location_label, products, is_active, created_at, updated_at',
          )
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getMarketItems: $e');
      rethrow;
    }
  }

  /// Sube una imagen al storage de Supabase y retorna la URL pública
  static Future<String> uploadMarketImage(
    String filePath,
    String fileName,
  ) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final String path = 'market/$fileName';

      await client.storage
          .from('market-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final String publicUrl = client.storage
          .from('market-images')
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploadMarketImage: $e');
      rethrow;
    }
  }

  static Future<String> insertMarketItem({
    required String title,
    String? description,
    String? category,
    String? imageUrl,
    String? profileImageUrl,
    String? contactInfo,
    String? phoneNumber,
    String? address,
    String? locationLabel,
  }) async {
    try {
      final response = await client
          .from('market_items')
          .insert({
            'title': title,
            'description': description,
            'category': category,
            'image_url': imageUrl,
            'profile_image_url': profileImageUrl,
            'contact_info': contactInfo,
            'phone_number': phoneNumber,
            'address': address,
            'location_label': locationLabel,
            'is_active': true,
            'is_verified': false,
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      debugPrint('Error insertMarketItem: $e');
      rethrow;
    }
  }

  static Future<void> updateMarketItem({
    required String id,
    required String title,
    String? description,
    String? category,
    String? imageUrl,
    String? profileImageUrl,
    String? contactInfo,
    String? phoneNumber,
    String? address,
    String? locationLabel,
    String? verificationCode,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'title': title,
        'description': description,
        'category': category,
        'contact_info': contactInfo,
        'phone_number': phoneNumber,
        'address': address,
        'location_label': locationLabel,
      };

      // Solo incluir URLs de imagen si no son nulas
      if (imageUrl != null) {
        updateData['image_url'] = imageUrl;
      }
      if (profileImageUrl != null) {
        updateData['profile_image_url'] = profileImageUrl;
      }

      // Si se proporciona código de verificación, verificar y actualizar
      if (verificationCode != null && verificationCode.isNotEmpty) {
        // Obtener item actual para verificar código
        final currentItem = await client
            .from('market_items')
            .select('verification_code')
            .eq('id', id)
            .single();

        if (currentItem['verification_code'] == verificationCode) {
          updateData['is_verified'] = true;
          updateData['verified_at'] = DateTime.now().toIso8601String();
        }
      }

      await client.from('market_items').update(updateData).eq('id', id);
    } catch (e) {
      debugPrint('Error updateMarketItem: $e');
      rethrow;
    }
  }

  // ==================== PRODUCTS_ITEMS METHODS ====================

  /// Inserta un producto en la tabla products_items
  static Future<String> insertProductItem({
    required String marketItemId,
    required String name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final response = await client
          .from('products_items')
          .insert({
            'market_item_id': marketItemId,
            'name': name,
            'description': description,
            'image_url': imageUrl,
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      debugPrint('Error insertProductItem: $e');
      rethrow;
    }
  }

  /// Obtiene todos los productos de un market_item
  static Future<List<Map<String, dynamic>>> getProductItemsByMarketId(
    String marketItemId,
  ) async {
    try {
      final response = await client
          .from('products_items')
          .select()
          .eq('market_item_id', marketItemId)
          .order('created_at');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getProductItemsByMarketId: $e');
      return [];
    }
  }

  /// Actualiza un producto
  static Future<void> updateProductItem({
    required String id,
    String? name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (imageUrl != null) updateData['image_url'] = imageUrl;

      if (updateData.isNotEmpty) {
        await client.from('products_items').update(updateData).eq('id', id);
      }
    } catch (e) {
      debugPrint('Error updateProductItem: $e');
      rethrow;
    }
  }

  /// Elimina un producto
  static Future<void> deleteProductItem(String id) async {
    try {
      await client.from('products_items').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleteProductItem: $e');
      rethrow;
    }
  }

  /// Genera y guarda un código de verificación de 6 dígitos
  static Future<String> generateVerificationCode(String id) async {
    try {
      final code = (100000 + Random().nextInt(900000)).toString();

      await client
          .from('market_items')
          .update({'verification_code': code})
          .eq('id', id);

      return code;
    } catch (e) {
      debugPrint('Error generateVerificationCode: $e');
      rethrow;
    }
  }

  /// Elimina todos los productos de un market_item
  static Future<void> deleteAllProductItemsByMarketId(
    String marketItemId,
  ) async {
    try {
      await client
          .from('products_items')
          .delete()
          .eq('market_item_id', marketItemId);
    } catch (e) {
      debugPrint('Error deleteAllProductItemsByMarketId: $e');
      rethrow;
    }
  }

  // QR Token Redemption
  static Future<Map<String, dynamic>> redeemQrToken(
    String token,
    String userId,
  ) async {
    try {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('🎫 REDEEM QR TOKEN INICIADO');
      debugPrint('═══════════════════════════════════════════════════════');

      // Verificar userData primero
      final userData = StorageService.userData ?? {};
      debugPrint('💾 UserData en StorageService:');
      debugPrint('   - child_user_id: ${userData['child_user_id']}');
      debugPrint('   - guest_household_id: ${userData['guest_household_id']}');
      debugPrint('   - is_guest: ${userData['is_guest']}');
      debugPrint('   - user_type: ${userData['user_type']}');

      // Normalizar token: trim y uppercase para coincidir con formato BD
      final normalizedToken = token.trim().toUpperCase();
      debugPrint(
        '🔍 Buscando token QR: "$normalizedToken" (original: "$token")',
      );
      debugPrint('👤 Usuario: $userId');

      // 1. Buscar token en qr_tokens
      final qrTokenResponse = await client
          .from('qr_tokens')
          .select('id, card_id, qr_id')
          .eq('qr_id', normalizedToken)
          .limit(1);

      debugPrint('📊 Resultado búsqueda QR: ${qrTokenResponse.length} tokens');

      if (qrTokenResponse.isEmpty) {
        debugPrint('❌ Token no encontrado en qr_tokens');
        debugPrint('   Token buscado: "$normalizedToken"');
        throw Exception(
          'QR no encontrado en el sistema. Verifica que el código sea correcto.',
        );
      }

      final cardId = qrTokenResponse.first['card_id'] as String;
      debugPrint('🎴 Card ID vinculado: $cardId');

      // 2. Obtener datos de la carta con JOIN a seasons para validación
      final cardResponse = await client
          .from('cards')
          .select(
            'id, title, description, image_url, rarity, code, season_id, seasons(name)',
          )
          .eq('id', cardId)
          .eq('is_active', true)
          .single();

      // Extraer nombre de la temporada del JOIN
      final seasonData = cardResponse['seasons'] as Map<String, dynamic>?;
      final seasonName = seasonData?['name'] as String?;

      // Detectar temporada actual
      final currentSeason = _detectCurrentSeason();
      debugPrint('📅 Temporada actual: $currentSeason');
      debugPrint('🎴 Temporada de carta: $seasonName');

      // Validar que la carta sea de la temporada actual
      if (seasonName != null &&
          seasonName.toLowerCase() != currentSeason.toLowerCase()) {
        throw Exception(
          'Esta carta pertenece a la temporada "$seasonName". Solo se pueden canjear cartas de la temporada "$currentSeason".',
        );
      }

      // 3. Determinar si es invitado (child_user) o usuario normal
      final childUserId = userData['child_user_id'] as String?;
      final isGuest = childUserId != null;

      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('👤 TIPO DE USUARIO:');
      debugPrint('   - Es invitado: $isGuest');
      if (isGuest) {
        debugPrint('   - child_user_id: $childUserId');
        debugPrint('   - household_id: ${userData['guest_household_id']}');
      } else {
        debugPrint('   - user_id: $userId');
      }
      debugPrint('───────────────────────────────────────────────────────');

      bool alreadyOwned = false;

      // 4. Verificar si ya tiene esta carta
      debugPrint('🔍 Verificando si ya tiene la carta $cardId...');

      if (isGuest) {
        // Invitado: buscar por child_user_id
        debugPrint('   Buscando en user_cards por child_user_id=$childUserId');
        final existingCardResponse = await client
            .from('user_cards')
            .select('id')
            .eq('child_user_id', childUserId)
            .eq('card_id', cardId)
            .limit(1);

        debugPrint('   Resultados: ${existingCardResponse.length}');
        alreadyOwned = existingCardResponse.isNotEmpty;

        // Insertar carta con child_user_id
        if (!alreadyOwned) {
          try {
            debugPrint('💾 Insertando carta en user_cards para child_user...');
            await client.from('user_cards').insert({
              'child_user_id': childUserId,
              'card_id': cardId,
              'source': 'qr',
            });
            debugPrint('✅ Carta agregada a colección de child_user');
          } catch (insertError) {
            final errorMsg = insertError.toString().toLowerCase();
            // Si es error de duplicado, marcar como alreadyOwned
            if (errorMsg.contains('duplicate') ||
                errorMsg.contains('unique') ||
                errorMsg.contains('23505')) {
              debugPrint('ℹ️ Carta ya existía (duplicate key detectado)');
              alreadyOwned = true;
            } else {
              // Si es otro error, relanzar
              debugPrint('❌ Error insertando carta: $insertError');
              rethrow;
            }
          }

          // Solo desbloquear para household si es carta nueva
          if (!alreadyOwned) {
            try {
              debugPrint(
                '🔓 Intentando desbloquear carta para miembros del household...',
              );

              final householdId = userData['guest_household_id'] as String?;

              if (householdId != null) {
                debugPrint('👨‍👩‍👧‍👦 Household ID: $householdId');
                debugPrint('🎴 Card ID: $cardId');

                final unlockResult = await client.rpc(
                  'unlock_card_for_household',
                  params: {
                    'p_household_id': householdId.toString(),
                    'p_card_id': cardId.toString(),
                  },
                );

                debugPrint('📦 RPC Response: $unlockResult');

                final unlockedCount = unlockResult['unlocked_count'] as int;
                debugPrint(
                  '✅ Carta desbloqueada para $unlockedCount miembros del household',
                );
              } else {
                debugPrint('⚠️ No se encontró household_id en userData');
              }
            } catch (e) {
              debugPrint('⚠️ Error desbloqueando para household: $e');
              debugPrint('📍 StackTrace: ${StackTrace.current}');
              // Continuar aunque falle el desbloqueo para el household
            }
          }
        }
      } else {
        // Usuario normal: buscar por user_id
        final existingCardResponse = await client
            .from('user_cards')
            .select('id')
            .eq('user_id', userId)
            .eq('card_id', cardId)
            .limit(1);

        alreadyOwned = existingCardResponse.isNotEmpty;

        // Insertar carta con user_id
        if (!alreadyOwned) {
          try {
            await client.from('user_cards').insert({
              'user_id': userId,
              'card_id': cardId,
              'source': 'qr',
            });
            debugPrint('✅ Carta agregada a colección del usuario');
          } catch (insertError) {
            final errorMsg = insertError.toString().toLowerCase();
            // Si es error de duplicado, marcar como alreadyOwned
            if (errorMsg.contains('duplicate') ||
                errorMsg.contains('unique') ||
                errorMsg.contains('23505')) {
              debugPrint('ℹ️ Carta ya existía (duplicate key detectado)');
              alreadyOwned = true;
            } else {
              // Si es otro error, relanzar
              debugPrint('❌ Error insertando carta: $insertError');
              rethrow;
            }
          }
        }
      }

      // 5. Ya no es necesario registrar en redemptions
      // Las cartas se insertan directamente en user_cards con child_user_id o user_id
      // El padre puede ver todas las cartas usando getUserCards() que consulta ambos
      debugPrint('✅ Carta registrada exitosamente');

      // 6. Devolver resultado
      debugPrint('✅ redeemQrToken completado exitosamente');
      return {'alreadyOwned': alreadyOwned, 'card': cardResponse};
    } catch (e, stackTrace) {
      debugPrint('❌ Error redeemQrToken: $e');
      debugPrint('📍 StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Detecta la temporada actual basada en la fecha
  static String _detectCurrentSeason() {
    final now = DateTime.now();
    final month = now.month;

    // Verano: Diciembre - Febrero
    if (month == 12 || month == 1 || month == 2) {
      return 'verano';
    }
    // Otoño: Marzo - Mayo
    else if (month >= 3 && month <= 5) {
      return 'otoño';
    }
    // Invierno: Junio - Agosto
    else if (month >= 6 && month <= 8) {
      return 'invierno';
    }
    // Primavera: Septiembre - Noviembre
    else {
      return 'primavera';
    }
  }

  // Collection - Get user cards
  static Future<List<Map<String, dynamic>>> getUserCards(String userId) async {
    try {
      debugPrint('📦 getUserCards llamado para userId: $userId');

      // Verificar si es invitado (child_user)
      final userData = StorageService.userData ?? {};
      final childUserId = userData['child_user_id'] as String?;
      final isGuest = childUserId != null;

      List<Map<String, dynamic>> userCards = [];

      if (isGuest) {
        // Invitado: obtener solo sus propias cartas por child_user_id
        debugPrint('👶 Usuario es invitado con child_user_id: $childUserId');

        try {
          final guestCardsResponse = await client
              .from('user_cards')
              .select(
                'id, unlocked_at, source, cards(id, title, description, image_url, rarity, code, scientific_name, technical_data, curiosities, card_type, season_id, seasons(id, name))',
              )
              .eq('child_user_id', childUserId)
              .order('unlocked_at', ascending: false);

          userCards = List<Map<String, dynamic>>.from(guestCardsResponse);
          debugPrint('📊 Cartas de invitado: ${userCards.length}');

          // Debug: verificar estructura de cada carta
          for (var uc in userCards) {
            final cardData = uc['cards'];
            if (cardData == null) {
              debugPrint('⚠️ ALERTA: user_card con cards=null: ${uc['id']}');
            } else {
              debugPrint('✓ Card OK: ${cardData['title']} (${cardData['id']})');
            }
          }

          return userCards; // Retornar solo cartas de invitado
        } catch (e) {
          debugPrint('❌ Error cargando cartas de invitado: $e');
          debugPrint('📍 StackTrace: ${StackTrace.current}');
          rethrow;
        }
      }

      // Usuario normal: obtener cartas propias desde user_cards
      final userCardsResponse = await client
          .from('user_cards')
          .select(
            'id, unlocked_at, source, cards(id, title, description, image_url, rarity, code, scientific_name, technical_data, curiosities, card_type, season_id, seasons(name))',
          )
          .eq('user_id', userId)
          .order('unlocked_at', ascending: false);

      userCards = List<Map<String, dynamic>>.from(userCardsResponse);
      debugPrint('📊 Cartas propias: ${userCards.length}');

      // 2. Verificar si el usuario es padre de familia (tiene household)
      try {
        final householdResponse = await client
            .from('household_members')
            .select('household_id, role')
            .eq('user_id', userId)
            .limit(1);

        if (householdResponse.isNotEmpty) {
          final householdId = householdResponse.first['household_id'] as String;
          debugPrint('👨‍👩‍👧‍👦 Usuario pertenece a household: $householdId');

          // 3. Obtener cartas escaneadas por child_users (invitados) del household
          try {
            // Primero obtener los child_user_ids del household
            final childUsersResponse = await client
                .from('child_users')
                .select('id')
                .eq('household_id', householdId);

            final childUserIds = childUsersResponse
                .map((cu) => cu['id'] as String)
                .toList();

            debugPrint('👶 Child users en household: ${childUserIds.length}');

            if (childUserIds.isNotEmpty) {
              // Obtener cartas de child_users
              final childCardsResponse = await client
                  .from('user_cards')
                  .select(
                    'id, unlocked_at, source, child_user_id, cards(id, title, description, image_url, rarity, code, scientific_name, technical_data, curiosities, card_type, season_id, seasons(name))',
                  )
                  .inFilter('child_user_id', childUserIds)
                  .order('unlocked_at', ascending: false);

              debugPrint(
                '📊 Cartas de child_users: ${childCardsResponse.length}',
              );

              // Agregar cartas de child_users (evitar duplicados)
              for (final childCard in childCardsResponse) {
                final cardData = childCard['cards'];
                if (cardData != null) {
                  final cardId = (cardData as Map<String, dynamic>)['id'];
                  final alreadyExists = userCards.any((uc) {
                    final existingCard = uc['cards'] as Map<String, dynamic>?;
                    return existingCard?['id'] == cardId;
                  });

                  if (!alreadyExists) {
                    debugPrint(
                      '➕ Agregando carta de invitado: ${cardData['title']}',
                    );
                    userCards.add({
                      'id': childCard['id'],
                      'unlocked_at': childCard['unlocked_at'],
                      'source': 'guest',
                      'cards': cardData,
                    });
                  }
                }
              }

              debugPrint(
                '📊 Total cartas (propias + invitados): ${userCards.length}',
              );
            }
          } catch (e) {
            debugPrint('⚠️ Error obteniendo cartas de child_users: $e');
          }
        }
      } catch (e) {
        debugPrint('⚠️ No se pudo verificar household: $e');
        // Continuar con solo las cartas propias
      }

      return userCards;
    } catch (e) {
      debugPrint('❌ Error getUserCards: $e');
      rethrow;
    }
  }

  // Progress - Get user cards count
  static Future<int> getUserCardsCount(String userId) async {
    try {
      final response = await client
          .from('user_cards')
          .select('id')
          .eq('user_id', userId);
      return (response as List).length;
    } catch (e) {
      debugPrint('Error getUserCardsCount: $e');
      return 0;
    }
  }

  // Progress - Get total cards count
  static Future<int> getTotalCardsCount() async {
    try {
      final response = await client.from('cards').select('id');
      return (response as List).length;
    } catch (e) {
      debugPrint('Error getTotalCardsCount: $e');
      return 0;
    }
  }

  // FILTROS - Get all cards (for collection page filters)
  static Future<List<Map<String, dynamic>>> getAllCards() async {
    try {
      final response = await client
          .from('cards')
          .select('id, title, description, image_url, rarity, code')
          .order('title', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getAllCards: $e');
      rethrow;
    }
  }

  /// Obtiene todas las cartas de la temporada activa
  static Future<List<Map<String, dynamic>>> getActiveSeasonCards() async {
    try {
      // 1. Obtener temporada activa
      final activeSeason = await client
          .from('seasons')
          .select('id, name')
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

      if (activeSeason == null) {
        debugPrint('⚠️ No hay temporada activa');
        return [];
      }

      debugPrint('📅 Temporada activa: ${activeSeason['name']}');

      // 2. Obtener cartas de esa temporada
      final response = await client
          .from('cards')
          .select('id, title, description, image_url, rarity, code, area_id')
          .eq('season_id', activeSeason['id'])
          .eq('is_active', true)
          .order('rarity', ascending: false) // Amenazadas primero
          .order('title', ascending: true);

      debugPrint('🎴 Cartas de temporada activa: ${response.length}');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getActiveSeasonCards: $e');
      rethrow;
    }
  }

  // DEBUG/DEMO - Reset user collection (delete all user_cards for this user)
  static Future<void> resetUserCollection(String userId) async {
    try {
      debugPrint('🗑️ Eliminando cartas de user_cards para: $userId');
      await client.from('user_cards').delete().eq('user_id', userId);

      // También limpiar el cache offline
      debugPrint('🗑️ Limpiando cache offline de cartas...');
      await OfflineStorageService.clearCachedCards();

      debugPrint('✅ Colección reseteada completamente (BD + cache)');
    } catch (e) {
      debugPrint('Error resetUserCollection: $e');
      rethrow;
    }
  }

  // DEBUG/DEMO - Get all cards for current season (from cloud)
  static Future<List<Map<String, dynamic>>> getSeasonCards(
    String seasonId,
  ) async {
    try {
      debugPrint('🔍 Obteniendo cartas de temporada ID: $seasonId');
      final response = await client
          .from('cards')
          .select('id, title, code, rarity, season_id, seasons(name)')
          .eq('season_id', seasonId)
          .order('title', ascending: true);

      final cards = List<Map<String, dynamic>>.from(response);
      debugPrint(
        '✅ Encontradas ${cards.length} cartas de temporada ID $seasonId',
      );
      return cards;
    } catch (e) {
      debugPrint('Error getSeasonCards: $e');
      rethrow;
    }
  }

  // DEBUG/DEMO - Clear all market cache
  static Future<void> clearMarketCache() async {
    try {
      debugPrint('🗑️ Limpiando cache de mercado...');
      await OfflineStorageService.clearMarketCache();
      debugPrint('✅ Cache de mercado limpiado');
    } catch (e) {
      debugPrint('Error clearMarketCache: $e');
      rethrow;
    }
  }
}
