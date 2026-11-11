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

El póster imprimible y las posiciones de sus marcadores se generan con `python3 tool/generate_canvas.py` (no editar el SVG a mano).

## Documentación

| Doc | Qué tiene |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Cómo está armada la app |
| [docs/GLOSSARY.md](docs/GLOSSARY.md) | Vocabulario (canvas, anchor, snapshot, layer, pin…) |
| [docs/PHYSICAL_CANVAS.md](docs/PHYSICAL_CANVAS.md) | Requisitos del mapa físico y cómo imprimir el póster |
| [docs/TESTING_MACOS.md](docs/TESTING_MACOS.md) | Probar en la Mac |
| [docs/TESTING_IPHONE.md](docs/TESTING_IPHONE.md) | Probar en un iPhone |
| [AGENTS.md](AGENTS.md) | Reglas para agentes de IA |
