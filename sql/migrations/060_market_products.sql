-- Script para corregir la tabla products_items
-- Cambiar la referencia de cards a market_items

-- 1. Eliminar la tabla anterior si existe (cuidado: esto borra datos)
DROP TABLE IF EXISTS products_items CASCADE;

-- 2. Crear la tabla products_items correctamente referenciando market_items
CREATE TABLE products_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  market_item_id uuid NOT NULL REFERENCES market_items(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  image_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 3. Índice para búsquedas por market_item
CREATE INDEX idx_products_items_market_item_id ON products_items(market_item_id);

-- 4. Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_products_items_updated_at
  BEFORE UPDATE ON products_items
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 5. Comentarios para documentación
COMMENT ON TABLE products_items IS 'Productos individuales asociados a emprendimientos del mercado';
COMMENT ON COLUMN products_items.market_item_id IS 'Referencia al emprendimiento (market_items)';
COMMENT ON COLUMN products_items.name IS 'Nombre del producto';
COMMENT ON COLUMN products_items.description IS 'Descripción detallada del producto';
COMMENT ON COLUMN products_items.image_url IS 'URL de la imagen del producto en Supabase Storage';

-- 6. Habilitar Row Level Security (RLS)
ALTER TABLE products_items ENABLE ROW LEVEL SECURITY;

-- 7. Políticas de seguridad (todos pueden leer, solo autenticados pueden modificar)
CREATE POLICY "Productos visibles públicamente"
  ON products_items FOR SELECT
  USING (true);

CREATE POLICY "Usuarios autenticados pueden insertar productos"
  ON products_items FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Usuarios autenticados pueden actualizar productos"
  ON products_items FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Usuarios autenticados pueden eliminar productos"
  ON products_items FOR DELETE
  TO authenticated
  USING (true);

-- Ejemplo de inserción
-- INSERT INTO products_items (market_item_id, name, description, image_url) 
-- VALUES ('uuid-de-market-item', 'Llavero artesanal', 'Hecho a mano con madera local', 'https://ejemplo.com/llavero.jpg');
