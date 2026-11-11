# Cómo probar Orbio en un iPhone

Guía para instalar y correr la app en un iPhone físico desde la Mac. Es la única forma de probar la **cámara en vivo**: en macOS la cámara no funciona y el simulador de iOS no tiene cámara.

Requisitos previos: Flutter, Xcode y CocoaPods instalados, con `flutter doctor` en verde para Xcode (ver [TESTING_MACOS.md](TESTING_MACOS.md) §1).

---

## 1. Primera vez (configuración)

### 1.1 Conectar el iPhone
1. Conectá el iPhone a la Mac con cable.
2. Desbloquealo y aceptá **"Confiar en esta computadora"**.

### 1.2 Activar el Modo desarrollador
1. En el iPhone: **Ajustes → Privacidad y seguridad → Modo desarrollador** → activar.
2. El iPhone se reinicia; al volver, confirmá **Activar**.

Si la opción no aparece, abrí Xcode con el iPhone conectado: eso la habilita.

### 1.3 Configurar la firma en Xcode
Apple exige que toda app instalada en un iPhone esté firmada. Alcanza con un Apple ID gratuito.

1. Abrí el proyecto de iOS:
   ```bash
   cd orbio   # la carpeta donde clonaste el repo
   open ios/Runner.xcworkspace
   ```
2. **Xcode → Settings → Accounts → +** → agregá tu Apple ID.
3. En el panel izquierdo elegí **Runner** (el ícono azul) → target **Runner** → pestaña **Signing & Capabilities**.
4. Tildá **Automatically manage signing** y en **Team** elegí tu nombre ("Personal Team").
5. Si aparece un error con el **Bundle Identifier**: tiene que ser único en todo Apple. Cambialo por uno propio (por ejemplo `com.orbio.app` o `com.<tu-nombre>.orbio`) y volvé a elegir el Team.
6. Si Xcode ofrece descargar el soporte de iOS o del dispositivo, aceptá y esperá a que termine.

### 1.4 Primera instalación
```bash
flutter devices                    # tiene que aparecer el iPhone
flutter run -d <id-del-iphone>
```
La primera compilación tarda unos minutos.

### 1.5 Autorizar al desarrollador en el iPhone
La primera vez, el iPhone bloquea la app porque la firmaste vos:

1. **Ajustes → General → VPN y gestión de dispositivos** → tu Apple ID → **Confiar**.
2. Volvé a correr `flutter run -d <id-del-iphone>`.

---

## 2. Uso diario

```bash
flutter devices                              # ver el id del iPhone
flutter run -d <id-del-iphone>               # debug: hot reload (r), hot restart (R), salir (q)
flutter run --release -d <id-del-iphone>     # release: para medir rendimiento real
```

- **Debug** es más lento a propósito (incluye herramientas de depuración). Sirve para desarrollar, no para medir.
- **Release** es la velocidad real. Usalo para evaluar la cámara, la detección de anclas y cualquier prueba de realidad aumentada.
- La primera vez que abras la cámara, la app pide permiso: aceptá. Si lo rechazaste, se habilita en **Ajustes → Orbio → Cámara**.

### Sin cable (Wi-Fi)
1. Con el iPhone conectado por cable: **Xcode → Window → Devices and Simulators** → elegí el iPhone → tildá **Connect via network**.
2. Desde entonces, con la Mac y el iPhone en la misma red Wi-Fi, `flutter devices` lo muestra sin cable.

---

## 3. Qué probar

Con el póster armado según [PHYSICAL_CANVAS.md](PHYSICAL_CANVAS.md):

- [ ] La cámara muestra la vista en vivo con el marco guía 2:1.
- [ ] Sacá la snapshot desde arriba, con las 4 anchors en cuadro, luz pareja y sin flash.
- [ ] En Calibrate se detectan las 4 anchors (handles verdes). Si no, ajustá a mano con la lupa.
- [ ] En Explore, las banderas caen sobre los países impresos.
- [ ] Probá también **Import canvas photo**, que abre la galería del iPhone, y la demo snapshot.

### Live view (rama `ar-spike`)

Imprimí el póster **nuevo** (con los cuadraditos en los océanos) y corré en release: `flutter run --release -d <id>`.

- [ ] En la pantalla de cámara tocá el ícono 🧊 (Live view).
- [ ] Apuntá al póster: aparecen las banderas pintadas sobre los países y los nombres flotando.
- [ ] El modo debug (ícono 🐞, activo por defecto) muestra cada marker detectado en verde con su número, y arriba a la izquierda `N marcadores · X ms`.
- [ ] Acercate a una zona (por ejemplo Sudamérica): las banderas siguen en su lugar aunque no se vea el póster entero.
- [ ] Al apuntar fuera del póster, las banderas desaparecen en menos de un segundo.
- [ ] Anotá: ¿las banderas tiemblan?, ¿se desfasan al mover rápido?, ¿cuántos ms tarda cada cuadro?, ¿desde qué distancia deja de detectar?

El resto del checklist de Calibrate y Explore es igual al de [TESTING_MACOS.md](TESTING_MACOS.md) §4.

---

## 4. Limitaciones de la cuenta gratuita

| Tema | Cuenta gratuita | Apple Developer Program (99 USD/año) |
|---|---|---|
| Vencimiento de la app instalada | **7 días**; se reinstala con `flutter run` | 1 año |
| Apps instaladas a la vez | hasta 3 | sin límite práctico |
| Distribuir a otros (TestFlight, App Store) | no | sí |

---

## 5. Problemas comunes

| Síntoma | Solución |
|---|---|
| `flutter devices` no muestra el iPhone | Desbloquealo, revisá el cable, aceptá "Confiar" y verificá que el Modo desarrollador esté activo. |
| `No valid code signing certificates were found` | Falta el Team en Signing & Capabilities (§1.3). |
| `Failed to register bundle identifier` | El Bundle Identifier ya existe en otra cuenta: cambialo (§1.3, paso 5). |
| "Desarrollador no confiable" al abrir la app | §1.5. |
| La app dejó de abrir después de una semana | Venció la firma gratuita: `flutter run -d <id>` de nuevo. |
| `Could not run build/ios/...` o errores de CocoaPods | `cd ios && pod install && cd ..` y reintentar; si sigue, `flutter clean && flutter pub get`. |
| La app va lenta | Estás en debug: probá con `--release`. |
