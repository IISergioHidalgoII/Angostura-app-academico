# Angostura App

Aplicación móvil educativa y turística en desarrollo para el **Parque Angostura de Colbún S.A.**, ubicado entre las comunas de **Santa Bárbara y Quilaco, Región del Biobío, Chile**.

El proyecto explora una experiencia de visita gamificada: orientación dentro del parque, descubrimiento de flora y fauna, colección de cartas mediante códigos QR, participación de grupos familiares y difusión de emprendimientos locales.

> **Estado:** prototipo académico funcional y compilable, actualmente en estabilización. Cuenta con módulos implementados, integración con Supabase, pruebas automatizadas y una compilación Android de referencia. Persisten mejoras de arquitectura, seguridad y pruebas integrales antes de considerarlo apto para producción.

> [!IMPORTANT]
> **Proyecto académico independiente y sin afiliación oficial con Colbún S.A.** Este repositorio no ha sido patrocinado, autorizado, encargado ni validado oficialmente por Colbún S.A., Parque Angostura, las municipalidades de Santa Bárbara o Quilaco ni otras entidades vinculadas al destino. Los nombres, referencias territoriales y contenidos se utilizan exclusivamente con fines educativos y demostrativos. La aplicación no representa una fuente oficial de información turística, operacional o de seguridad.

Las denominaciones, marcas y referencias territoriales pertenecen a sus respectivos titulares. Su mención describe el contexto académico del prototipo y no implica patrocinio, asociación, aprobación ni autorización para usar identidades institucionales.

## Contexto

Parque Angostura forma parte del destino turístico **Angostura del Biobío** y fue desarrollado por Colbún S.A. en torno a la Central Hidroeléctrica Angostura. El parque incluye senderos, miradores, playas públicas, campings, un centro de visitantes y espacios de educación ambiental.

La conectividad irregular de algunos sectores motivó que la aplicación se diseñara con una orientación *offline-first*: mantener disponible el contenido esencial y conservar operaciones pendientes para sincronizarlas cuando regrese la conexión. Esa estrategia se encuentra parcialmente implementada y continúa en revisión.

Este repositorio corresponde a un ejercicio de aprendizaje y desarrollo de software. Cualquier publicación o demostración debe conservar el aviso de independencia anterior y evitar presentar el prototipo como un producto institucional o servicio disponible para visitantes.

## Objetivos

- Apoyar la educación ambiental mediante fichas de especies y contenido contextual.
- Motivar la exploración responsable del parque con una colección digital.
- Permitir que familias compartan parte de su progreso mediante grupos.
- Dar visibilidad a emprendedores y servicios turísticos del territorio.
- Mantener una experiencia útil cuando la conexión sea limitada.
- Construir una base modular que pueda evolucionar sin rehacer toda la aplicación.

## Funcionalidades y estado actual

| Área | Estado | Observación |
|---|---|---|
| Onboarding y selección de usuario | En estabilización | Existen flujos funcionales, pero aún hay implementaciones duplicadas. |
| Autenticación con Supabase | Parcialmente funcional | Se está revisando la sincronización entre `auth.users` y `public.users`. |
| Grupos familiares | En desarrollo | Crear, verificar y unirse a un grupo requiere más pruebas integrales. |
| Colección de cartas | Prototipo funcional | Permite consultar y desbloquear cartas; falta consolidar el progreso individual y familiar. |
| Escáner QR | Prototipo funcional | El flujo básico existe; la validación antifraude y la operación server-side deben reforzarse. |
| Temporadas | Parcial | Hay soporte en datos y UI, con inconsistencias pendientes entre `id` y `season_id`. |
| Funcionamiento offline | Experimental | Hive almacena caché y QR pendientes; faltan idempotencia, reintentos robustos y reconciliación completa. |
| Mercado local | Prototipo funcional | Incluye fichas y herramientas de administración en desarrollo. |
| Mapa y novedades | Inicial/parcial | Las pantallas existen, pero el alcance offline y la fuente de contenido deben completarse. |
| Recompensas | Experimental | La interfaz y parte del modelo existen; no hay una operación real validada con personal del parque. |
| Panel de desarrollo | Funcional para pruebas | Contiene herramientas de diagnóstico y mantenimiento; no es un panel administrativo de producción. |

## Tecnologías

- **Cliente:** Flutter y Dart.
- **Estado:** Riverpod, con lógica heredada aún pendiente de migración.
- **Backend:** Supabase Auth y PostgreSQL.
- **Persistencia local:** Hive.
- **Navegación:** rutas de Flutter y una migración parcial a `go_router`.
- **Escaneo:** `mobile_scanner`.
- **Conectividad:** `connectivity_plus`.
- **Imágenes:** `cached_network_image`.

## Arquitectura actual

El repositorio contiene dos etapas de arquitectura:

- `lib/main.dart`: punto de entrada activo, con navegación tradicional y parte importante del flujo heredado.
- `lib/main_modular.dart`: propuesta modular basada en `go_router`.

La meta es consolidar ambas etapas en una sola arquitectura, manteniendo los módulos dentro de `lib/features/` y los servicios compartidos dentro de `lib/core/`.

```text
lib/
├── core/       # modelos, servicios, configuración, tema y utilidades
├── features/   # autenticación, colección, QR, mercado, mapa y otros módulos
├── router/     # enrutamiento modular en proceso de adopción
├── shared/     # widgets reutilizables
├── main.dart
└── main_modular.dart

sql/            # esquema base, migraciones seleccionadas y datos demo
test/           # pruebas existentes y simulaciones
```

## Ejecución local

### Requisitos

- Flutter compatible con Dart `^3.9.2`.
- Android Studio, VSCode u otro entorno compatible con Flutter.
- Un emulador o dispositivo configurado.
- Acceso a una instancia de Supabase con el esquema esperado por el proyecto.

### Pasos

```bash
git clone https://github.com/IISergioHidalgoII/Angostura-app-academico.git
cd Angostura-app-academico
flutter pub get
Copy-Item dart_defines.example.json dart_defines.json
# Completa dart_defines.json con la configuración de tu proyecto Supabase.
flutter run --dart-define-from-file=dart_defines.json
```

En macOS o Linux, reemplaza `Copy-Item` por `cp`. También puedes proporcionar las variables sin archivo:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_CLAVE_ANON_PUBLICA
```

El punto de entrada predeterminado es `lib/main.dart`. La variante modular puede ejecutarse durante el proceso de migración con:

```bash
flutter run -t lib/main_modular.dart --dart-define-from-file=dart_defines.json
```

`dart_defines.json` está excluido de Git. No lo publiques ni incluyas una clave `service_role`. La clave `anon` se incorpora al cliente compilado y no sustituye la protección mediante políticas RLS correctamente configuradas.

## Estado de verificación

- `flutter pub get` resolvió correctamente las dependencias.
- `flutter analyze` fue ejecutado y reportó 285 observaciones informativas pendientes.
- `flutter test` finalizó con 8 pruebas aprobadas.
- `flutter build apk --debug` generó correctamente un APK de depuración.

Las pruebas actuales cubren lógica local, contraste visual y simulaciones. No sustituyen pruebas integrales con Supabase ni validaciones en dispositivos reales. Consulta [VALIDACION_TECNICA.md](VALIDACION_TECNICA.md) para revisar los resultados y su interpretación.

## Base de datos

La carpeta `sql/` contiene un esquema base reconstruido, migraciones seleccionadas y datos opcionales de demostración. Los diagnósticos y scripts históricos se administran fuera del repositorio.

No se recomienda ejecutar todos los archivos ni asumir que su orden alfabético representa el historial de migraciones. Antes de preparar un entorno nuevo es necesario:

1. Exportar o confirmar el esquema real desplegado en Supabase.
2. Definir una migración base reproducible.
3. Ordenar las migraciones posteriores.
4. Separar datos demo y scripts de diagnóstico.
5. Revisar funciones `SECURITY DEFINER`, permisos y políticas RLS.

## Pruebas y calidad

Las pruebas actuales no cubren todavía los flujos críticos de extremo a extremo. La prioridad es incorporar evidencia reproducible para:

- Registro e inicio de sesión.
- Creación y unión a grupos familiares.
- Aislamiento de datos mediante RLS.
- Escaneo QR válido, repetido, expirado y fuera de temporada.
- Operaciones sin conexión y reconciliación al reconectar.
- Progreso individual y familiar sin duplicados.
- Accesibilidad y contraste calculados correctamente.

Hasta completar estas verificaciones, las funciones deben considerarse prototipos en evaluación.

## Prioridades de estabilización

1. Consolidar el contexto territorial y eliminar referencias incorrectas a la Región del Maule.
2. Elegir un único punto de entrada y sistema de navegación.
3. Documentar el esquema real de Supabase y ordenar las migraciones.
4. Restaurar y probar las políticas RLS.
5. Unificar los modelos de usuario, invitado y miembro familiar.
6. Convertir la redención QR en una operación server-side atómica e idempotente.
7. Resolver definitivamente la relación entre `id` y `season_id`.
8. Completar y probar la sincronización offline.
9. Reemplazar simulaciones por pruebas unitarias, de integración y de dispositivo.
10. Repetir análisis, pruebas y compilaciones de referencia después de cada etapa de estabilización.

## Documentación

- [`sql/README_SQL.md`](sql/README_SQL.md): notas existentes sobre los scripts SQL.
- [`VALIDACION_TECNICA.md`](VALIDACION_TECNICA.md): resultados e interpretación de la verificación técnica actual.

La documentación académica, histórica y de continuidad se administra fuera de este repositorio, en una carpeta dedicada. Parte de ella describe decisiones posteriormente reemplazadas; el código y el esquema desplegado deben verificarse antes de asumir que una función está terminada.

## Recursos gráficos

Las imágenes de especies incluidas en `assets/images/species/` se conservan para el prototipo académico. La autoría, fuente y licencia de algunas imágenes todavía deben verificarse. No deben asumirse como libres de derechos ni reutilizarse fuera de este proyecto hasta completar esa comprobación.

## Referencias del territorio

- [Central y Parque Angostura — Colbún S.A.](https://www.colbun.cl/nuestras-energias/centrales-de-energia-renovable/centrales-hidroelectricas-de-embalse/angostura)
- [Programa de hidroturismo — Colbún S.A.](https://www.colbun.cl/corporativo/comunidad-y-sociedad/programas-y-proyectos-sociales/hidroturismo)
- [Parque Angostura celebra su visitante 1.000.000 — Colbún S.A.](https://www.colbun.cl/corporativo/sala-de-prensa/noticias-y-comunicados/detalle/2022/01/14/parque-angostura-celebra-su-visitante-1-000-000)

## Situación del repositorio

Este README acompaña el proceso de estabilización del proyecto. La versión actual ofrece una base funcional, compilable y demostrable, mientras las mejoras pendientes se mantienen documentadas para orientar su evolución técnica.

## Autoría

Proyecto académico desarrollado por Sergio Hidalgo, estudiante de Analista Programador en INACAP.

## Derechos de uso

Este proyecto no incluye por ahora una licencia de software. Se reservan todos los derechos sobre el código y los recursos propios. La disponibilidad del repositorio no concede permiso para copiar, modificar, distribuir o reutilizar su contenido.
