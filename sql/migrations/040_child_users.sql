-- =====================================================
-- PASO 1: Crear solo la tabla child_users
-- =====================================================

CREATE TABLE IF NOT EXISTS child_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  parent_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  display_name TEXT NOT NULL DEFAULT 'Invitado',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_active_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_child_users_household 
ON child_users(household_id);


-- =====================================================
-- PASO 2: Agregar columna child_user_id a user_cards
-- =====================================================

-- Hacer user_id nullable (para permitir child_user_id)
ALTER TABLE user_cards 
ALTER COLUMN user_id DROP NOT NULL;

-- Agregar columna child_user_id
ALTER TABLE user_cards 
ADD COLUMN IF NOT EXISTS child_user_id UUID REFERENCES child_users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_user_cards_child 
ON user_cards(child_user_id);

-- Constraint: debe tener user_id O child_user_id
ALTER TABLE user_cards
DROP CONSTRAINT IF EXISTS user_cards_owner_check;

ALTER TABLE user_cards
ADD CONSTRAINT user_cards_owner_check 
CHECK (
  (user_id IS NOT NULL AND child_user_id IS NULL) OR
  (user_id IS NULL AND child_user_id IS NOT NULL)
);


-- =====================================================
-- PASO 3: Función RPC para crear child_users
-- =====================================================

CREATE OR REPLACE FUNCTION create_child_user(
  p_family_code TEXT,
  p_display_name TEXT DEFAULT 'Invitado'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_household_id UUID;
  v_child_user_id UUID;
BEGIN
  -- Validar código familiar
  SELECT id INTO v_household_id
  FROM households
  WHERE redeem_code = p_family_code
  AND activated_at IS NOT NULL;

  IF v_household_id IS NULL THEN
    RAISE EXCEPTION 'Código familiar inválido';
  END IF;

  -- Crear child_user (sin parent_user_id por ahora)
  INSERT INTO child_users (household_id, display_name)
  VALUES (v_household_id, p_display_name)
  RETURNING id INTO v_child_user_id;

  -- Retornar resultado
  RETURN json_build_object(
    'success', true,
    'child_user_id', v_child_user_id,
    'household_id', v_household_id,
    'display_name', p_display_name
  );
END;
$$;

GRANT EXECUTE ON FUNCTION create_child_user(TEXT, TEXT) TO anon, authenticated;


-- =====================================================
-- PASO 3B: Función para desbloquear carta a miembros del household
-- =====================================================

CREATE OR REPLACE FUNCTION unlock_card_for_household(
  p_household_id UUID,
  p_card_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_member_id UUID;
  v_unlocked_count INT := 0;
BEGIN
  -- Desbloquear carta para todos los miembros del household
  FOR v_member_id IN 
    SELECT user_id FROM household_members WHERE household_id = p_household_id
  LOOP
    -- Verificar si ya tiene la carta
    IF NOT EXISTS (
      SELECT 1 FROM user_cards 
      WHERE user_id = v_member_id AND card_id = p_card_id
    ) THEN
      -- Insertar carta
      INSERT INTO user_cards (user_id, card_id, source)
      VALUES (v_member_id, p_card_id, 'guest_unlock');
      
      v_unlocked_count := v_unlocked_count + 1;
    END IF;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'unlocked_count', v_unlocked_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION unlock_card_for_household(UUID, UUID) TO anon, authenticated;


-- =====================================================
-- PASO 4: Políticas RLS básicas
-- =====================================================

-- Permitir que cualquiera inserte en user_cards con child_user_id
DROP POLICY IF EXISTS "user_cards_child_insert" ON user_cards;
CREATE POLICY "user_cards_child_insert" 
ON user_cards FOR INSERT
WITH CHECK (child_user_id IS NOT NULL);

-- Permitir ver cartas con child_user_id (sin autenticación)
DROP POLICY IF EXISTS "user_cards_child_select" ON user_cards;
CREATE POLICY "user_cards_child_select" 
ON user_cards FOR SELECT
USING (child_user_id IS NOT NULL);


-- Verificar:
-- SELECT create_child_user('FAM-CC8E4', 'Guest Test');
-- SELECT * FROM child_users;
