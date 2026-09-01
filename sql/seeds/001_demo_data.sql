-- ============================================================================
-- SEED DEMO DATA - Angostura Biobío App (EVA03)
-- ============================================================================
-- Este script puebla datos de ejemplo para demostración/desarrollo.
-- NO modifica tablas de autenticación ni usuarios.
--
-- CÓMO EJECUTAR:
-- 1. Abrir el panel SQL de Supabase (https://supabase.com/dashboard)
-- 2. Ir a: SQL Editor
-- 3. Copiar y pegar este archivo completo
-- 4. Ejecutar (Run)
--
-- IMPORTANTE: Ajusta los UUIDs si necesitas referencias específicas.
-- ============================================================================

-- ============================================================================
-- 1) TABLA: cards
-- ============================================================================
-- Insertar cartas de especies nativas del Parque Angostura
-- NOTA: Ejecuta primero migration_add_card_fields.sql si la tabla no tiene description/image_url

INSERT INTO cards (id, code, title, description, rarity, is_active, site_id, area_id, season_id)
VALUES
  (
    'c1a2b3c4-d5e6-47f8-9012-3456789abcde'::uuid,
    'ANG-CARD-001',
    'Carpintero Negro',
    'El carpintero negro (Campephilus magellanicus) es una de las aves más emblemáticas de los bosques nativos del sur de Chile. Reconocido por su distintivo plumaje negro con marcas rojas en la cabeza, puede alcanzar hasta 45 cm de longitud.',
    'común',
    true,
    NULL,
    NULL,
    NULL
  ),
  (
    'c2b3c4d5-e6f7-4890-a123-456789bcdef0'::uuid,
    'ANG-CARD-002',
    'Coigüe',
    'El coigüe (Nothofagus dombeyi) es un árbol nativo de gran altura que puede superar los 40 metros. Sus hojas perennes y su madera de alta calidad lo convierten en una especie fundamental del bosque templado lluvioso.',
    'común',
    true,
    NULL,
    NULL,
    NULL
  ),
  (
    'c3c4d5e6-f789-401a-b234-56789cdef012'::uuid,
    'ANG-CARD-003',
    'Pehuén (Araucaria)',
    'La araucaria (Araucaria araucana), conocida como pehuén por el pueblo mapuche, es un árbol milenario endémico de Chile y Argentina. Puede vivir más de 1.000 años y alcanzar 50 metros de altura. Sus piñones son alimento tradicional.',
    'épica',
    true,
    NULL,
    NULL,
    NULL
  ),
  (
    'c4d5e6f7-8901-42ab-c345-6789def01234'::uuid,
    'ANG-CARD-004',
    'Traro',
    'El traro (Caracara plancus) es un ave rapaz de tamaño mediano, muy adaptable y común en la región del Biobío. Se alimenta de carroña, pequeños mamíferos e insectos. Es fácil de reconocer por su cara desnuda de color naranja.',
    'común',
    true,
    NULL,
    NULL,
    NULL
  ),
  (
    'c5e6f789-0123-44bc-d456-789ef0123456'::uuid,
    'ANG-CARD-005',
    'Zorro Culpeo',
    'El zorro culpeo (Lycalopex culpaeus) es el segundo cánido más grande de Sudamérica. Habita en diversos ambientes, desde bosques hasta zonas montañosas. Su pelaje rojizo-grisáceo y su cola espesa lo hacen inconfundible.',
    'rara',
    true,
    NULL,
    NULL,
    NULL
  ),
  (
    'c6f78901-2345-46cd-e567-89f012345678'::uuid,
    'ANG-CARD-006',
    'Copihue',
    'El copihue (Lapageria rosea) es la flor nacional de Chile. Esta enredadera nativa produce flores acampanadas de color rojo intenso (aunque también existen variedades blancas y rosadas). Crece en bosques húmedos y sombríos.',
    'rara',
    true,
    NULL,
    NULL,
    NULL
  ),
  (
    'c7890123-4567-48de-f678-90123456789a'::uuid,
    'ANG-CARD-007',
    'Huemul',
    'El huemul (Hippocamelus bisulcus) es uno de los dos ciervos nativos de Chile y símbolo nacional junto al cóndor. Habita en bosques y zonas cordilleranas de Los Andes. Está en peligro crítico de extinción con menos de 2.000 individuos silvestres. Los machos poseen cornamentas bifurcadas.',
    'épica',
    true,
    NULL,
    NULL,
    NULL
  ),
  (
    'c8901234-5678-490e-f789-0123456789ab'::uuid,
    'ANG-CARD-008',
    'Chucao',
    'El chucao (Scelorchilus rubecula) es un ave pequeña y esquiva de color rojizo característico de los bosques templados. Su canto distintivo es inconfundible: un "chucao, chucao" repetitivo que resuena en la espesura del bosque.',
    'rara',
    true,
    NULL,
    NULL,
    NULL
  );

-- ============================================================================
-- 2) TABLA: qr_tokens
-- ============================================================================
-- Insertar códigos QR activos asociados a cartas de ejemplo
-- NOTA: El esquema real tiene: id, site_id, card_id, qr_id, nonce, sig, expires_at, max_uses_per_user, cooldown_days, created_at
-- No tiene columna 'token' ni 'is_active'

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
    NULL
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
    NULL
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
    NULL
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
    NULL
  );

-- ============================================================================
-- 3) TABLA: market_items (COMPLEMENTO - solo si no existe insert_market_data.sql)
-- ============================================================================
-- Insertar emprendedores de ejemplo adicionales

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
  );

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================
-- Datos insertados:
--   - 8 cartas de especies nativas (común, rara, épica)
--   - 4 códigos QR activos vinculados a cartas
--   - 5 emprendedores locales (gastronomía, artesanía, turismo)
--
-- Verificación:
--   SELECT COUNT(*) FROM cards; -- Debería mostrar al menos 8
--   SELECT COUNT(*) FROM qr_tokens; -- Al menos 4
--   SELECT COUNT(*) FROM market_items WHERE is_active = true; -- Al menos 5
-- ============================================================================
