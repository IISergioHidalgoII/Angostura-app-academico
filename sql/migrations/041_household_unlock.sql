-- =====================================================
-- SOLO LA FUNCIÓN RPC PARA DESBLOQUEAR HOUSEHOLD
-- Ejecuta esto en Supabase Dashboard -> SQL Editor
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
  v_member_id TEXT;
  v_unlocked_count INT := 0;
BEGIN
  -- Desbloquear carta para todos los miembros del household
  FOR v_member_id IN 
    SELECT user_id::text FROM household_members WHERE household_id = p_household_id
  LOOP
    -- Verificar si ya tiene la carta (user_id es TEXT)
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
-- VERIFICAR que se creó correctamente
-- =====================================================
SELECT 
  proname as "Función",
  pg_get_function_arguments(oid) as "Argumentos"
FROM pg_proc 
WHERE proname = 'unlock_card_for_household';

-- Debe devolver 1 fila con:
-- Función: unlock_card_for_household
-- Argumentos: p_household_id uuid, p_card_id uuid
