# Orbio

App Flutter (iOS, Android, macOS), local-first y sin nube, que acompaña a un mapa mundi físico borrable: sacás una foto del mapa, se calibra con las 4 anclas impresas y se pintan encima banderas, formas de gobierno y relieve.

## Arrancar en una Mac nueva

```bash
# 1. Herramientas (una vez)
brew install --cask flutter
brew install cocoapods
# Xcode desde la App Store, y después:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
flutter doctor            # Flutter y Xcode en verde (Android es opcional)

# 2. Proyecto
git clone https://github.com/vazquezger/orbio.git
cd orbio
flutter pub get
flutter analyze && flutter test

# 3. Correr
flutter run -d macos      # en la Mac (sin cámara: importar foto o demo)
```

En VS Code instalá la extensión **Flutter** (`Dart-Code.flutter`).

El canvas y los PDFs para imprimir se generan con `python3 tool/generate_canvas.py && python3 tool/generate_poster.py` (y `python3 tool/build_country_shapes.py` para las formas de los países) (no editar el SVG ni los PDFs a mano).

## Imprimir el mapa

**[print/orbio_poster_6xA4.pdf](print/orbio_poster_6xA4.pdf)**: 6 hojas A4 horizontales que arman un póster de 72 × 36 cm. Imprimir al **100 %** (tamaño real). Para pruebas rápidas hay una versión de una sola hoja: [print/orbio_test_1xA4.pdf](print/orbio_test_1xA4.pdf). Cómo armarlo: [docs/PHYSICAL_CANVAS.md](docs/PHYSICAL_CANVAS.md) §2.

## Créditos

- Geografía: [Natural Earth](https://www.naturalearthdata.com/) 1:110m (dominio público).
- Banderas: [flag-icons](https://github.com/lipis/flag-icons) (MIT).
- Patrones de markers: ArUco `DICT_4X4_50` de [OpenCV](https://github.com/opencv/opencv) (Apache 2.0).

## Documentación

| Doc | Qué tiene |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Cómo está armada la app |
| [docs/GLOSSARY.md](docs/GLOSSARY.md) | Vocabulario (canvas, anchor, snapshot, layer, pin…) |
| [docs/PHYSICAL_CANVAS.md](docs/PHYSICAL_CANVAS.md) | Requisitos del mapa físico y cómo imprimir y armar el póster |
| [docs/TESTING_MACOS.md](docs/TESTING_MACOS.md) | Probar en la Mac |
| [docs/TESTING_IPHONE.md](docs/TESTING_IPHONE.md) | Probar en un iPhone |
| [AGENTS.md](AGENTS.md) | Reglas para agentes de IA |
