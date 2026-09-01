# Card Images

Este directorio contiene las imágenes de las cartas de especies.

## Estructura

### Imágenes específicas por código
- `ANG001.jpg` - Garza Grande
- `ANG002.jpg` - Pato Jergón Grande
- `ANG003.jpg` - Coipo
- etc.

### Imágenes por rareza (fallback)
- `common.jpg` - Para cartas comunes
- `rare.jpg` - Para cartas raras
- `epic.jpg` - Para cartas épicas
- `legendary.jpg` - Para cartas legendarias

### Imagen genérica
- `placeholder.jpg` - Imagen por defecto si no hay otra disponible

## Formato recomendado
- Resolución: 512x768 px (ratio 2:3)
- Formato: JPG o PNG
- Peso: < 500KB por imagen

## Cómo agregar imágenes

1. Coloca las imágenes en este directorio
2. Nómbralas según el código de la carta (ej: ANG001.jpg)
3. O usa las categorías de rareza
4. La app las cargará automáticamente

## Estado actual

⚠️ **PENDIENTE**: Agregar imágenes reales de especies.

Mientras tanto, la app mostrará placeholders con colores según rareza:
- Verde: Común
- Azul: Rara
- Morado: Épica
- Dorado: Legendaria
