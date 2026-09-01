-- ============================================================================
-- MIGRACIÓN: Agregar campos faltantes a tabla cards
-- ============================================================================
-- Este script agrega columnas description e image_url a la tabla cards existente
-- sin eliminar los datos actuales.
--
-- CÓMO EJECUTAR:
-- 1. Abrir el panel SQL de Supabase (https://supabase.com/dashboard)
-- 2. Ir a: SQL Editor
-- 3. Copiar y pegar este archivo completo
-- 4. Ejecutar (Run)
-- ============================================================================

-- Agregar columna description si no existe
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cards' AND column_name = 'description'
  ) THEN
    ALTER TABLE cards ADD COLUMN description text;
    RAISE NOTICE 'Columna description agregada a cards';
  ELSE
    RAISE NOTICE 'Columna description ya existe en cards';
  END IF;
END $$;

-- Agregar columna image_url si no existe
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cards' AND column_name = 'image_url'
  ) THEN
    ALTER TABLE cards ADD COLUMN image_url text;
    RAISE NOTICE 'Columna image_url agregada a cards';
  ELSE
    RAISE NOTICE 'Columna image_url ya existe en cards';
  END IF;
END $$;

-- Agregar columna is_active si no existe
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cards' AND column_name = 'is_active'
  ) THEN
    ALTER TABLE cards ADD COLUMN is_active boolean NOT NULL DEFAULT true;
    RAISE NOTICE 'Columna is_active agregada a cards';
  ELSE
    RAISE NOTICE 'Columna is_active ya existe en cards';
  END IF;
END $$;

-- ============================================================================
-- ACTUALIZAR DESCRIPCIONES PARA CARTAS EXISTENTES
-- ============================================================================
-- Agregar descripciones a las 3 cartas que ya existen en tu BD

UPDATE cards 
SET description = 'La tagua común (Fulica armillata) es un ave acuática muy común en humedales del sur de Chile. Se caracteriza por su plumaje negro, pico amarillo con escudo frontal rojo. Se alimenta principalmente de plantas acuáticas.'
WHERE code = 'ANG001' AND description IS NULL;

UPDATE cards 
SET description = 'El cisne de cuello negro (Cygnus melancoryphus) es una especie endémica de Sudamérica. Se distingue por su cuello negro contrastante con el cuerpo blanco. Habita en lagunas y humedales, formando parejas de por vida.'
WHERE code = 'ANG002' AND description IS NULL;

UPDATE cards 
SET description = 'El flamenco chileno (Phoenicopterus chilensis) es un ave filtrador que habita en lagunas salinas y humedales costeros. Su característico color rosado proviene de los pigmentos de los crustáceos que consume. Forman grandes colonias reproductivas.'
WHERE code = 'ANG003' AND description IS NULL;

-- Actualizar is_active para todas las cartas existentes
UPDATE cards SET is_active = true WHERE is_active IS NULL;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================
-- Ver estructura actualizada de la tabla cards
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'cards'
ORDER BY ordinal_position;

-- Ver las cartas actualizadas
SELECT id, code, title, rarity, 
       CASE 
         WHEN description IS NULL THEN '[Sin descripción]'
         ELSE LEFT(description, 50) || '...'
       END as description_preview,
       is_active
FROM cards
ORDER BY code;

-- ============================================================================
-- FIN DE LA MIGRACIÓN
-- ============================================================================
