-- ============================================================================
-- SCRIPT MAESTRO - SETUP COMPLETO ANGOSTURA BIOBÍO APP
-- ============================================================================
-- Este script configura la base de datos completa desde cero
-- Incluye: esquema, migraciones, datos de ejemplo
--
-- ORDEN DE EJECUCIÓN (recomendado):
-- 1. PARTE 1: Extensiones y esquema base
-- 2. PARTE 2: Migraciones (agregar campos faltantes)
-- 3. PARTE 3: Datos de ejemplo (sites, areas, cards, qr_tokens, market_items)
--
-- CÓMO EJECUTAR:
-- 1. Abrir SQL Editor en Supabase Dashboard
-- 2. Copiar y pegar TODO este archivo
-- 3. Ejecutar (Run)
-- ============================================================================


-- ============================================================================
-- PARTE 1: EXTENSIONES Y ESQUEMA BASE
-- ============================================================================

-- Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- TABLAS BASE DE CONTEXTO
-- ============================================================================

-- Sitios / parques (multi-park)
CREATE TABLE IF NOT EXISTS sites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  region text,
  description text,
  latitude double precision,
  longitude double precision,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Áreas dentro de cada sitio/parque
CREATE TABLE IF NOT EXISTS areas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id uuid REFERENCES sites(id),
  name text NOT NULL,
  description text,
  coordinates polygon,
  created_at timestamptz DEFAULT now()
);

-- Temporadas / eventos especiales
CREATE TABLE IF NOT EXISTS seasons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id uuid REFERENCES sites(id),
  name text NOT NULL,
  start_date timestamptz,
  end_date timestamptz,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- ============================================================================
-- USUARIOS Y GRUPOS (HOUSEHOLDS)
-- ============================================================================

-- USERS
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text UNIQUE,
  display_name text,
  email text,
  created_at timestamptz DEFAULT now()
);

-- HOUSEHOLDS (grupos familiares/escolares)
CREATE TABLE IF NOT EXISTS households (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id uuid REFERENCES sites(id),
  name text NOT NULL,
  owner_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  redeem_code text UNIQUE,
  activated_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- HOUSEHOLD MEMBERS (miembros del grupo)
CREATE TABLE IF NOT EXISTS household_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid REFERENCES households(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  role text,
  display_name text,
  is_child boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- RESERVATIONS (reservas ligadas a household/sitio)
CREATE TABLE IF NOT EXISTS reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid REFERENCES households(id),
  site_id uuid REFERENCES sites(id),
  reserved_at timestamptz,
  status text,
  created_at timestamptz DEFAULT now()
);

-- ============================================================================
-- CARTAS, QR Y REDEMPTIONS
-- ============================================================================

-- CARDS (coleccionables)
CREATE TABLE IF NOT EXISTS cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id uuid REFERENCES sites(id),
  area_id uuid REFERENCES areas(id),
  season_id uuid REFERENCES seasons(id),
  title text,
  code text UNIQUE,
  rarity text,
  created_at timestamptz DEFAULT now()
);

-- USER_CARDS (cartas desbloqueadas por usuario)
CREATE TABLE IF NOT EXISTS user_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL, -- Usa text para soportar 'guest-user-id' y UUIDs
  card_id uuid NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  source text NOT NULL DEFAULT 'qr',
  UNIQUE(user_id, card_id)
);

-- Índices de rendimiento para user_cards
CREATE INDEX IF NOT EXISTS idx_user_cards_user ON user_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_user_cards_card ON user_cards(card_id);
CREATE INDEX IF NOT EXISTS idx_user_cards_unlocked ON user_cards(unlocked_at DESC);

-- QR TOKENS (metadatos de QR)
CREATE TABLE IF NOT EXISTS qr_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id uuid REFERENCES sites(id),
  card_id uuid REFERENCES cards(id),
  qr_id text UNIQUE,
  nonce text,
  sig text,
  expires_at timestamptz,
  max_uses_per_user int DEFAULT 1,
  cooldown_days int DEFAULT 90,
  created_at timestamptz DEFAULT now()
);

-- REDEMPTIONS (escaneos)
CREATE TABLE IF NOT EXISTS redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid REFERENCES households(id),
  member_id uuid REFERENCES household_members(id),
  card_id uuid REFERENCES cards(id),
  qr_token_id uuid REFERENCES qr_tokens(id),
  lat double precision,
  lng double precision,
  created_at timestamptz DEFAULT now(),
  result text
);

-- ============================================================================
-- RECOMPENSAS Y REGLAS
-- ============================================================================

-- REWARDS (recompensas configurables)
CREATE TABLE IF NOT EXISTS rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id uuid REFERENCES sites(id),
  title text NOT NULL,
  description text,
  cost_points int,
  area_complete boolean DEFAULT false,
  household_only boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- REWARD REQUIREMENTS (reglas para desbloquear recompensas)
CREATE TABLE IF NOT EXISTS reward_requirements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reward_id uuid REFERENCES rewards(id) ON DELETE CASCADE,
  site_id uuid REFERENCES sites(id),
  area_id uuid NULL REFERENCES areas(id),
  season_id uuid NULL REFERENCES seasons(id),
  rarity text NULL,
  min_count int NULL
);

-- REWARD REDEEMS (canjes)
CREATE TABLE IF NOT EXISTS reward_redeems (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reward_id uuid REFERENCES rewards(id),
  household_id uuid REFERENCES households(id),
  code text,
  verified_by_staff_id uuid,
  used_at timestamptz,
  status text CHECK (status IN ('pending','verified','used','rejected')) DEFAULT 'pending',
  created_at timestamptz DEFAULT now()
);

-- VERIFICATION CODES (códigos de verificación para households)
CREATE TABLE IF NOT EXISTS verification_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  site_id uuid REFERENCES sites(id),
  issued_by uuid,
  max_uses int DEFAULT 1 CHECK (max_uses >= 1),
  uses int DEFAULT 0,
  expires_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- ============================================================================
-- SISTEMA DE PUNTOS Y CONFIGURACIÓN
-- ============================================================================

-- TRANSACCIONES DE PUNTOS
CREATE TABLE IF NOT EXISTS point_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid REFERENCES households(id),
  member_id uuid REFERENCES household_members(id),
  points_delta int,
  transaction_type text,
  reference_id uuid,
  description text,
  created_at timestamptz DEFAULT now()
);

-- CONFIGURACIÓN POR SITIO
CREATE TABLE IF NOT EXISTS site_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id uuid REFERENCES sites(id),
  key text,
  value jsonb,
  created_at timestamptz DEFAULT now()
);

-- LOG DE SINCRONIZACIÓN (opcional)
CREATE TABLE IF NOT EXISTS sync_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid,
  op_type text,
  payload jsonb,
  processed boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- ============================================================================
-- MARKET ITEMS (Emprendedores locales)
-- ============================================================================

CREATE TABLE IF NOT EXISTS market_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  price numeric(10,2),
  category text,
  contact_info text,
  location_label text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================================================
-- ÍNDICES DE RENDIMIENTO
-- ============================================================================

-- Redemptions
CREATE INDEX IF NOT EXISTS idx_redemptions_household_created ON redemptions (household_id, created_at);
CREATE INDEX IF NOT EXISTS ix_redemptions_household_card_time ON redemptions (household_id, card_id, created_at DESC);
CREATE INDEX IF NOT EXISTS brin_redemptions_created ON redemptions USING BRIN (created_at);

-- QR Tokens
CREATE INDEX IF NOT EXISTS idx_qr_tokens_qr_id ON qr_tokens (qr_id);

-- Cards
CREATE INDEX IF NOT EXISTS idx_cards_site_area_rarity ON cards (site_id, area_id, rarity);
CREATE INDEX IF NOT EXISTS idx_cards_site_season ON cards (site_id, season_id, rarity);
CREATE INDEX IF NOT EXISTS idx_cards_code ON cards(code);

-- Point transactions
CREATE INDEX IF NOT EXISTS idx_point_transactions_household ON point_transactions (household_id, created_at DESC);

-- Areas
CREATE INDEX IF NOT EXISTS idx_areas_site ON areas (site_id);

-- Market items
CREATE INDEX IF NOT EXISTS idx_market_items_active_created ON market_items (is_active, created_at DESC);

-- Restricción única: sólo un 'ok' por household + card
CREATE UNIQUE INDEX IF NOT EXISTS ux_household_card_ok ON redemptions (household_id, card_id) WHERE result = 'ok';

-- ============================================================================
-- FUNCIONES ÚTILES
-- ============================================================================

-- Calcular puntos totales de un household
CREATE OR REPLACE FUNCTION get_household_points(p_household_uuid uuid)
RETURNS integer AS $$
BEGIN
  RETURN COALESCE((
    SELECT SUM(points_delta)
    FROM point_transactions
    WHERE household_id = p_household_uuid
  ), 0);
END;
$$ LANGUAGE plpgsql;

-- Verificar cooldown de QR
CREATE OR REPLACE FUNCTION check_qr_cooldown(
  p_household_id uuid,
  p_card_id uuid,
  p_cooldown_days int
)
RETURNS boolean AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1
    FROM redemptions
    WHERE household_id = p_household_id
      AND card_id = p_card_id
      AND created_at > NOW() - INTERVAL '1 day' * p_cooldown_days
  );
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- PARTE 2: MIGRACIONES - AGREGAR CAMPOS FALTANTES A CARDS
-- ============================================================================

-- Agregar columna description
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cards' AND column_name = 'description'
  ) THEN
    ALTER TABLE cards ADD COLUMN description text;
  END IF;
END $$;

-- Agregar columna image_url
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cards' AND column_name = 'image_url'
  ) THEN
    ALTER TABLE cards ADD COLUMN image_url text;
  END IF;
END $$;

-- Agregar columna is_active
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cards' AND column_name = 'is_active'
  ) THEN
    ALTER TABLE cards ADD COLUMN is_active boolean NOT NULL DEFAULT true;
  END IF;
END $$;


-- ============================================================================
-- PARTE 3: DATOS DE EJEMPLO
-- ============================================================================

-- ============================================================================
-- 3.0 USUARIO INVITADO (para demo sin autenticación)
-- ============================================================================

-- NOTA: Como users.id es TEXT, podemos usar directamente 'guest-user-id'
-- No hay necesidad de INSERT aquí porque user_cards.user_id es TEXT y no tiene FK constraint
-- El usuario 'guest-user-id' se puede usar directamente sin insertar en users

-- ============================================================================
-- 3.1 SITIOS Y ÁREAS
-- ============================================================================

INSERT INTO sites (id, name, region, description, latitude, longitude, is_active) 
VALUES (
  '10000000-0000-0000-0000-000000000001'::uuid,
  'Parque Angostura',
  'Región del Biobío',
  'Zona cordillerana con embalse Colbún (el más grande de Chile), bosque nativo y biodiversidad de la precordillera del Biobío',
  -36.8269,
  -73.0562,
  true
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO areas (id, site_id, name, description) VALUES
  (
    '20000000-0000-0000-0000-000000000001'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    'Laguna Principal',
    'Zona del embalse Colbún, el más grande de Chile'
  ),
  (
    '20000000-0000-0000-0000-000000000002'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    'Sendero del Bosque',
    'Zona boscosa con especies nativas'
  ),
  (
    '20000000-0000-0000-0000-000000000003'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    'Mirador Norte',
    'Punto elevado para observación panorámica'
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 3.2 TEMPORADAS
-- ============================================================================

INSERT INTO seasons (id, site_id, name, start_date, end_date, is_active) VALUES (
  '30000000-0000-0000-0000-000000000001'::uuid,
  '10000000-0000-0000-0000-000000000001'::uuid,
  'Temporada Verano 2025-2026',
  '2025-12-21'::timestamptz,
  '2026-03-20'::timestamptz,
  true
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 3.3 CARTAS DE ESPECIES NATIVAS
-- ============================================================================

INSERT INTO cards (id, code, title, description, rarity, is_active, site_id, area_id, season_id)
VALUES
  (
    'c1a2b3c4-d5e6-47f8-9012-3456789abcde'::uuid,
    'ANG-CARD-001',
    'Carpintero Negro',
    'El carpintero negro (Campephilus magellanicus) es una de las aves más emblemáticas de los bosques nativos del sur de Chile. Reconocido por su distintivo plumaje negro con marcas rojas en la cabeza, puede alcanzar hasta 45 cm de longitud.',
    'común',
    true,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    NULL
  ),
  (
    'c2b3c4d5-e6f7-4890-a123-456789bcdef0'::uuid,
    'ANG-CARD-002',
    'Coigüe',
    'El coigüe (Nothofagus dombeyi) es un árbol nativo de gran altura que puede superar los 40 metros. Sus hojas perennes y su madera de alta calidad lo convierten en una especie fundamental del bosque templado lluvioso.',
    'común',
    true,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    NULL
  ),
  (
    'c3c4d5e6-f789-401a-b234-56789cdef012'::uuid,
    'ANG-CARD-003',
    'Pehuén (Araucaria)',
    'La araucaria (Araucaria araucana), conocida como pehuén por el pueblo mapuche, es un árbol milenario endémico de Chile y Argentina. Puede vivir más de 1.000 años y alcanzar 50 metros de altura. Sus piñones son alimento tradicional.',
    'épica',
    true,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    NULL
  ),
  (
    'c4d5e6f7-8901-42ab-c345-6789def01234'::uuid,
    'ANG-CARD-004',
    'Traro',
    'El traro (Caracara plancus) es un ave rapaz de tamaño mediano, muy adaptable y común en la región del Biobío. Se alimenta de carroña, pequeños mamíferos e insectos. Es fácil de reconocer por su cara desnuda de color naranja.',
    'común',
    true,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000003'::uuid,
    NULL
  ),
  (
    'c5e6f789-0123-44bc-d456-789ef0123456'::uuid,
    'ANG-CARD-005',
    'Zorro Culpeo',
    'El zorro culpeo (Lycalopex culpaeus) es el segundo cánido más grande de Sudamérica. Habita en diversos ambientes, desde bosques hasta zonas montañosas. Su pelaje rojizo-grisáceo y su cola espesa lo hacen inconfundible.',
    'rara',
    true,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    NULL
  ),
  (
    'c6f78901-2345-46cd-e567-89f012345678'::uuid,
    'ANG-CARD-006',
    'Copihue',
    'El copihue (Lapageria rosea) es la flor nacional de Chile. Esta enredadera nativa produce flores acampanadas de color rojo intenso (aunque también existen variedades blancas y rosadas). Crece en bosques húmedos y sombríos.',
    'rara',
    true,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    NULL
  ),
  (
    'c7890123-4567-48de-f678-90123456789a'::uuid,
    'ANG-CARD-007',
    'Huemul',
    'El huemul (Hippocamelus bisulcus) es uno de los dos ciervos nativos de Chile y símbolo nacional junto al cóndor. Habita en bosques y zonas cordilleranas de Los Andes. Está en peligro crítico de extinción con menos de 2.000 individuos silvestres. Los machos poseen cornamentas bifurcadas.',
    'épica',
    true,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    NULL
  ),
  (
    'c8901234-5678-490e-f789-0123456789ab'::uuid,
    'ANG-CARD-008',
    'Chucao',
    'El chucao (Scelorchilus rubecula) es un ave pequeña y esquiva de color rojizo característico de los bosques templados. Su canto distintivo es inconfundible: un "chucao, chucao" repetitivo que resuena en la espesura del bosque.',
    'rara',
    true,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    NULL
  ),
  (
    'c9012345-6789-40ab-cdef-0123456789bc'::uuid,
    'ANG-CARD-009',
    'Tagua Común',
    'La tagua común (Fulica armillata) es un ave acuática muy común en humedales del sur de Chile. Se caracteriza por su plumaje negro, pico amarillo con escudo frontal rojo. Se alimenta principalmente de plantas acuáticas.',
    'común',
    true,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    NULL
  ),
  (
    'ca123456-789a-4bcd-ef01-23456789abcd'::uuid,
    'ANG-CARD-010',
    'Cisne de Cuello Negro',
    'El cisne de cuello negro (Cygnus melancoryphus) es una especie endémica de Sudamérica. Se distingue por su cuello negro contrastante con el cuerpo blanco. Habita en lagunas y humedales, formando parejas de por vida.',
    'rara',
    true,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    NULL
  )
ON CONFLICT (code) DO UPDATE SET
  description = EXCLUDED.description,
  image_url = EXCLUDED.image_url,
  is_active = EXCLUDED.is_active;

-- ============================================================================
-- 3.4 QR TOKENS VINCULADOS A CARTAS
-- ============================================================================

INSERT INTO qr_tokens (id, qr_id, card_id, nonce, sig, expires_at, max_uses_per_user, cooldown_days, site_id)
VALUES
  (
    'a1b2c3d4-e5f6-4789-0123-456789abcdef'::uuid,
    'ANG-MIRADOR-CARD001',
    'c1a2b3c4-d5e6-47f8-9012-3456789abcde'::uuid,
    'nonce001',
    'sig001',
    NULL,
    1,
    90,
    '10000000-0000-0000-0000-000000000001'::uuid
  ),
  (
    'a2b3c4d5-e6f7-4890-1234-56789abcdef0'::uuid,
    'ANG-LAGUNA-CARD003',
    'c3c4d5e6-f789-401a-b234-56789cdef012'::uuid,
    'nonce003',
    'sig003',
    NOW() + INTERVAL '6 months',
    1,
    90,
    '10000000-0000-0000-0000-000000000001'::uuid
  ),
  (
    'a3c4d5e6-f789-401a-2345-6789abcdef01'::uuid,
    'ANG-SENDERO-CARD005',
    'c5e6f789-0123-44bc-d456-789ef0123456'::uuid,
    'nonce005',
    'sig005',
    NOW() + INTERVAL '1 year',
    1,
    90,
    '10000000-0000-0000-0000-000000000001'::uuid
  ),
  (
    'a4d5e6f7-8901-42ab-3456-789abcdef012'::uuid,
    'ANG-BOSQUE-CARD007',
    'c7890123-4567-48de-f678-90123456789a'::uuid,
    'nonce007',
    'sig007',
    NOW() + INTERVAL '1 year',
    1,
    90,
    '10000000-0000-0000-0000-000000000001'::uuid
  ),
  (
    'a5e6f789-0123-45bc-4567-89abcdef0123'::uuid,
    'ANG-LAGUNA-CARD009',
    'c9012345-6789-40ab-cdef-0123456789bc'::uuid,
    'nonce009',
    'sig009',
    NOW() + INTERVAL '1 year',
    1,
    90,
    '10000000-0000-0000-0000-000000000001'::uuid
  ),
  (
    'a6f78901-2345-46cd-5678-9abcdef01234'::uuid,
    'ANG-LAGUNA-CARD010',
    'ca123456-789a-4bcd-ef01-23456789abcd'::uuid,
    'nonce010',
    'sig010',
    NOW() + INTERVAL '1 year',
    1,
    90,
    '10000000-0000-0000-0000-000000000001'::uuid
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 3.5 EMPRENDEDORES LOCALES (MARKET ITEMS)
-- ============================================================================

INSERT INTO market_items (id, title, description, price, category, contact_info, location_label, is_active, created_at, updated_at)
VALUES
  (
    'e1f2a3b4-c5d6-4789-0123-456789abcdef'::uuid,
    'Café Mirador del Biobío',
    'Disfruta de café de grano local con vista privilegiada al río Biobío. Especialidad en tortas caseras y empanadas. Abierto de 9:00 a 18:00 todos los días.',
    5000,
    'Gastronomía',
    '+56912345001',
    'Entrada Principal, Km 2',
    true,
    NOW(),
    NOW()
  ),
  (
    'e2f3a4b5-c6d7-4890-1234-56789abcdef0'::uuid,
    'Artesanías Quilaco',
    'Tejidos tradicionales mapuche: mantas, chalecos y bolsos elaborados con lana natural. Cada pieza es única y hecha a mano por artesanas locales.',
    25000,
    'Artesanía',
    '+56912345002',
    'Plaza de Artesanos',
    true,
    NOW(),
    NOW()
  ),
  (
    'e3f4a5b6-c7d8-490a-2345-6789abcdef01'::uuid,
    'Guías de Kayak Laguna',
    'Tours guiados en kayak por la Laguna Angostura. Incluye equipo completo y guía certificado. Duración: 2 horas. Ideal para familias y principiantes.',
    18000,
    'Turismo',
    'https://wa.me/56912345003',
    'Muelle Laguna Angostura',
    true,
    NOW(),
    NOW()
  ),
  (
    'e4f5a6b7-c8d9-410b-3456-789abcdef012'::uuid,
    'Miel Nativa del Biobío',
    'Miel 100% pura de ulmo y quillay. Producción sustentable en colmenas ubicadas en el bosque nativo. Frascos de 500g y 1kg disponibles.',
    8000,
    'Gastronomía',
    '+56912345004',
    'Feria del Parque',
    true,
    NOW(),
    NOW()
  ),
  (
    'e5f6a7b8-c9da-420c-4567-89abcdef0123'::uuid,
    'Fotografía Naturaleza Chile',
    'Sesiones fotográficas profesionales en el parque. Captura tu visita con paisajes impresionantes. Incluye edición digital y entrega en 48 horas.',
    35000,
    'Turismo',
    '+56912345005',
    'Centro de Visitantes',
    true,
    NOW(),
    NOW()
  ),
  (
    'e6f78901-2345-46cd-5678-9abcdef01234'::uuid,
    'Artesanías Angostura',
    'Tejidos artesanales en lana de alpaca. Mantas, gorros, guantes y ponchos con diseños tradicionales de la zona. Productos 100% naturales hechos a mano.',
    15000,
    'Artesanía',
    '+56987654321',
    'Plaza de Angostura',
    true,
    NOW(),
    NOW()
  ),
  (
    'e7890123-4567-48de-6789-abcdef012345'::uuid,
    'Empanadas Doña Rosa',
    'Empanadas caseras de pino, queso y napolitana. Horneadas al momento con receta familiar de más de 30 años.',
    2500,
    'Gastronomía',
    '+56976543210',
    'Calle Principal #45',
    true,
    NOW(),
    NOW()
  ),
  (
    'e8901234-5678-490e-789a-bcdef0123456'::uuid,
    'Miel y Mermeladas del Valle',
    'Miel de abeja 100% pura y mermeladas artesanales de frutos del bosque. Sin conservantes ni colorantes.',
    8500,
    'Alimentos',
    '+56965432109',
    'Feria Campesina - Sector Norte',
    true,
    NOW(),
    NOW()
  ),
  (
    'e9012345-6789-40ab-89cd-ef0123456789'::uuid,
    'Cabalgatas Cerro Mirador',
    'Tours guiados a caballo por los senderos del Parque Angostura. Incluye equipo completo y guía certificado. Duración 2-3 horas.',
    25000,
    'Turismo',
    '+56954321098',
    'Entrada Parque - Sector Mirador',
    true,
    NOW(),
    NOW()
  ),
  (
    'ea123456-789a-4bcd-9def-0123456789ab'::uuid,
    'Cerámica Patagónica',
    'Vajilla y decoración en cerámica greda. Platos, tazones, vasos y figuras decorativas con motivos de la flora y fauna local.',
    12000,
    'Artesanía',
    '+56943210987',
    'Taller Artesanal - Calle Los Álamos #12',
    true,
    NOW(),
    NOW()
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 3.6 RECOMPENSAS Y CONFIGURACIÓN
-- ============================================================================

INSERT INTO rewards (id, site_id, title, description, cost_points, area_complete, household_only) VALUES
  (
    '40000000-0000-0000-0000-000000000001'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    'Entrada gratuita próxima visita',
    'Descuento del 100% en la entrada para la próxima visita familiar',
    500,
    false,
    true
  ),
  (
    '40000000-0000-0000-0000-000000000002'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    'Kit de observación',
    'Binoculares y guía de campo básica para llevar a casa',
    1000,
    true,
    true
  ),
  (
    '40000000-0000-0000-0000-000000000003'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    'Taller de fotografía',
    'Participación en taller de fotografía de naturaleza',
    750,
    false,
    false
  )
ON CONFLICT (id) DO NOTHING;

-- Insertar configuraciones solo si no existen
INSERT INTO site_configs (site_id, key, value)
SELECT '10000000-0000-0000-0000-000000000001'::uuid, 'points_per_scan', '50'
WHERE NOT EXISTS (
  SELECT 1 FROM site_configs 
  WHERE site_id = '10000000-0000-0000-0000-000000000001'::uuid AND key = 'points_per_scan'
);

INSERT INTO site_configs (site_id, key, value)
SELECT '10000000-0000-0000-0000-000000000001'::uuid, 'bonus_area_complete', '200'
WHERE NOT EXISTS (
  SELECT 1 FROM site_configs 
  WHERE site_id = '10000000-0000-0000-0000-000000000001'::uuid AND key = 'bonus_area_complete'
);

INSERT INTO site_configs (site_id, key, value)
SELECT '10000000-0000-0000-0000-000000000001'::uuid, 'max_daily_scans', '10'
WHERE NOT EXISTS (
  SELECT 1 FROM site_configs 
  WHERE site_id = '10000000-0000-0000-0000-000000000001'::uuid AND key = 'max_daily_scans'
);

-- ============================================================================
-- VERIFICACIÓN FINAL
-- ============================================================================

SELECT 
  'SETUP COMPLETO - RESUMEN DE DATOS' as info,
  '' as tabla,
  0 as registros
UNION ALL
SELECT '', 'Sites', COUNT(*)::int FROM sites
UNION ALL
SELECT '', 'Areas', COUNT(*)::int FROM areas
UNION ALL
SELECT '', 'Seasons', COUNT(*)::int FROM seasons
UNION ALL
SELECT '', 'Cards', COUNT(*)::int FROM cards
UNION ALL
SELECT '', 'QR Tokens', COUNT(*)::int FROM qr_tokens
UNION ALL
SELECT '', 'Market Items', COUNT(*)::int FROM market_items
UNION ALL
SELECT '', 'Rewards', COUNT(*)::int FROM rewards
ORDER BY info DESC, tabla;

-- Ver algunas cartas creadas
SELECT 
  code,
  title,
  rarity,
  LEFT(description, 50) || '...' as description_preview
FROM cards
ORDER BY code
LIMIT 10;

-- ============================================================================
-- FIN DEL SCRIPT MAESTRO
-- ============================================================================
-- NOTA: Ejecuta este script UNA SOLA VEZ en tu base de datos limpia
-- Si ya tienes datos, revisa cada sección antes de ejecutar
-- ============================================================================
