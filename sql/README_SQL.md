# SQL de Angostura App

Esta carpeta conserva solamente los scripts relacionados con el contrato de datos utilizado por la aplicación. Los diagnósticos, correcciones descartadas y versiones históricas fueron trasladados fuera del repositorio.

> Estos archivos representan una reconstrucción del desarrollo, no un historial de migraciones validado contra producción. Antes de aplicarlos sobre una base existente se debe exportar y comparar el esquema real de Supabase.

## Estructura

```text
sql/
├── bootstrap/
│   └── 001_base_schema.sql
├── migrations/
│   ├── 010_households.sql
│   ├── 020_guest_access.sql
│   ├── 030_prepare_user_profiles.sql
│   ├── 031_sync_auth_users.sql
│   ├── 040_child_users.sql
│   ├── 041_household_unlock.sql
│   ├── 050_developer_panel_columns.sql
│   ├── 060_market_products.sql
│   ├── 070_card_biological_fields.sql
│   ├── 071_card_content_fields.sql
│   └── 080_roles.sql
└── seeds/
    └── 001_demo_data.sql
```

## Orden previsto para una base nueva

1. `bootstrap/001_base_schema.sql`
2. Scripts de `migrations/` en orden numérico
3. Opcionalmente `seeds/001_demo_data.sql` en un ambiente de demostración

El seed no debe ejecutarse en producción sin revisar previamente su contenido.

## Contrato observado en el código Flutter

Tablas consultadas directamente:

- `areas`
- `cards`
- `child_users`
- `household_members`
- `households`
- `market_items`
- `products_items`
- `qr_tokens`
- `seasons`
- `sites`
- `user_cards`
- `users`

RPC invocadas directamente:

- `create_child_user`
- `create_household_for_owner`
- `get_my_household_info`
- `join_household_by_code`
- `resend_verification_code`
- `unlock_card_by_code`
- `unlock_card_for_household`
- `validate_family_code`
- `verify_household_code`

## Limitaciones conocidas

- No se encontró una definición versionada de `unlock_card_by_code`, aunque el cliente la invoca.
- El modelo histórico mezcla `seasons.id` y `seasons.season_id`.
- El esquema base contiene módulos que el cliente actual no usa directamente, como reservas, puntos y canjes.
- Las políticas RLS no tienen todavía una suite de pruebas de aislamiento entre hogares.
- Algunas migraciones fueron creadas como correcciones manuales y aún deben convertirse en migraciones idempotentes.
- El envío real del código de verificación familiar no está implementado.

## Seguridad

- No deshabilitar RLS para solucionar errores del cliente.
- Las funciones `SECURITY DEFINER` deben fijar un `search_path` seguro y validar `auth.uid()` cuando corresponda.
- No usar credenciales de usuarios reales en seeds o pruebas.
- No ejecutar scripts históricos sobre una base activa.
- La clave `service_role` nunca debe incluirse en la aplicación ni en este repositorio.
- Revisar manualmente migraciones y seeds antes de cada despliegue; su presencia en el repositorio no implica que sean seguros para producción.

## Próxima tarea necesaria

Exportar el esquema desplegado en Supabase y generar una migración inicial limpia. Hasta realizar esa comparación, estos scripts deben considerarse material de desarrollo y recuperación, no una instalación de producción garantizada.
