-- ==========================================
--  ACTUALIZACIÓN DE ROLES DE USUARIO
-- ==========================================

-- Este script actualiza la documentación y estructura de roles
-- en el sistema de households

-- Roles disponibles en household_members.role:
-- 'owner'  : Padre/Madre que crea el grupo familiar (puede administrar)
-- 'member' : Miembro adulto del household (puede participar)
-- 'child'  : Hijo/menor (member + is_child=true, con restricciones)
-- 'admin'  : Administrador del parque (staff)

-- NOTA: El campo is_child tiene prioridad sobre role para determinar
-- si un usuario tiene restricciones de edad

-- Actualizar comentarios de la tabla
COMMENT ON COLUMN household_members.role IS 
'Rol del usuario en el household: owner (padre/creador), member (miembro adulto), child (hijo con restricciones), admin (staff del parque)';

COMMENT ON COLUMN household_members.is_child IS 
'Indica si es cuenta de hijo (true = restricciones en recompensas y funcionalidades). Tiene prioridad sobre el campo role.';

-- Crear índices para mejorar consultas de roles
CREATE INDEX IF NOT EXISTS idx_household_members_role 
ON household_members(role);

CREATE INDEX IF NOT EXISTS idx_household_members_is_child 
ON household_members(is_child) 
WHERE is_child = true;

-- Ver distribución de roles actual
SELECT 
  role,
  is_child,
  COUNT(*) as total_usuarios,
  CASE 
    WHEN is_child = true THEN 'Hijo/Hija'
    WHEN role = 'owner' THEN 'Padre/Madre'
    WHEN role = 'member' THEN 'Miembro Adulto'
    WHEN role = 'admin' THEN 'Administrador'
    ELSE 'Otro'
  END as tipo_usuario
FROM household_members
GROUP BY role, is_child
ORDER BY total_usuarios DESC;

-- Función helper para obtener el tipo de usuario legible
CREATE OR REPLACE FUNCTION get_user_type(p_role text, p_is_child boolean)
RETURNS text AS $$
BEGIN
  IF p_is_child THEN
    RETURN 'child';
  END IF;
  
  RETURN p_role;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Ejemplo de uso:
-- SELECT 
--   display_name,
--   get_user_type(role, is_child) as user_type
-- FROM household_members;
