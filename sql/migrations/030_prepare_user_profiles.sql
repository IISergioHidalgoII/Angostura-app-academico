-- Script para preparar la tabla users para recibir UUIDs de auth.users

-- ============================================
-- PASO 1: VERIFICAR ESTRUCTURA ACTUAL
-- ============================================

-- Ver la definición actual de la tabla users
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'users' AND table_schema = 'public'
ORDER BY ordinal_position;

-- ============================================
-- PASO 2: MODIFICAR TABLA USERS
-- ============================================

-- Eliminar el default gen_random_uuid() para permitir insertar UUIDs desde auth
ALTER TABLE users 
  ALTER COLUMN id DROP DEFAULT;

-- La columna id ahora puede recibir UUIDs de auth.users sin generar nuevos

-- ============================================
-- PASO 3: AGREGAR CONSTRAINT ÚNICA PARA EMAIL
-- ============================================

-- Asegurar que el email sea único
ALTER TABLE users 
  ADD CONSTRAINT users_email_unique 
  UNIQUE (email);

-- ============================================
-- PASO 4: CREAR ÍNDICES PARA PERFORMANCE
-- ============================================

-- Índice para búsquedas por id (ya existe como PRIMARY KEY)
-- Índice para búsquedas por email
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ============================================
-- PASO 5: PROBAR INSERCIÓN MANUAL
-- ============================================

-- Test: Intentar insertar un usuario con UUID específico
-- (Reemplaza 'test-uuid' con un UUID real de auth.users para probar)

/*
INSERT INTO users (id, email, display_name, username, created_at)
VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  'test@example.com',
  'Test User',
  'test_user',
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Si esto funciona, el problema no es la tabla
-- Si falla, verifica los constraints y foreign keys
*/

-- ============================================
-- PASO 6: VERIFICAR FOREIGN KEYS
-- ============================================

-- Ver todos los constraints de la tabla users
SELECT
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.table_name = 'users' AND tc.table_schema = 'public';

-- ============================================
-- PASO 7: LIMPIAR DATOS DE PRUEBA (OPCIONAL)
-- ============================================

-- CUIDADO: Esto eliminará TODOS los usuarios
-- Solo ejecutar en ambiente de desarrollo

-- DELETE FROM household_members WHERE user_id IN (SELECT id FROM users);
-- DELETE FROM households WHERE owner_user_id IN (SELECT id FROM users);
-- DELETE FROM users;

-- ============================================
-- RESULTADO ESPERADO
-- ============================================

-- Después de ejecutar este script:
-- ✅ users.id no tiene DEFAULT (acepta UUIDs de auth)
-- ✅ users.email es UNIQUE
-- ✅ Índices creados para performance
-- ✅ La app puede insertar con client.auth.currentUser.id
