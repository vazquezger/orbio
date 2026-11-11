# Glosario de Orbio

El vocabulario canónico de Orbio está en **inglés**: es el que se usa en el código, en los nombres de archivos y campos, y en la documentación técnica. La interfaz es **bilingüe** (inglés y español); la columna *UI (es)* muestra cómo aparece cada término en español.

Reglas:
- Usá estos términos tal cual en el código y en la documentación. No inventes sinónimos (*marker*, *POI*, *overlay item*, *corner pin*…).
- Todo texto visible para el usuario va en `lib/l10n/app_en.arb` y `lib/l10n/app_es.arb`, nunca escrito directo en el código.
- La documentación del repo se escribe en español usando estos términos en inglés.

---

## Mundo físico

| Término | UI (es) | Definición | En el código |
|---|---|---|---|
| **Canvas** | Lienzo | El mapa mundi físico y borrable (hoy un póster de papel; en el futuro un producto fabricado). Ver [PHYSICAL_CANVAS.md](PHYSICAL_CANVAS.md). | `orbio_printable_canvas.svg` |
| **Marker** | Marcador | Cada uno de los cuadraditos ArUco impresos en los océanos del canvas. Permiten ubicar el teléfono viendo solo una parte del mapa. | `ArucoDetector`, `MarkerLayout` |
| **Anchor** | Ancla | Cada una de las 4 dianas impresas en las esquinas del canvas (TL, TR, BR, BL). Sus centros marcan los bordes del mundo. | `AnchorDetector`, `anchor-TL` en el SVG |

> En la UI en español, "marcador" puede confundirse con la fibra para escribir: si hace falta nombrarlo para chicos, usar "cuadradito". En código y docs es **marker**.

## Flujo

| Término | UI (es) | Definición | En el código |
|---|---|---|---|
| **Snapshot** | Captura | La foto congelada del canvas: sacada con la cámara, importada o generada como demo. | `SnapshotStore` |
| **Demo snapshot** | Captura demo | Snapshot sintética: el SVG imprimible renderizado en ángulo sobre una mesa, para probar sin canvas ni cámara. | `createDemoSnapshot()` |
| **Calibrate** | Calibrar | Alinear la snapshot con el mapa ubicando los 4 corner handles sobre las anchors. | `CalibrationScreen` |
| **Corner handle** | Esquina | Cada uno de los 4 puntos arrastrables en Calibrate, en orden `[TL, TR, BR, BL]`. | `defaultCornerHandles()`, `_activeHandle` |
| **Loupe** | Lupa | Lente de aumento que aparece al arrastrar un corner handle, para ubicarlo con precisión de un píxel. | `MagnifierLoupe` |
| **Live view** | En vivo | La cámara en vivo con las banderas pintadas sobre el canvas (realidad aumentada). | `LiveScreen`, `MarkerTracker` |
| **Explore** | Explorar | La vista con la snapshot y las layers proyectadas encima. | `ExploreScreen` |

## Contenido sobre el mapa

| Término | UI (es) | Definición | En el código |
|---|---|---|---|
| **Layer** | Capa | Grupo de contenido que se prende y apaga: **Flags** (Banderas), **Government** (Gobierno) y **Physical** (Física). Flags y Government son excluyentes. | `MapLayer` |
| **Pin** | — (genérico) | Elemento puntual sobre el mapa, con una ubicación lat/lon: volcán, montaña, depresión. Más adelante, por ejemplo, capitales. | `Pin`, `PinKind` |
| **Area** | — (genérico) | Elemento que cubre una superficie: hoy, la forma de un país (puede tener varias piezas: islas, exclaves). | `Country.areas` |
| **Note** | Nota | Texto curado asociado a un país, de solo lectura, que se muestra en la hoja del país (sección Stories). Tipos: `fact` (¿Sabías que…?) y `story` (Historia). | `Note`, `NoteKind`, `Country.notes` |
| **Pack** | Paquete | Conjunto de contenido instalable (countries, pins, curated notes). Hoy existe un único pack implícito: `world_sample.json`. | *(pendiente)* |

## Geometría (interno)

| Término | Definición | En el código |
|---|---|---|
| **Normalized space** | Coordenadas `[0,1]²` del mapa: (0,0) = anchor TL, (1,1) = anchor BR. | `PerspectiveProjector.normalizedCorners` |
| **Homography** | Matriz 3×3 que lleva el normalized space a píxeles de la snapshot. | `Homography` |
| **Projection** | Paso de lat/lon al normalized space (equirectangular). | `MapProjection` |

---

## Cambios de nombre aplicados

| Antes | Ahora |
|---|---|
| corner pin | corner handle |
| capture / `CaptureStore` | snapshot / `SnapshotStore` |
| `MapViewerScreen` | `ExploreScreen` |
| `PointOfInterest` / `PoiType` / `points_of_interest` | `Pin` / `PinKind` / `pins` |
| `BioEntry` / `BioKind` / `bio_notes` | `Note` / `NoteKind` / `notes` |
| `MapLayer.bio` / `stories` / `political` | `MapLayer.flags`, `government`, `physical` |
| kind `trivia` | kind `fact` (`trivia` se sigue leyendo como alias) |
| notas propias (family/travel, editables) | eliminadas: solo notas curadas |
