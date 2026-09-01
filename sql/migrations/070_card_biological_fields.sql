-- ==========================================
--  MIGRACIÓN: Agregar campos para reverso de cartas
--  Fecha: 2025-12-16
--  Propósito: Eliminar hardcoding de datos biológicos en cartas
--  Enfoque: Campos simples de texto libre para máxima flexibilidad
-- ==========================================

-- Agregar campos para el reverso de la carta
ALTER TABLE cards 
  ADD COLUMN IF NOT EXISTS scientific_name text,
  ADD COLUMN IF NOT EXISTS technical_data text,
  ADD COLUMN IF NOT EXISTS curiosities text,
  ADD COLUMN IF NOT EXISTS card_type text CHECK (card_type IN ('fauna', 'flora'));

-- Índices para búsquedas optimizadas
CREATE INDEX IF NOT EXISTS idx_cards_scientific_name ON cards(scientific_name);
CREATE INDEX IF NOT EXISTS idx_cards_card_type ON cards(card_type);

-- Comentarios para documentación de la BD
COMMENT ON COLUMN cards.scientific_name IS 'Nombre científico en latín (ej: Hippocamelus bisulcus)';
COMMENT ON COLUMN cards.description IS 'Descripción general de la especie';
COMMENT ON COLUMN cards.technical_data IS 'Datos técnicos en formato libre multilínea. Ejemplo:
Familia: Cervidae
Peso: 70-90 kg
Altura: 1.5-1.7 m
Dieta: Herbívoro
Estado de conservación: En Peligro
Esperanza de vida: 12-15 años';
COMMENT ON COLUMN cards.curiosities IS 'Curiosidades o datos interesantes en formato libre multilínea';
COMMENT ON COLUMN cards.card_type IS 'Tipo de carta: fauna (animales) o flora (plantas)';

-- Verificación de migración
DO $$
BEGIN
  RAISE NOTICE '✅ Migración completada: cards ahora tiene % columnas', 
    (SELECT count(*) FROM information_schema.columns WHERE table_name = 'cards');
  RAISE NOTICE '📝 Campos agregados: scientific_name, technical_data, curiosities';
END $$;
