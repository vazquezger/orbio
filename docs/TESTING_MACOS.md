# Cómo probar Orbio en macOS

Guía para correr los tests y probar la app a mano en una Mac.

> **Importante:** el plugin oficial `camera` no tiene implementación para macOS. En la Mac la pantalla de cámara muestra *"Camera is not available here."* y se prueba todo el flujo **importando una foto** del canvas o con la **demo snapshot** (el mapa imprimible renderizado en ángulo sobre una mesa). Para probar con la cámara real hay que usar un iPhone o un Android físico.

---

## 1. Requisitos (una sola vez)

### 1.1 Flutter
Ya está instalado con Homebrew (`/opt/homebrew/bin/flutter`, versión 3.47.x). Verificalo con:

```bash
flutter --version
```

Si no estuviera: `brew install --cask flutter`.

### 1.2 Xcode (obligatorio para compilar la app de macOS)
1. Instalá **Xcode** desde la App Store (no alcanza con las Command Line Tools).
2. Apuntá las herramientas a Xcode y completá el primer arranque:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   sudo xcodebuild -license accept
   ```
3. Si `flutter doctor` pide CocoaPods:
   ```bash
   brew install cocoapods
   ```

### 1.3 Verificar el entorno
```bash
flutter doctor
```
La línea **Xcode** tiene que estar en verde. Las de Android o Chrome pueden ignorarse para esta prueba.

---

## 2. Tests automáticos (no necesitan Xcode)

Desde la raíz del proyecto:

```bash
cd orbio   # la carpeta donde clonaste el repo
flutter pub get
flutter analyze
flutter test
```

Resultado esperado:
- `flutter analyze` → `No issues found!`
- `flutter test` → `All tests passed!` (17 tests).

En el test *"undecodable bytes fall back gracefully"* se imprime un stack trace `Invalid image data`: **es esperado**. El test le pasa bytes basura al detector a propósito para comprobar que cae al fallback sin romperse.

Para correr solo un archivo:
```bash
flutter test test/anchor_detector_test.dart
flutter test test/geometry_test.dart
flutter test test/l10n_test.dart
```

---

## 3. Correr la app en macOS

```bash
flutter run -d macos
```

La primera compilación tarda unos minutos. Con la app abierta, en la terminal:
- `r` → hot reload
- `R` → hot restart
- `q` → salir

Si macOS pide permiso de cámara, aceptá o rechazá: en cualquier caso el plugin no funciona en macOS y se usa importar foto o la demo snapshot.

**Idioma:** la app sigue el idioma de macOS (Configuración del Sistema → General → Idioma y región). Para probar la otra traducción, poné español o inglés primero en la lista, o agregá Orbio en "Idiomas de las apps". Abajo los textos aparecen en inglés, con el español entre paréntesis.

---

## 4. Checklist de prueba manual

### 4.1 Pantalla de cámara
- [ ] Aparece *"Camera is not available here."* con los botones **Import canvas photo** (Importar foto del lienzo), **Use demo snapshot** (Usar captura demo) y **Retry camera**.
- [ ] **Import canvas photo** (o el ícono 🖼 de la barra) abre el diálogo de archivos de macOS. Elegí una foto JPEG o PNG del póster: pasa a Calibración. Si cancelás, no pasa nada.
- [ ] El ícono 🌐 de la barra superior también genera la demo snapshot.

### 4.2 Calibrate
Tocá **Use demo snapshot**.
- [ ] Aparece la foto congelada: un mapa blanco en ángulo sobre fondo marrón.
- [ ] Se ve el chip *"Finding anchors…"* y luego el snackbar **"Found all 4 anchors."**
- [ ] Los 4 corner handles quedan **verdes** y centrados sobre las anchors TL, TR, BR, BL.
- [ ] Arrastrá un corner handle: aparece la **lupa** arriba del cursor, con píxeles nítidos, mira roja y coordenadas. Se puede centrar la diana con precisión de un píxel.
- [ ] Cerca del borde superior, la lupa se muestra debajo del handle.
- [ ] **Reset anchors** → los handles vuelven al 10 % hacia adentro y pasan a **ámbar**.
- [ ] **Auto-detect** → los handles vuelven a las anchors.
- [ ] Cruzá dos handles (por ejemplo TL a la derecha de TR): el cuadrilátero se pone **rojo** y **Explore** muestra *"The corner handles cross over…"*.

### 4.3 Explore
Con los handles bien puestos, tocá **Explore**.
- [ ] Capa **Flags** (Banderas) activa por defecto: Argentina, Japón, Egipto, España e Islandia pintados con su bandera, en perspectiva y recortados al contorno, con el nombre encima.
- [ ] Sin zoom, los países chicos (Islandia, España, Egipto, Japón) aparecen como **ícono de bandera** con el nombre debajo. Hacé zoom sobre España: pasa a estar pintada con la bandera.
- [ ] Activá **Government** (Gobierno): se apaga Flags; los países se colorean por forma de gobierno, aparece 👑 sobre Tokio y Madrid, y una leyenda abajo a la izquierda. Volvé a Flags: se apaga Government.
- [ ] Los contornos coloreados coinciden con los continentes del mapa de la foto. Es la prueba visual de que la homografía está bien.
- [ ] Activá **Physical** (Física): aparecen pins de volcanes (rojo con humo), montañas (marrón) y la Depresión de Qattara (azul, invertido) con su elevación.
- [ ] Zoom con pinch en el trackpad (o scroll): la foto se agranda pero **el texto mantiene su tamaño** en pantalla. 🔍 resetea el zoom.
- [ ] Tocá un país: se abre la hoja de detalle con secciones Political, Physical y Stories, de solo lectura.
- [ ] Tocá el mar: no se abre nada.

### 4.4 Volver a calibrar
- [ ] En Explore, el ícono ⛶ vuelve a Calibrate con los handles donde estaban.

---

## 5. Probar con un mapa impreso real

1. Imprimí y armá el póster siguiendo [PHYSICAL_CANVAS.md](PHYSICAL_CANVAS.md).
2. Fotografialo con el celular desde arriba, con las 4 dianas visibles, luz pareja y sin flash.
3. Pasá la foto a la Mac (AirDrop, cable, etc.) y abrila con **Import map photo**.
   - Las fotos de iPhone suelen venir en **HEIC**. Si la app no la abre, exportala como JPEG (en Fotos: Archivo → Exportar → JPEG) o configurá el iPhone en Ajustes → Cámara → Formatos → "Más compatible".
4. Para probar la cámara en vivo, corré la app en un iPhone: ver [TESTING_IPHONE.md](TESTING_IPHONE.md).

---

## 6. Dónde quedan los datos (sandbox de macOS)

La app de macOS corre en sandbox; el bundle id actual es `com.orbio.app`.

| Qué | Ruta |
|---|---|
| Snapshots (cámara, importadas, demo) | `~/Library/Containers/com.orbio.app/Data/Documents/orbio/snapshots/` |

Para empezar de cero, cerrá la app y borrá `~/Library/Containers/com.orbio.app`.

---

## 7. Problemas comunes

| Síntoma | Solución |
|---|---|
| `Xcode not installed` al compilar | Ver sección 1.2. |
| `CocoaPods not installed` | `brew install cocoapods` y luego `flutter run -d macos`. |
| `xcrun: error: unable to find utility "xcodebuild"` | `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` |
| La detección encuentra menos de 4 anclas | Normal si la foto no tiene las dianas o están cortadas o borrosas. Colocá los corner handles a mano con la lupa. |
| Errores raros después de cambiar dependencias | `flutter clean && flutter pub get` |
