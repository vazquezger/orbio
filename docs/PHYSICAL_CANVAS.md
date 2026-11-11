# Canvas físico de Orbio: requerimientos

Orbio funciona sobre un mapa mundi físico. Este documento define qué tiene que cumplir ese mapa para que la app lo calibre y proyecte bien las capas, en dos etapas:

1. **Hoy (prototipo):** póster de papel impreso en 4 o 6 hojas A4.
2. **Después (producto):** canvas fabricado, borrable, tomando como referencia un producto comercial.

---

## 1. Requerimientos que impone la app

Estos puntos valen para cualquier versión del canvas. Si no se cumplen, la superposición no coincide con el mapa.

| # | Requerimiento | Por qué |
|---|---|---|
| R1 | **Proyección equirectangular** (lat/lon lineales), con lon −180…180 y lat 90…−90 | `MapProjection` asume exactamente esa proyección. Un mapa en Robinson, Miller o Winkel no va a coincidir aunque las esquinas estén bien. |
| R2 | **Los 4 centros de las anclas son los bordes del mundo**: TL = (−180°, 90°), TR = (180°, 90°), BR = (180°, −90°), BL = (−180°, −90°) | La homografía mapea las anclas a (0,0), (1,0), (1,1), (0,1). |
| R3 | **4 anclas tipo diana** en las esquinas: disco negro, anillo blanco (≈⅔ del radio), cruz fina y punto negro central (≈0.3 del radio) | Es el patrón que busca `AnchorDetector`. |
| R4 | **Zona libre** de al menos 1 radio de ancla alrededor de cada diana: nada impreso y sin borde de la tela/papel | Si algo oscuro toca el ancla, se fusiona con ella y el detector la descarta o la desplaza. |
| R5 | **Anclas permanentes**: no borrables, no tapadas por marcos ni ojales | Se borra el mapa, no las anclas. |
| R6 | **Superficie plana y tensa** al fotografiar | La homografía asume un plano; las arrugas y ondas desplazan las capas. |
| R7 | **Acabado mate** | Los brillos y reflejos de la lámpara o el flash tapan contornos y anclas. |
| R8 | **Alto contraste**: contornos negros sobre fondo blanco o muy claro | El umbral adaptativo necesita diferencia de luminancia. |
| R9 | **Tolerancia de impresión**: la posición de cada ancla y la geometría del mapa con un error ≤ ±1 mm (o ≤ 0.2 % del ancho) | Es el error que se traslada a los países y puntos de interés proyectados. |
| R11 | **Markers ArUco** en los océanos (hoy 50, `DICT_4X4_50`, 15 mm de lado + 2,5 mm de margen blanco en el póster de 80 × 40 cm), impresos en negro puro, nítidos y sin uniones de hojas encima | Son los que usa la Live view para ubicar el teléfono viendo solo una parte del mapa. |
| R10 | Proporción entre centros de anclas **2.11 : 1** (760 × 360 unidades del SVG); la hoja total es 2 : 1 (800 × 400) | Así está definido `assets/maps/orbio_printable_canvas.svg`. |

Referencia de diseño: `assets/maps/orbio_printable_canvas.svg`, generado por `tool/generate_canvas.py` (no editarlo a mano; también escribe `assets/maps/canvas_markers.json`) (ver [ARCHITECTURE.md §5](ARCHITECTURE.md#5-mapa-imprimible-assetsmapsorbio_printable_canvassvg)).

---

## 2. Etapa actual: póster de papel en 4 o 6 hojas

Se imprime el SVG en varias hojas A4 y se arma como póster.

### 2.1 Opciones de tamaño

El SVG mide 800 × 400 unidades. Conviene definir **1 unidad = X mm**:

| Formato | Hojas | Escala | Tamaño final | Radio del ancla | Contenido por hoja |
|---|---|---|---|---|---|
| **Recomendado** | 6 A4 horizontales (3 × 2) | 1 u = 1 mm | **80 × 40 cm** | 12 mm | 267 × 200 mm |
| Compacto | 4 A4 horizontales (2 × 2) | 1 u = 0.7 mm | **56 × 28 cm** | 8.4 mm | 280 × 140 mm |

- Una A4 horizontal (297 × 210 mm) deja unos 287 × 200 mm imprimibles con márgenes de 5 mm. El formato 3 × 2 entra justo en alto; si la impresora tiene márgenes más grandes, bajá a 0.95 u/mm (76 × 38 cm).
- En ambos formatos las anclas quedan en las hojas de las esquinas y lejos de las uniones: las uniones verticales están a ⅓ y ⅔ del ancho (o a ½), y la horizontal a ½ del alto. Cumple R4.

### 2.2 Cómo imprimirlo

1. Abrí `assets/maps/orbio_printable_canvas.svg` en Chrome o Safari y exportalo a **PDF** (Imprimir → Guardar como PDF, tamaño personalizado de 800 × 400 mm, escala 100 %).
2. Abrí el PDF en **Adobe Acrobat Reader** (gratis) → Imprimir → **Póster**:
   - Escala de mosaico: **100 %** (6 hojas) o **70 %** (4 hojas).
   - Superposición: **10 mm**.
   - Activar **marcas de corte** y **etiquetas**.
   - Orientación: horizontal.
3. Imprimí en **calidad alta**, en **escala de grises o negro puro**, en papel **mate** de 90 g o más.
4. Desactivá en el driver cualquier "ajustar a página" o "reducir para que quepa": tiene que salir al 100 %.

### 2.3 Cómo armarlo

1. Recortá por las marcas de corte en el lado de superposición de cada hoja.
2. Uní **desde atrás** con cinta de papel. Cinta por delante genera brillos y bordes oscuros.
3. Pegá el póster sobre una superficie rígida y plana (cartón pluma, foamboard o MDF fino) con adhesivo en aerosol o cinta doble faz en todo el perímetro (R6).
4. **Verificá con regla** la distancia entre centros de anclas:
   - 6 hojas: TL↔TR = **760 mm**, TL↔BL = **360 mm**.
   - 4 hojas: TL↔TR = **532 mm**, TL↔BL = **252 mm**.
   - Diagonales iguales (TL↔BR = TR↔BL). Una diferencia de más de 2 mm indica una unión torcida.
5. Opcional, para hacerlo borrable: plastificado mate o vinilo transparente mate. Evitá el brillante (R7).

### 2.4 Prueba rápida

1. Fotografiá desde arriba con luz pareja, sin flash, con las 4 dianas en cuadro.
2. En Calibrate tienen que aparecer los 4 corner handles **verdes** ("Found all 4 anchors").
3. En Explore, los contornos coloreados de ARG, JPN, EGY, ESP e ISL tienen que caer sobre los contornos impresos.

---

## 3. Etapa futura: canvas fabricado

### 3.1 Producto de referencia

- Publicación: <https://www.mercadolibre.com.ar/up/MLAU220390466> (MLA1106479775)
- La página no se pudo leer en forma automática. **Completar a mano:**

| Campo | Valor |
|---|---|
| Título / marca | _completar_ |
| Medidas (cm) | _completar_ |
| Material (tela, lona, vinilo…) | _completar_ |
| Borrable con | _completar_ (¿marcador de pizarra? ¿al agua?) |
| Qué tiene impreso | _completar_ (¿solo contornos? ¿nombres? ¿grilla?) |
| **Proyección del mapa** | _completar_ (crítico, ver R1) |
| Terminación (ojales, bastidor, dobladillo) | _completar_ |
| Precio (ARS) y fecha | _completar_ |

### 3.2 Qué hay que pedirle al fabricante

Para fabricar un canvas propio o adaptar uno comercial:

1. **Arte provisto por nosotros**: el SVG (vectorial) escalado al tamaño final. No usar el mapa de catálogo del fabricante salvo que cumpla R1 y R2.
2. **Material**: tela o lona blanca mate apta para marcador borrable (tipo pizarra blanca o tela "dry-erase"), o vinilo mate laminado.
3. **Tintas**: contornos y anclas con tinta permanente de alta adherencia, que resista el borrado repetido con paño y alcohol (R5).
4. **Tamaño sugerido**: 80 × 40 cm (escala 1 u = 1 mm), o 120 × 60 cm (1 u = 1.5 mm) para uso en el piso o una mesa grande.
5. **Tensión y planitud**: bastidor, varillas arriba y abajo, o tela con respaldo rígido. Los ojales y costuras tienen que quedar fuera de la zona libre de las anclas (R4, R6).
6. **Control de calidad por lote**: medir las distancias entre anclas y las diagonales (tolerancia R9) y fotografiar una muestra con la app (4/4 anclas detectadas).
7. **Muestra física** antes de producción, validada con la prueba rápida de §2.4.

### 3.3 Si usamos un mapa comercial tal cual

Si el producto no está en equirectangular o no tiene las anclas:

- **Se pueden agregar anclas** con stickers impresos (diana de vinilo mate) en las posiciones que correspondan a lon ±180 / lat ±90, pero solo sirve si el mapa es equirectangular y cubre el mundo completo.
- **Si tiene otra proyección**, la app necesita soportarla: agregar la proyección en `core/geometry/map_projection.dart` y los límites del mapa como configuración por producto. Es trabajo de software, no solo de impresión.

---

## 4. Pendientes

- [ ] Completar la ficha del producto de referencia (§3.1).
- [ ] Imprimir y validar el póster de 6 hojas (§2.4).
- [ ] Decidir el tamaño final del producto fabricado.
- [ ] Opcional: generar desde el repo los PDFs ya divididos en hojas (con marcas de corte y número de hoja) para no depender de Acrobat.
