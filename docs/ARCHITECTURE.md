# Arquitectura de Orbio

Orbio es una app Flutter (iOS, Android, macOS) **local-first y sin nube** que acompaña a un mapa mundi físico borrable, el **canvas** (contornos negros sobre tela blanca). El usuario saca una **snapshot** del canvas, la **calibra** alineando cuatro **corner handles** sobre las **anchors**, y la app proyecta **layers** (con **pins** y **areas**) sobre la foto congelada.

El vocabulario canónico está en [GLOSSARY.md](GLOSSARY.md). La interfaz es bilingüe (inglés y español).

Nada sale del dispositivo: todo el contenido viene empaquetado en `assets/` y es de solo lectura. Por ahora la familia no crea contenido propio (decisión de producto: primero iterar la app base).

---

## 1. Flujo principal

```
CameraScreen ──snapshot──▶ CalibrationScreen ──confirmar──▶ ExploreScreen
 (cámara / importar / demo)  (snapshot + 4 corner handles)    (InteractiveViewer + layers)
        │                          │                                 │
 SnapshotStore.saveSnapshot  AnchorDetector.detect           PerspectiveProjector
 SnapshotStore.createDemo…   (isolate en segundo plano)      MapOverlayPainter
                                                            CountryDetailSheet
```

1. **Snapshot (freeze-frame).** `CameraScreen` usa `camera` con `ResolutionPreset.max`, toma una foto fija, la copia a `Documents/orbio/snapshots/` y pausa el preview. Alternativas en todas las plataformas: **importar una foto** existente (`image_picker`: galería en móvil, diálogo de archivos en macOS) o una **demo snapshot** generada a partir del SVG imprimible.
2. **Calibrate.** `CalibrationScreen` decodifica la snapshot a `ui.Image`, coloca 4 corner handles por defecto (10 % hacia adentro) y lanza la detección de anchors en segundo plano. Al terminar, mueve los handles sobre las anchors detectadas. El usuario puede ajustarlos con una lupa.
3. **Explore.** `ExploreScreen` recibe la imagen y las 4 esquinas, construye la homografía y dibuja las capas con un `CustomPainter` dentro de un `InteractiveViewer`.

La navegación es `Navigator.push` con `MaterialPageRoute`; `main.dart` crea las dependencias (`MapRepository`, `SnapshotStore`) y las pasa por constructor.

---

## 2. Estructura de carpetas

```
lib/
├── main.dart                         # OrbioApp, tema, i18n, inyección de dependencias
├── l10n/                             # app_en.arb, app_es.arb (+ código generado por gen-l10n)
├── core/
│   └── geometry/
│       ├── homography.dart           # Matriz 3x3, solver DLT 8x8, inversa, toMatrix4
│       ├── perspective_projector.dart# Corner handles ⇄ coordenadas normalizadas [0,1]
│       ├── map_projection.dart       # lat/lon ⇄ normalizado (equirectangular)
│       └── anchor_detector.dart      # Detección de las 4 anclas tipo diana
│   └── tracking/                     # ArucoDetector, MarkerTracker, diccionario 4x4_50
├── data/
│   ├── models/                       # Country, Pin, Note, GeoPoint, MapLayer
│   └── repositories/
│       ├── map_repository.dart       # Lee el JSON de contenido (solo lectura)
│       └── snapshot_store.dart       # Guarda snapshots; genera la demo snapshot
└── presentation/
    ├── l10n_labels.dart              # context.l10n y etiquetas traducidas de enums
    ├── screens/                      # CameraScreen, CalibrationScreen, ExploreScreen
    ├── painter/map_overlay_painter.dart
    └── widgets/                      # LayerToggleBar, CountryDetailSheet, MagnifierLoupe

assets/
├── flags/                            # banderas SVG (flag-icons, MIT) por iso2
├── data/world_sample.json            # 5 países curados (ARG, JPN, EGY, ESP, ISL)
└── maps/orbio_printable_canvas.svg   # Mapa imprimible 2:1 con 4 anclas

test/
├── geometry_test.dart                # Homografía, proyector, proyección
└── anchor_detector_test.dart         # Detección sintética + SVG real en perspectiva
```

Regla de dependencias: `presentation → data → core`. `core/` no conoce Flutter widgets (solo `dart:ui` para `Offset`/`Size` y decodificación de imagen).

---

## 3. Sistemas de coordenadas

Hay tres espacios y todo el diseño gira en torno a convertir entre ellos:

| Espacio | Unidades | Origen | Quién lo usa |
|---|---|---|---|
| **Geográfico** | lat/lon (WGS84, grados) | — | `world_sample.json`, modelos |
| **Normalizado** | `[0,1] × [0,1]` | (0,0) = ancla TL = lon −180, lat 90 | Hit-testing, proyección |
| **Imagen** | píxeles de la foto | esquina sup. izq. de la foto | Corner handles, painter, detector |

- Geográfico → normalizado: `MapProjection.toNormalized(lat, lon)` = `((lon+180)/360, (90−lat)/180)`.
- Normalizado ⇄ imagen: `PerspectiveProjector`, que envuelve una homografía.

**Contrato clave:** los centros de las 4 anclas del mapa impreso son exactamente los bordes del mundo normalizado:

| Ancla | Normalizado | Geográfico |
|---|---|---|
| TL | (0, 0) | lon −180, lat 90 |
| TR | (1, 0) | lon 180, lat 90 |
| BR | (1, 1) | lon 180, lat −90 |
| BL | (0, 1) | lon −180, lat −90 |

Los corner handles siempre se ordenan `[TL, TR, BR, BL]` (sentido horario).

---

## 4. Geometría (`lib/core/geometry/`)

### 4.1 `Homography`
- Matriz 3×3 en orden de filas, Dart puro.
- `fromCorrespondences(src, dst)`: transformación lineal directa (DLT) con `h8 = 1` → sistema lineal 8×8 resuelto con eliminación gaussiana con pivoteo parcial. Lanza `DegenerateHomographyException` si los puntos son colineales o coincidentes.
- `transform(p)` hace la división proyectiva; `inverse()` usa la adjunta; `compose()` multiplica.
- `toMatrix4()` embebe la homografía en una `Matrix4` (vector_math) para usarla con `Canvas.transform` (lo usa la demo snapshot).

### 4.2 `PerspectiveProjector`
- Construye `mapToImage` = homografía de `[(0,0),(1,0),(1,1),(0,1)]` → corner handles, y su inversa `imageToMap`.
- `geoToImage(lat, lon)` encadena proyección equirectangular + homografía.
- Helpers: `defaultCornerPins` (10 % hacia adentro), `isConvexQuad` (evita cuadriláteros cruzados que "doblan" la homografía), `polygonArea`.

### 4.3 `AnchorDetector`
API pública: `Future<List<Offset>> detectAnchorPoints(Uint8List imageBytes, Size imageSize)` → `[TL, TR, BR, BL]` en píxeles de imagen. `AnchorDetector.detect` devuelve además confianza y si cada esquina fue detectada o es fallback.

Pipeline:
1. **Decodificación reducida**: `ui.instantiateImageCodec` con `targetWidth/Height` (lado mayor ≤ 960 px) → RGBA.
2. **Isolate** (`compute`): RGBA → escala de grises → `scanGray`.
3. **Umbral adaptativo**: imagen integral para la media local; un píxel es "oscuro" si está ≥18 niveles y ≥20 % por debajo de su media. Se guarda la "oscuridad" por píxel (sirve como peso).
4. **Componentes conexos** (4-conectividad, flood fill iterativo).
5. **Filtro de forma**: no toca el borde, tamaño ≤ 18 % del lado menor, relación de aspecto ≤ 1.6, relleno entre 20 % y 95 %.
6. **Chequeo de diana**: se muestrean las diagonales (para esquivar las líneas de la cruz) — centro oscuro, anillo intermedio claro, anillo exterior oscuro.
7. **Puntaje** = forma + simetría + diana, ponderado por cercanía a la esquina de la foto de ese cuadrante. Se queda el mejor por cuadrante.
8. **Centroide sub-píxel** ponderado por oscuridad, reescalado a la resolución completa.
9. **Fallback**: esquina con puntaje < 0.55 → punto por defecto al 10 %. Si el cuadrilátero resultante no es convexo o cubre < 5 % de la foto → las 4 esquinas por defecto. Cualquier excepción → fallback (nunca lanza).

---

## 5. Mapa imprimible (`assets/maps/orbio_printable_canvas.svg`)

- `viewBox` 800×400 (2:1).
- Contornos continentales simplificados, trazo negro de 1.5 px, más mares interiores (Caspio, Negro).
- 4 anclas a 20 px de cada borde: disco negro r=12, anillo blanco r=8, cruz fina, punto negro r=3.5, y etiqueta TL/TR/BR/BL separada ~30 px hacia adentro (para que no se pegue al componente del ancla).
- El mapa equirectangular se dibuja **entre los centros de las anclas** (760×360 unidades), cumpliendo el contrato de la sección 3.
- Se generó con un script; si se modifican los contornos hay que respetar esa caja.
- Los requerimientos del canvas físico (póster impreso y producto fabricado) están en [PHYSICAL_CANVAS.md](PHYSICAL_CANVAS.md).

---

## 6. Datos y persistencia

### `world_sample.json`
```jsonc
{
  "version": 1,
  "data_as_of": "2025-10",           // los gobernantes cambian: verificar
  "countries": [{
    "code": "ARG", "name": "Argentina", "flag": "🇦🇷",
    "capital":  { "name": "Buenos Aires", "lat": -34.60, "lon": -58.38 },
    "centroid": { "lat": -33.5, "lon": -64.2 },     // punto de etiqueta de Natural Earth
    "areas":    [[[-68.6, -52.6], ...], ...],        // anillos Natural Earth 1:110m, [lon, lat]
    "government_type": "...",              // texto libre (se muestra en la hoja)
    "government_system": "presidential_republic|parliamentary_republic|constitutional_monarchy|absolute_monarchy",
    "iso2": "ar",                          // bandera: assets/flags/ar.svg
    "head_of_state": { "title": "President", "name": "..." },
    "head_of_government": null,
    "pins": [{ "id", "name", "kind": "volcano|peak|depression",
                             "lat", "lon", "elevation_m", "description" }],
    "notes": [{ "kind": "fact|story", "text": "..." }]   // curated notes
  }]
}
```

### `MapRepository`
- `loadCountries()` lee el JSON del bundle (cacheado en memoria).
- Las `notes` del JSON se exponen como `Country.notes` (`Note`, kinds `fact`/`story`), de solo lectura.
- No hay persistencia de datos del usuario: lo único que se guarda en disco son las snapshots.

### `SnapshotStore`
- `saveSnapshot(path)` copia la foto (cámara o importada) a `Documents/orbio/snapshots/`.
- `createDemoSnapshot()` rasteriza el SVG con `flutter_svg`, le aplica una homografía (simula foto en ángulo sobre una mesa) y guarda un PNG de 2400×1600.

---

## 7. Presentación

### `CalibrationScreen`
- La foto se dibuja con `RawImage` escalada con *contain*; `toScreen(p) = origin + p * scale`.
- Cada corner handle es un `GestureDetector` de 56 px; el arrastre suma `delta / scale` en píxeles de imagen.
- `_QuadPainter` dibuja el cuadrilátero (rojo si no es convexo) y anillos verdes (detectado) o ámbar (fallback).
- **Lupa** (`MagnifierLoupe`): mientras se arrastra, `drawImageRect` del área bajo el handle a ≥3 px de pantalla por píxel de foto, con `FilterQuality.none` para ver píxeles nítidos, mira roja y coordenadas. Aparece arriba del dedo (o abajo si no entra).
- Botones: **Auto-Detect** (relanza detección; un contador descarta resultados viejos), **Reset Anchors** (vuelve al 10 %), **Explore** (valida convexidad y navega).

### `ExploreScreen`
- `InteractiveViewer` → `FittedBox` → `SizedBox(anchoImagen, altoImagen)`: el contenido se pinta en **píxeles de imagen**, así el `onTapUp` ya da coordenadas de foto.
- `labelScale = 1 / (fitScale × zoom)` mantiene texto y marcadores de tamaño constante en pantalla al hacer zoom (se recalcula escuchando el `TransformationController`).

### `MapOverlayPainter`
- **Flags** (por defecto): cada area se rellena con la bandera del país (`assets/flags/<iso2>.svg`, de `flag-icons` 7.2.3, MIT). La bandera se escala para cubrir el bounding box del país en el mapa 2:1, se compone con la homografía (`mapToImageMatrix.compose(flagToNormalized)`) para que quede deformada con la perspectiva de la snapshot, se recorta al contorno y se pinta al 72 % de opacidad para que se vean los contornos impresos. Más el nombre del país.
- **Government**: area coloreada según `GovernmentSystem` (república presidencial o parlamentaria, monarquía constitucional o absoluta) y 👑 sobre la capital de las monarquías. Leyenda fija (`_GovernmentLegend` en `ExploreScreen`) con solo los sistemas presentes. Colores en `GovernmentStyle`.
- Flags y Government son excluyentes (`MapLayer.toggle`): prender una apaga la otra.
- **Países chicos**: si `√(área proyectada) / labelScale` < 40 px de pantalla (`isSmallOnScreen`), en vez de rellenar se dibuja un marcador en el centroide: ícono de bandera (26×19.5 px) en Flags, o punto de color en Government, con el nombre debajo. Al hacer zoom el país crece en pantalla y vuelve a rellenarse.
- **Physical**: pins: triángulos para volcanes (rojo, con humo) y montañas (marrón), triángulo invertido para depresiones; etiqueta con elevación formateada con `intl`.
- `countryAt(...)`: punto en polígono en espacio normalizado; si no hay, centroide más cercano dentro de 36 px de pantalla.

### `CountryDetailSheet`
Bottom sheet arrastrable, de solo lectura, con datos políticos, pins físicos y notas (facts y stories).

---

## 7a. Geografía: una sola fuente

Todo sale de **Natural Earth 1:110m** (dominio público, `tool/natural_earth/`, v5.1.2):

| Script | Lee | Escribe |
|---|---|---|
| `tool/generate_canvas.py` | costas y fronteras | `assets/maps/orbio_printable_canvas.svg` (costa 1.2 u, fronteras 0.4 u, anchors, markers) y `canvas_markers.json` |
| `tool/generate_poster.py` | lo mismo, vía `generate_canvas` | `print/*.pdf` |
| `tool/build_country_shapes.py` | formas de países | `areas` y `centroid` de cada país en `world_sample.json` |

- Se omiten los bordes artificiales: el borde sur de la Antártida (−90°) y los cortes en el antimeridiano.
- **Zonas de exclusión**: ninguna línea se dibuja a menos de 28 u del centro de un anchor ni sobre su etiqueta (R4). Sin esto, la costa de la Antártida tocaba los anchors BL y BR y la detección fallaba.
- **Areas de varias piezas** (`Country.areas`): islas, exclaves y huecos, rellenados even-odd. Para la bandera, la parte principal y las cercanas comparten una (`MapOverlayPainter.flagGroups`); las partes lejanas llevan la suya.

## 7b. Live view (realidad aumentada, prueba técnica en la rama `ar-spike`)

Alternativa a la snapshot: la cámara en vivo con las banderas pintadas encima. Acercar el teléfono es el zoom; no hace falta ver el canvas entero.

```
CameraController.startImageStream (yuv420)
  → plano Y (gris), submuestreado a ~640 px
  → compute(): ArucoDetector.detect → MarkerTracker.track
  → Homography.fromPoints(esquinas normalizadas de cada marker, esquinas en el cuadro)
  → cuadro → widget de preview → suavizado de las 4 esquinas del mapa
  → MapOverlayPainter(layers: {flags}, floatingNames: true)
```

- **Markers**: 50 ArUco `DICT_4X4_50` (patrones oficiales de OpenCV 4.10.0, en `lib/core/tracking/aruco_dictionary.dart`) impresos en los océanos del canvas. `assets/maps/canvas_markers.json` tiene las esquinas normalizadas de cada uno. Los genera `tool/generate_canvas.py`.
- **`ArucoDetector`** (Dart puro, sin OpenCV): umbral adaptativo → componentes 8-conexos → contorno (Moore) → Douglas–Peucker → cuadrilátero convexo → esquinas sub-píxel (recta ajustada por lado) → lectura de la grilla 6×6 → código en 4 rotaciones con ≤ 1 bit de error. Se descartó `opencv_dart`: con ArUco obliga a compilar OpenCV desde fuente y falla con Xcode 27.
- **`MarkerTracker`**: con un solo marker alcanza; con varios, la homografía sale por mínimos cuadrados (normalización de Hartley + ecuaciones normales).
- **Orientación**: en iOS los cuadros llegan ya rotados a la orientación del dispositivo; la pantalla se bloquea en vertical. Si el aspecto del cuadro no coincide con el de la preview (Android), se rota según `sensorOrientation`.
- **Seguimiento perdido**: si no se ve ningún marker por 600 ms, se oculta la capa.
- **Debug** (activado por defecto en la prueba): contorno e id de cada marker y ms por cuadro.

## 8. Tests

| Archivo | Qué cubre |
|---|---|
| `geometry_test.dart` | Homografía exacta en las 4 correspondencias, ida y vuelta con la inversa, puntos degenerados, `toMatrix4`, anclas → (0,0)/(1,0)/(1,1)/(0,1), convexidad, proyección. |
| `tracking_test.dart` | Homografía por mínimos cuadrados con ruido; canvas real renderizado en perspectiva: vista completa (50/50 markers), girada 180° y primer plano parcial; ids, esquinas (≤ 2.5 px) y homografía resultante. |
| `anchor_detector_test.dart` | Dianas sintéticas con distractores (error < 0.6 px), imagen vacía, fallback al 10 %, bytes inválidos, y **end-to-end**: SVG real renderizado en perspectiva sobre fondo oscuro → 4/4 anclas con error < 2.5 px. |

---

## 9. Limitaciones conocidas

- El plugin oficial `camera` **no soporta macOS**: ahí se usa **importar foto** (`image_picker`, diálogo de archivos) o la demo snapshot.
- Las fotos HEIC pueden no decodificarse en todas las plataformas; JPEG y PNG siempre funcionan.
- La detección requiere que el mapa físico tenga las anclas impresas; sin ellas cae al posicionamiento manual.
- No se aplica corrección de distorsión de lente: la homografía asume que el mapa es plano y la lente rectilínea.
- La calibración no se persiste entre sesiones; cada captura se calibra de nuevo.
- Los gobernantes del JSON son de octubre de 2025.
- El contenido (nombres de países, notas curadas, descripciones de pins) todavía está solo en inglés; la i18n cubre la interfaz. Se resolverá con los packs.
