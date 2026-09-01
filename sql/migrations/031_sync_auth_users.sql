-- Sincroniza Supabase Auth con el perfil público de la aplicación.
-- Requiere: bootstrap/001_base_schema.sql y migrations/030_prepare_user_profiles.sql.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_email_local text;
  v_display_name text;
  v_username text;
BEGIN
  v_email_local := NULLIF(split_part(COALESCE(NEW.email, ''), '@', 1), '');
  v_display_name := COALESCE(
    NULLIF(NEW.raw_user_meta_data ->> 'display_name', ''),
    v_email_local,
    'Usuario'
  );

  -- El sufijo derivado del UUID evita carreras al generar usernames.
  v_username := lower(
    regexp_replace(
      COALESCE(
        NULLIF(NEW.raw_user_meta_data ->> 'username', ''),
        v_email_local,
        'usuario'
      ),
      '[^a-zA-Z0-9_]+',
      '_',
      'g'
    )
  ) || '_' || left(replace(NEW.id::text, '-', ''), 8);

  INSERT INTO public.users (
    id, email, display_name, username, created_at, updated_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    v_display_name,
    v_username,
    COALESCE(NEW.created_at, now()),
    now()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    display_name = COALESCE(public.users.display_name, EXCLUDED.display_name),
    username = COALESCE(public.users.username, EXCLUDED.username),
    updated_at = now();

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Sincroniza cuentas existentes que todavía no tienen perfil público.
INSERT INTO public.users (
  id, email, display_name, username, created_at, updated_at
)
SELECT
  au.id,
  au.email,
  COALESCE(
    NULLIF(au.raw_user_meta_data ->> 'display_name', ''),
    NULLIF(split_part(COALESCE(au.email, ''), '@', 1), ''),
    'Usuario'
  ),
  lower(
    regexp_replace(
      COALESCE(
        NULLIF(au.raw_user_meta_data ->> 'username', ''),
        NULLIF(split_part(COALESCE(au.email, ''), '@', 1), ''),
        'usuario'
      ),
      '[^a-zA-Z0-9_]+',
      '_',
      'g'
    )
  ) || '_' || left(replace(au.id::text, '-', ''), 8),
  au.created_at,
  now()
FROM auth.users AS au
LEFT JOIN public.users AS pu ON pu.id = au.id
WHERE pu.id IS NULL
ON CONFLICT (id) DO NOTHING;

DO $$
DECLARE
  v_missing_count bigint;
BEGIN
  SELECT count(*)
  INTO v_missing_count
  FROM auth.users AS au
  LEFT JOIN public.users AS pu ON pu.id = au.id
  WHERE pu.id IS NULL;

  IF v_missing_count > 0 THEN
    RAISE WARNING 'Quedan % cuentas de auth sin perfil público', v_missing_count;
  ELSE
    RAISE NOTICE 'Todas las cuentas de auth tienen perfil público';
  END IF;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user() IS
'Crea el perfil public.users después de insertar una cuenta en auth.users.';
