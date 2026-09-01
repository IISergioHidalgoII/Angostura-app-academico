-- ==========================================
--  SISTEMA COMPLETO DE HOUSEHOLDS/FAMILIAS
--  Incluye verificación por email y OTP
-- ==========================================

-- 1. Agregar campos de verificación a la tabla households
ALTER TABLE households 
ADD COLUMN IF NOT EXISTS verified boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS verification_code text,
ADD COLUMN IF NOT EXISTS verification_code_expires_at timestamptz,
ADD COLUMN IF NOT EXISTS verification_code_sent_at timestamptz;

-- 2. Crear índices para optimizar búsquedas
CREATE INDEX IF NOT EXISTS idx_households_redeem_code ON households(redeem_code);
CREATE INDEX IF NOT EXISTS idx_households_owner ON households(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_household_members_user ON household_members(user_id);
CREATE INDEX IF NOT EXISTS idx_household_members_household ON household_members(household_id);

-- 3. Función para generar código único de grupo (FAM-XXXXX)
CREATE OR REPLACE FUNCTION generate_family_code(prefix text DEFAULT 'FAM')
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  code text;
  exists_code boolean;
BEGIN
  LOOP
    -- Generar código alfanumérico: FAM-XXXXX (5 caracteres)
    code := prefix || '-' || upper(substring(md5(random()::text) from 1 for 5));
    
    -- Verificar si ya existe
    SELECT EXISTS(SELECT 1 FROM households WHERE redeem_code = code) INTO exists_code;
    
    -- Si no existe, retornar
    IF NOT exists_code THEN
      RETURN code;
    END IF;
  END LOOP;
END;
$$;

-- 4. Función para generar código de verificación (6 dígitos)
CREATE OR REPLACE FUNCTION generate_verification_code()
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  -- Generar código de 6 dígitos
  RETURN lpad(floor(random() * 1000000)::text, 6, '0');
END;
$$;

-- 5. RPC: Crear household para el owner (padre)
CREATE OR REPLACE FUNCTION create_household_for_owner(
  p_site_id uuid,
  p_household_name text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_user_email text;
  v_household_id uuid;
  v_family_code text;
  v_verification_code text;
  v_household_name text;
  v_existing_household_id uuid;
  v_result json;
BEGIN
  -- [HOUSEHOLD] create:start
  RAISE LOG '[HOUSEHOLD] create:start - user: %', auth.uid();
  
  -- 1. Obtener usuario actual
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '[HOUSEHOLD] create:error - No authenticated user';
  END IF;
  
  -- Obtener email del usuario
  SELECT email INTO v_user_email FROM auth.users WHERE id = v_user_id;
  RAISE LOG '[HOUSEHOLD] create:user_info - id: %, email: %', v_user_id, v_user_email;
  
  -- 2. Verificar si el usuario ya tiene un household como owner
  SELECT id INTO v_existing_household_id
  FROM households
  WHERE owner_user_id = v_user_id
  LIMIT 1;
  
  -- Si ya existe, retornar el existente
  IF v_existing_household_id IS NOT NULL THEN
    RAISE LOG '[HOUSEHOLD] create:existing - household_id: %', v_existing_household_id;
    
    SELECT json_build_object(
      'household_id', h.id,
      'family_code', h.redeem_code,
      'household_name', h.name,
      'verified', h.verified,
      'created_at', h.created_at,
      'is_new', false
    )
    INTO v_result
    FROM households h
    WHERE h.id = v_existing_household_id;
    
    RAISE LOG '[HOUSEHOLD] create:success - returning existing household';
    RETURN v_result;
  END IF;
  
  -- 3. Generar códigos únicos
  v_family_code := generate_family_code('FAM');
  v_verification_code := generate_verification_code();
  
  -- Nombre del household
  v_household_name := COALESCE(
    p_household_name,
    'Familia de ' || COALESCE(split_part(v_user_email, '@', 1), 'Usuario')
  );
  
  RAISE LOG '[HOUSEHOLD] create:codes - family_code: %, verification_code: %', 
    v_family_code, v_verification_code;
  
  -- 4. Crear household
  INSERT INTO households (
    site_id,
    name,
    owner_user_id,
    redeem_code,
    verified,
    verification_code,
    verification_code_expires_at,
    verification_code_sent_at,
    activated_at
  ) VALUES (
    p_site_id,
    v_household_name,
    v_user_id,
    v_family_code,
    false, -- Inicialmente no verificado
    v_verification_code,
    now() + interval '24 hours', -- Expira en 24 horas
    now(),
    now()
  )
  RETURNING id INTO v_household_id;
  
  RAISE LOG '[HOUSEHOLD] create:household_inserted - id: %', v_household_id;
  
  -- 5. Agregar al owner como miembro
  INSERT INTO household_members (
    household_id,
    user_id,
    role,
    display_name,
    is_child
  ) VALUES (
    v_household_id,
    v_user_id,
    'owner',
    split_part(v_user_email, '@', 1),
    false
  );
  
  RAISE LOG '[HOUSEHOLD] create:member_inserted - user_id: %, role: owner', v_user_id;
  
  -- 6. Preparar resultado (incluye verification_code para enviar por email)
  -- NOTA: El código de verificación debe enviarse por email desde el cliente
  -- usando una Edge Function o servicio de email
  SELECT json_build_object(
    'household_id', v_household_id,
    'family_code', v_family_code,
    'household_name', v_household_name,
    'verified', false,
    'verification_code', v_verification_code,
    'verification_code_expires_at', now() + interval '24 hours',
    'owner_email', v_user_email,
    'created_at', now(),
    'is_new', true
  )
  INTO v_result;
  
  RAISE LOG '[HOUSEHOLD] create:success - household_id: %, family_code: %', 
    v_household_id, v_family_code;
  
  RETURN v_result;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE LOG '[HOUSEHOLD] create:error - %', SQLERRM;
    RAISE EXCEPTION '[HOUSEHOLD] Error creating household: %', SQLERRM;
END;
$$;

-- 6. RPC: Unirse a household existente (hijo/invitado)
CREATE OR REPLACE FUNCTION join_household_by_code(
  p_family_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_user_email text;
  v_household_id uuid;
  v_household_name text;
  v_existing_member_id uuid;
  v_result json;
BEGIN
  -- [HOUSEHOLD] join:start
  RAISE LOG '[HOUSEHOLD] join:start - user: %, code: %', auth.uid(), p_family_code;
  
  -- 1. Obtener usuario actual
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '[HOUSEHOLD] join:error - No authenticated user';
  END IF;
  
  -- Obtener email del usuario
  SELECT email INTO v_user_email FROM auth.users WHERE id = v_user_id;
  RAISE LOG '[HOUSEHOLD] join:user_info - id: %, email: %', v_user_id, v_user_email;
  
  -- 2. Buscar household por código
  SELECT id, name INTO v_household_id, v_household_name
  FROM households
  WHERE redeem_code = p_family_code
  AND activated_at IS NOT NULL
  LIMIT 1;
  
  IF v_household_id IS NULL THEN
    RAISE LOG '[HOUSEHOLD] join:error - Invalid code: %', p_family_code;
    RAISE EXCEPTION 'Código de familia inválido';
  END IF;
  
  RAISE LOG '[HOUSEHOLD] join:household_found - id: %, name: %', 
    v_household_id, v_household_name;
  
  -- 3. Verificar si el usuario ya es miembro
  SELECT id INTO v_existing_member_id
  FROM household_members
  WHERE household_id = v_household_id
  AND user_id = v_user_id
  LIMIT 1;
  
  IF v_existing_member_id IS NOT NULL THEN
    RAISE LOG '[HOUSEHOLD] join:already_member - member_id: %', v_existing_member_id;
    
    SELECT json_build_object(
      'household_id', v_household_id,
      'household_name', v_household_name,
      'family_code', p_family_code,
      'role', 'member',
      'is_new_member', false,
      'message', 'Ya eres miembro de este grupo'
    )
    INTO v_result;
    
    RETURN v_result;
  END IF;
  
  -- 4. Agregar como miembro
  INSERT INTO household_members (
    household_id,
    user_id,
    role,
    display_name,
    is_child
  ) VALUES (
    v_household_id,
    v_user_id,
    'member',
    split_part(v_user_email, '@', 1),
    false -- Por defecto no es hijo, puede cambiarse después
  );
  
  RAISE LOG '[HOUSEHOLD] join:member_added - user_id: %, household_id: %', 
    v_user_id, v_household_id;
  
  -- 5. Preparar resultado
  SELECT json_build_object(
    'household_id', v_household_id,
    'household_name', v_household_name,
    'family_code', p_family_code,
    'role', 'member',
    'is_new_member', true,
    'message', 'Te has unido exitosamente al grupo'
  )
  INTO v_result;
  
  RAISE LOG '[HOUSEHOLD] join:success - household_id: %', v_household_id;
  
  RETURN v_result;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE LOG '[HOUSEHOLD] join:error - %', SQLERRM;
    RAISE EXCEPTION '[HOUSEHOLD] Error joining household: %', SQLERRM;
END;
$$;

-- 7. RPC: Verificar household con código OTP
CREATE OR REPLACE FUNCTION verify_household_code(
  p_household_id uuid,
  p_verification_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_stored_code text;
  v_expires_at timestamptz;
  v_is_owner boolean;
  v_result json;
BEGIN
  RAISE LOG '[HOUSEHOLD] verify:start - household: %, code: %', 
    p_household_id, p_verification_code;
  
  -- 1. Obtener usuario actual
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No authenticated user';
  END IF;
  
  -- 2. Verificar que el usuario sea el owner del household
  SELECT EXISTS(
    SELECT 1 FROM households 
    WHERE id = p_household_id 
    AND owner_user_id = v_user_id
  ) INTO v_is_owner;
  
  IF NOT v_is_owner THEN
    RAISE LOG '[HOUSEHOLD] verify:error - User is not owner';
    RAISE EXCEPTION 'Solo el propietario puede verificar el grupo';
  END IF;
  
  -- 3. Obtener código almacenado y fecha de expiración
  SELECT verification_code, verification_code_expires_at
  INTO v_stored_code, v_expires_at
  FROM households
  WHERE id = p_household_id;
  
  -- 4. Validar código
  IF v_stored_code IS NULL THEN
    RAISE EXCEPTION 'No hay código de verificación para este grupo';
  END IF;
  
  IF v_expires_at < now() THEN
    RAISE LOG '[HOUSEHOLD] verify:error - Code expired';
    RAISE EXCEPTION 'El código de verificación ha expirado';
  END IF;
  
  IF v_stored_code != p_verification_code THEN
    RAISE LOG '[HOUSEHOLD] verify:error - Invalid code';
    RAISE EXCEPTION 'Código de verificación incorrecto';
  END IF;
  
  -- 5. Marcar como verificado
  UPDATE households
  SET 
    verified = true,
    verification_code = NULL, -- Limpiar código usado
    verification_code_expires_at = NULL
  WHERE id = p_household_id;
  
  RAISE LOG '[HOUSEHOLD] verify:success - household: %', p_household_id;
  
  SELECT json_build_object(
    'success', true,
    'verified', true,
    'message', 'Grupo verificado exitosamente'
  )
  INTO v_result;
  
  RETURN v_result;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE LOG '[HOUSEHOLD] verify:error - %', SQLERRM;
    RAISE EXCEPTION 'Error verifying household: %', SQLERRM;
END;
$$;

-- 8. RPC: Reenviar código de verificación
CREATE OR REPLACE FUNCTION resend_verification_code(
  p_household_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_user_email text;
  v_new_code text;
  v_is_owner boolean;
  v_result json;
BEGIN
  RAISE LOG '[HOUSEHOLD] resend:start - household: %', p_household_id;
  
  -- 1. Obtener usuario actual
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No authenticated user';
  END IF;
  
  -- 2. Verificar que el usuario sea el owner
  SELECT EXISTS(
    SELECT 1 FROM households 
    WHERE id = p_household_id 
    AND owner_user_id = v_user_id
  ) INTO v_is_owner;
  
  IF NOT v_is_owner THEN
    RAISE EXCEPTION 'Solo el propietario puede reenviar el código';
  END IF;
  
  -- 3. Obtener email del owner
  SELECT email INTO v_user_email FROM auth.users WHERE id = v_user_id;
  
  -- 4. Generar nuevo código
  v_new_code := generate_verification_code();
  
  -- 5. Actualizar household
  UPDATE households
  SET 
    verification_code = v_new_code,
    verification_code_expires_at = now() + interval '24 hours',
    verification_code_sent_at = now()
  WHERE id = p_household_id;
  
  RAISE LOG '[HOUSEHOLD] resend:success - new code generated';
  
  SELECT json_build_object(
    'success', true,
    'verification_code', v_new_code,
    'verification_code_expires_at', now() + interval '24 hours',
    'owner_email', v_user_email,
    'message', 'Código reenviado exitosamente'
  )
  INTO v_result;
  
  RETURN v_result;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE LOG '[HOUSEHOLD] resend:error - %', SQLERRM;
    RAISE EXCEPTION 'Error resending verification code: %', SQLERRM;
END;
$$;

-- 9. RPC: Obtener información completa del household del usuario actual
CREATE OR REPLACE FUNCTION get_my_household_info()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_result json;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN NULL;
  END IF;
  
  SELECT json_build_object(
    'household_id', h.id,
    'household_name', h.name,
    'family_code', h.redeem_code,
    'verified', h.verified,
    'role', hm.role,
    'is_child', hm.is_child,
    'is_owner', hm.role = 'owner',
    'member_count', (
      SELECT count(*) FROM household_members 
      WHERE household_id = h.id
    ),
    'created_at', h.created_at
  )
  INTO v_result
  FROM household_members hm
  JOIN households h ON h.id = hm.household_id
  WHERE hm.user_id = v_user_id
  LIMIT 1;
  
  RETURN v_result;
END;
$$;

-- 10. Políticas RLS (Row Level Security)
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE household_members ENABLE ROW LEVEL SECURITY;

-- Policies para households
DROP POLICY IF EXISTS "Users can view their own household" ON households;
CREATE POLICY "Users can view their own household"
  ON households FOR SELECT
  USING (
    owner_user_id = auth.uid() OR
    id IN (
      SELECT household_id FROM household_members 
      WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update their own household" ON households;
CREATE POLICY "Users can update their own household"
  ON households FOR UPDATE
  USING (owner_user_id = auth.uid());

-- Policies para household_members
DROP POLICY IF EXISTS "Users can view members of their household" ON household_members;
CREATE POLICY "Users can view members of their household"
  ON household_members FOR SELECT
  USING (
    user_id = auth.uid() OR
    household_id IN (
      SELECT household_id FROM household_members 
      WHERE user_id = auth.uid()
    )
  );

-- 11. Comentarios para documentación
COMMENT ON FUNCTION create_household_for_owner IS 
'Crea un household para el owner (padre). Si ya existe, retorna el existente. Genera códigos de familia y verificación.';

COMMENT ON FUNCTION join_household_by_code IS 
'Permite a un usuario unirse a un household existente usando el código de familia.';

COMMENT ON FUNCTION verify_household_code IS 
'Verifica un household usando el código OTP enviado por email. Solo el owner puede verificar.';

COMMENT ON FUNCTION resend_verification_code IS 
'Regenera y reenvía el código de verificación. Solo el owner puede solicitar reenvío.';

COMMENT ON FUNCTION get_my_household_info IS 
'Obtiene información completa del household del usuario actual.';

-- FIN DEL SCRIPT
