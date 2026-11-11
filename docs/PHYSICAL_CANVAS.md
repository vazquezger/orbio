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
| R12 | **Costas gruesas (~1,1 mm) y fronteras finas (~0,35 mm)**, de Natural Earth 1:110m, las mismas que usa la app para pintar las banderas | Lo impreso y lo pintado coinciden exactamente; la jerarquía de líneas se lee como "continente" primero y "país" después. |
| R11 | **Markers ArUco** en los océanos (hoy 50, `DICT_4X4_50`, 13,5 mm de lado + 2,25 mm de margen blanco en el póster de 72 × 36 cm), impresos en negro puro, nítidos y sin uniones de hojas encima | Son los que usa la Live view para ubicar el teléfono viendo solo una parte del mapa. |
| R10 | Proporción entre centros de anclas **2.11 : 1** (760 × 360 unidades del SVG); la hoja total es 2 : 1 (800 × 400) | Así está definido `assets/maps/orbio_printable_canvas.svg`. |

Referencia de diseño: `assets/maps/orbio_printable_canvas.svg`, generado por `tool/generate_canvas.py` (no editarlo a mano; también escribe `assets/maps/canvas_markers.json`) (ver [ARCHITECTURE.md §5](ARCHITECTURE.md#5-mapa-imprimible-assetsmapsorbio_printable_canvassvg)).

---

## 2. Etapa actual: póster de papel de 6 hojas

Damos el póster listo para imprimir, como PDF vectorial a escala exacta. No conviene que cada uno lo divida en hojas por su cuenta: si cambia la escala o las uniones caen en otro lugar, la calibración falla o se parte un marker.

| Archivo | Para qué |
|---|---|
| [`print/orbio_poster_6xA4.pdf`](../print/orbio_poster_6xA4.pdf) | **El póster**: 6 hojas A4 horizontales (3 × 2) que arman **72 × 36 cm** |
| [`print/orbio_test_1xA4.pdf`](../print/orbio_test_1xA4.pdf) | Una sola hoja (28 × 14 cm) **solo para pruebas** en el escritorio. Los markers miden ~5 mm: funcionan de cerca. |

Los dos se generan con `python3 tool/generate_poster.py`, a partir de la misma geometría que el SVG. Hay que volver a generarlos si cambia `tool/generate_canvas.py`.

### 2.1 Cómo imprimirlo
1. Abrí el PDF y elegí **Imprimir**.
2. **Escala: 100 % / "Tamaño real".** Nunca "Ajustar a la página" ni "Reducir para que quepa".
3. Papel **A4 horizontal**, mate, de 90 g o más. En blanco y negro alcanza.
4. Cada hoja trae abajo su nombre (A1…B3), el orden y qué hacer con ella.

### 2.2 Cómo armarlo
El orden es:
```
A1  A2  A3
B1  B2  B3
```
- Las hojas tienen una **franja gris** a la derecha o abajo: es la zona de pegado y queda tapada por la hoja vecina.
- Las hojas que van encima tienen **marcas de corte** en el margen del borde izquierdo o del superior. Recortá ese margen blanco siguiendo las marcas.
- Apoyá cada hoja recortada sobre la franja gris de la anterior, haciendo coincidir las líneas del mapa, y pegala (adhesivo en barra o cinta doble faz).
- Orden sugerido: A1 → A2 → A3, después B1 → B2 → B3 (cada una sobre la de arriba y la de la izquierda).

Después:
1. Pegá el póster sobre una superficie rígida y plana (cartón pluma o foamboard) (R6).
2. **Verificá con una regla** la distancia entre los centros de las anchors: TL↔TR = **684 mm**, TL↔BL = **324 mm**, y diagonales iguales (**757 mm**). Más de 2 mm de diferencia indica una unión torcida.
3. Opcional, para hacerlo borrable: plastificado o vinilo transparente **mate** (R7).

### 2.3 Prueba rápida
1. **Snapshot**: fotografiá desde arriba con luz pareja y sin flash, con las 4 anchors en cuadro. En Calibrate tienen que aparecer los 4 corner handles **verdes** ("Found all 4 anchors").
2. **Live view**: apuntá a cualquier parte del póster; las banderas tienen que caer sobre sus países (ver [TESTING_IPHONE.md](TESTING_IPHONE.md)).

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
4. **Tamaño sugerido**: 80 × 40 cm (1 u = 1 mm) o 120 × 60 cm (1 u = 1.5 mm) para el piso o una mesa grande. El póster de papel actual es de 72 × 36 cm (1 u = 0.9 mm) por el límite de la hoja A4.
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
- [ ] Imprimir y validar el póster de 6 hojas (§2.3).
- [ ] Decidir el tamaño final del producto fabricado.
