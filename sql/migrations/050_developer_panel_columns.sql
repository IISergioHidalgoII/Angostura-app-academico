-- ============================================================================
-- MIGRACIÓN CONSOLIDADA: Arreglar todas las tablas para Developer Panel
-- ============================================================================
-- Este script agrega TODAS las columnas faltantes en las tablas que 
-- el Developer Panel necesita para funcionar correctamente.
--
-- INSTRUCCIONES:
-- 1. Abrir Supabase Dashboard → SQL Editor
-- 2. Copiar y pegar TODO este archivo
-- 3. Ejecutar (Run)
-- 4. Verificar los mensajes NOTICE para confirmar que se ejecutó correctamente
-- ============================================================================

-- ============================================================================
-- 1. TABLA CARDS: Agregar description, image_url, is_active
-- ============================================================================

DO $$ 
BEGIN
  -- Agregar description
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cards' AND column_name = 'description'
  ) THEN
    ALTER TABLE cards ADD COLUMN description text;
    RAISE NOTICE '✅ Columna description agregada a cards';
  ELSE
    RAISE NOTICE 'ℹ️  Columna description ya existe en cards';
  END IF;

  -- Agregar image_url
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cards' AND column_name = 'image_url'
  ) THEN
    ALTER TABLE cards ADD COLUMN image_url text;
    RAISE NOTICE '✅ Columna image_url agregada a cards';
  ELSE
    RAISE NOTICE 'ℹ️  Columna image_url ya existe en cards';
  END IF;

  -- Agregar is_active
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cards' AND column_name = 'is_active'
  ) THEN
    ALTER TABLE cards ADD COLUMN is_active boolean NOT NULL DEFAULT true;
    RAISE NOTICE '✅ Columna is_active agregada a cards';
  ELSE
    RAISE NOTICE 'ℹ️  Columna is_active ya existe en cards';
  END IF;
END $$;

-- Actualizar cartas existentes sin is_active
UPDATE cards SET is_active = true WHERE is_active IS NULL;

-- ============================================================================
-- 2. TABLA SEASONS: Agregar description
-- ============================================================================

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'seasons' AND column_name = 'description'
  ) THEN
    ALTER TABLE seasons ADD COLUMN description text;
    RAISE NOTICE '✅ Columna description agregada a seasons';
  ELSE
    RAISE NOTICE 'ℹ️  Columna description ya existe en seasons';
  END IF;
END $$;

-- ============================================================================
-- 3. TABLA AREAS: Agregar image_url
-- ============================================================================

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'areas' AND column_name = 'image_url'
  ) THEN
    ALTER TABLE areas ADD COLUMN image_url text;
    RAISE NOTICE '✅ Columna image_url agregada a areas';
  ELSE
    RAISE NOTICE 'ℹ️  Columna image_url ya existe en areas';
  END IF;
END $$;

-- ============================================================================
-- 4. TABLA MARKET_ITEMS: Eliminar price, agregar image_url, profile_image_url, category
-- ============================================================================

DO $$ 
BEGIN
  -- Eliminar columna price si existe
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'market_items' AND column_name = 'price'
  ) THEN
    ALTER TABLE market_items DROP COLUMN price;
    RAISE NOTICE '✅ Columna price eliminada de market_items';
  ELSE
    RAISE NOTICE 'ℹ️  Columna price no existe en market_items (ya fue eliminada)';
  END IF;

  -- Agregar image_url
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'market_items' AND column_name = 'image_url'
  ) THEN
    ALTER TABLE market_items ADD COLUMN image_url text;
    RAISE NOTICE '✅ Columna image_url agregada a market_items';
  ELSE
    RAISE NOTICE 'ℹ️  Columna image_url ya existe en market_items';
  END IF;

  -- Agregar profile_image_url
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'market_items' AND column_name = 'profile_image_url'
  ) THEN
    ALTER TABLE market_items ADD COLUMN profile_image_url text;
    RAISE NOTICE '✅ Columna profile_image_url agregada a market_items';
  ELSE
    RAISE NOTICE 'ℹ️  Columna profile_image_url ya existe en market_items';
  END IF;

  -- Agregar category
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'market_items' AND column_name = 'category'
  ) THEN
    ALTER TABLE market_items ADD COLUMN category text;
    RAISE NOTICE '✅ Columna category agregada a market_items';
  ELSE
    RAISE NOTICE 'ℹ️  Columna category ya existe en market_items';
  END IF;
END $$;

-- ============================================================================
-- 5. CREAR ÍNDICES para mejorar rendimiento
-- ============================================================================

-- Índices para cards
CREATE INDEX IF NOT EXISTS idx_cards_season_id ON cards(season_id);
CREATE INDEX IF NOT EXISTS idx_cards_is_active ON cards(is_active);
CREATE INDEX IF NOT EXISTS idx_cards_code ON cards(code);

-- Índices para seasons
CREATE INDEX IF NOT EXISTS idx_seasons_is_active ON seasons(is_active);
CREATE INDEX IF NOT EXISTS idx_seasons_dates ON seasons(start_date, end_date);

-- Índices para market_items
CREATE INDEX IF NOT EXISTS idx_market_items_is_active ON market_items(is_active);
CREATE INDEX IF NOT EXISTS idx_market_items_category ON market_items(category);

-- Los índices anteriores se crean o verifican de forma idempotente.

-- ============================================================================
-- VERIFICACIÓN FINAL
-- ============================================================================

DO $$
DECLARE
  cards_cols text;
  seasons_cols text;
  areas_cols text;
  market_cols text;
BEGIN
  -- Verificar cards
  SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
  INTO cards_cols
  FROM information_schema.columns
  WHERE table_name = 'cards';
  
  RAISE NOTICE '📊 Columnas en CARDS: %', cards_cols;

  -- Verificar seasons
  SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
  INTO seasons_cols
  FROM information_schema.columns
  WHERE table_name = 'seasons';
  
  RAISE NOTICE '📊 Columnas en SEASONS: %', seasons_cols;

  -- Verificar areas
  SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
  INTO areas_cols
  FROM information_schema.columns
  WHERE table_name = 'areas';
  
  RAISE NOTICE '📊 Columnas en AREAS: %', areas_cols;

  -- Verificar market_items
  SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
  INTO market_cols
  FROM information_schema.columns
  WHERE table_name = 'market_items';
  
  RAISE NOTICE '📊 Columnas en MARKET_ITEMS: %', market_cols;

  RAISE NOTICE '✅✅✅ MIGRACIÓN COMPLETADA ✅✅✅';
  RAISE NOTICE 'Ahora puedes reiniciar tu aplicación Flutter';
END $$;
