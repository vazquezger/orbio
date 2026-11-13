# Glosario de Orbio

El vocabulario canónico de Orbio está en **inglés**: es el que se usa en el código, en los nombres de archivos y campos, y en la documentación técnica. La interfaz es **bilingüe** (inglés y español); la columna *UI (es)* muestra cómo aparece cada término en español.

Reglas:
- Usá estos términos tal cual en el código y en la documentación. No inventes sinónimos (*POI*, *overlay item*, *corner pin*…).
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
| **Live view** | En vivo | La cámara en vivo con las banderas y respuestas pintadas sobre el canvas (realidad aumentada). | `LiveScreen`, `MarkerTracker` |
| **Explore** | Explorar | La vista con la snapshot y las banderas/respuestas proyectadas encima. | `ExploreScreen` |

## Contenido y preguntas sobre el mapa

| Término | UI (es) | Definición | En el código |
|---|---|---|---|
| **Area** | — (genérico) | Elemento que cubre una superficie: la forma de un país (puede tener varias piezas: islas, exclaves). | `Country.areas` |
| **Question** | Pregunta | Consulta sobre el mundo hecha por voz o texto (o elegida del historial) cuya respuesta ilumina países en el mapa. | `WorldQuestion`, `QuestionStore` |
| **Answer item** | — (interno) | Cada país que responde a una question, con su código ISO-3, un badge opcional y un detail opcional. | `AnswerItem` |
| **Badge** | — (en píldora) | Etiqueta corta (número abreviado como `1.4B`, `8.849 m`, `5 🏆` o 1-2 palabras) que se muestra en la píldora sobre el país. | `AnswerItem.badge` |
| **Detail** | — (al acercarse) | Descripción breve (máx. ~10 palabras) que aparece debajo del país cuando hay zoom corto (acercamiento) o al tocar el país. | `AnswerItem.detail` |

## Geometría (interno)

| Término | Definición | En el código |
|---|---|---|
| **Normalized space** | Coordenadas `[0,1]²` del mapa: (0,0) = anchor TL, (1,1) = anchor BR. | `PerspectiveProjector.normalizedCorners` |
| **Homography** | Matriz 3×3 que lleva el normalized space a píxeles de la snapshot o del preview. | `Homography` |
| **Projection** | Paso de lat/lon al normalized space (equirectangular). | `MapProjection` |
