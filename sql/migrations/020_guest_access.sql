-- Función RPC para validar código sin RLS (evita recursión infinita)
CREATE OR REPLACE FUNCTION validate_family_code(p_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSON;
BEGIN
  -- Buscar household por código (sin RLS)
  SELECT json_build_object(
    'id', id,
    'name', name,
    'redeem_code', redeem_code
  ) INTO v_result
  FROM households
  WHERE redeem_code = p_code
  AND activated_at IS NOT NULL
  LIMIT 1;
  
  RETURN v_result;
END;
$$;

-- Permitir acceso a invitados y usuarios autenticados
GRANT EXECUTE ON FUNCTION validate_family_code(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION validate_family_code(TEXT) TO authenticated;
