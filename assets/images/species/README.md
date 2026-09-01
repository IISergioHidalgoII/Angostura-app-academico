# Species Images

Este directorio contiene las imágenes de las especies para las cartas.

## Cartas disponibles - 4 especies

✅ **Imágenes presentes** con estos nombres:

### Especies configuradas:
1. **carpinteronegro01.png** ✅
   - Código: `ANG-CARD-001`
   - Nombre: Carpintero Negro
   
2. **zorroculpeo01.png** ✅
   - Código: `ANG-CARD-004`
   - Nombre: Zorro Culpeo
   
3. **huemul01.png** ✅
   - Código: `ANG-CARD-007`
   - Nombre: Huemul
   
4. **pehuen01.png** ✅
   - Código: `ANG-CARD-011`
   - Nombre: Pehuén

### Imagen placeholder (opcional)
- `placeholder.png` - Si alguna carta no tiene imagen

## Códigos QR en Supabase

En la tabla `qr_tokens`, los códigos deben estar así:
- `ANG-CARD-001` → Carpintero Negro
- `ANG-CARD-004` → Zorro Culpeo
- `ANG-CARD-007` → Huemul
- `ANG-CARD-011` → Pehuén

## Flujo de prueba

1. **Coloca las 3 imágenes PNG** en esta carpeta
2. **Ejecuta** `flutter pub get` (si es necesario)
3. **Hot reload** la app
4. **Escanea los QR** para desbloquear cartas
5. **Ve a Colección** para ver las cartas con imágenes
6. **Toca una carta** para ver el detalle 3D volteado
7. **Resetea** desde el botón en QR Scanner para probar de nuevo

## Formato de imágenes

**Especificaciones simples para demo:**
- Formato: PNG
- Resolución: 512x512 px (cuadrada) o similar
- Peso: < 500KB
- Fondo: Cualquiera (transparente, blanco, o natural)

## Procedencia y derechos

La fuente, autoría y licencia de las imágenes presentes todavía no están documentadas. Antes de publicar el repositorio se debe registrar esa información para cada archivo y confirmar que la licencia permita redistribuirlo.

No descargues imágenes directamente desde resultados de buscadores. Usa recursos propios o fuentes que indiquen expresamente autor, licencia y requisitos de atribución, y conserva esa evidencia junto con el proyecto.

## Para resetear la colección

Usa el **botón de debug** en la parte superior del QR Scanner:
- Mantén presionado el botón 
- Selecciona "Reiniciar colección"
- Confirma
- Ahora puedes escanear QRs de nuevo y ver las cartas aparecer

## Estado actual

⚠️ **DEMO SIMPLIFICADO**: Solo 3 cartas de ejemplo para facilitar las pruebas.

- Sin imágenes PNG: Mostrará iconos con colores de rareza
- Con imágenes PNG: Mostrará las fotos reales de especies
- Todo funciona 100% offline
