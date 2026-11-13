# Cómo probar Orbio en un iPhone

Guía para instalar y correr la app en un iPhone físico desde la Mac. Es la única forma de probar la **cámara en vivo**: en macOS la cámara no funciona y el simulador de iOS no tiene cámara.

Requisitos previos: Flutter, Xcode y CocoaPods instalados, con `flutter doctor` en verde para Xcode (ver [TESTING_MACOS.md](TESTING_MACOS.md) §1).

---

## 1. Primera vez (configuración)

### 1.0 Verificar que la consola apunte a Xcode
Si es la primera vez que usás Xcode en la Mac, asegurate de que las herramientas de línea de comandos apunten a Xcode completo (si no, `flutter devices` no va a detectar el iPhone):
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

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
5. Si aparece un error con el **Bundle Identifier**: tiene que ser único en todo Apple. Cambialo por uno propio (por ejemplo `com.<tu-nombre>.orbio`), apretá **Enter** para que se guarde en `ios/Runner.xcodeproj/project.pbxproj`, y volvé a elegir el Team.
6. Si Xcode ofrece descargar e instalar el runtime/soporte de iOS o del dispositivo, aceptá y esperá a que termine de descargar y verificar.

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

# Pasar la clave de Gemini exportada en tu shell:
export GEMINI_API_KEY="tu_api_key_aqui"
flutter run --release -d <id-del-iphone> --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY"
```

- **Debug** es más lento a propósito (incluye herramientas de depuración). Sirve para desarrollar, no para medir.
- **Release** es la velocidad real. Usalo para evaluar la cámara, la detección de anclas y cualquier prueba de realidad aumentada.
- La primera vez que abras la cámara, la app pide permiso: aceptá. Si lo rechazaste, se habilita en **Ajustes → Orbio → Cámara**.

### Sin cable (Wi-Fi)
1. Con el iPhone conectado por cable: **Xcode → Window → Devices and Simulators** → elegí el iPhone → tildá **Connect via network**.
2. Desde entonces, con la Mac y el iPhone en la misma red Wi-Fi, `flutter devices` lo muestra sin cable.

---

## 3. Configurar el proveedor de IA (Gemini, ChatGPT, Claude u Ollama)

Las 3 preguntas precargadas en el historial funcionan sin conexión ni clave. Para hacer preguntas nuevas por voz o texto, configurá un proveedor de IA:

### 3.1 Cómo obtener tu API Key de Gemini (gratis, en 30 segundos)
1. Entrá a **Google AI Studio**: https://aistudio.google.com/apikey
2. Iniciá sesión con tu cuenta de Google.
3. Tocá **"Create API key"** (arriba a la derecha).
4. Elegí cualquier proyecto existente o **"Create API key in new project"** y copiá la clave.
   - El tier gratuito incluye miles de consultas diarias sin costo y sin tarjeta de crédito.

### 3.2 Cómo cargarla en Orbio
- **Al compilar desde la Mac (recomendado para desarrollo):**
  Exportá la variable en tu terminal (o agregala a tu `~/.zshrc`):
  ```bash
  export GEMINI_API_KEY="tu_api_key_aqui"
  flutter run --release -d <id-del-iphone> --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY"
  ```
- **Desde la app (se guarda en el iPhone):** tocá la barra inferior (**Preguntas**) → ícono de configuración **⚙️** arriba a la derecha → pegá tu API key y tocá **Guardar**.
  - Los proveedores cloud (Gemini, OpenAI, Claude) tienen el modelo calibrado y fijado automáticamente (`gemini-2.5-flash`, `gpt-4o-mini`, `claude-3-5-haiku-latest`) para evitar errores de tipeo y desbordes de cuota.

### 3.3 Consultas útiles por terminal (cURL) con `$GEMINI_API_KEY`

Podés diagnosticar y probar la conexión con Google directamente desde la terminal de tu Mac usando la variable `$GEMINI_API_KEY`:

#### 1. Listar los modelos habilitados para tu clave
Permite verificar que la clave sea válida y ver qué identificadores de modelo soporta tu cuenta:
```bash
curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY" | grep '"name":'
```
*Salida esperada (incluye `gemini-2.5-flash` y `gemini-flash-latest`):*
```text
      "name": "models/gemini-2.5-flash",
      "name": "models/gemini-flash-latest",
```

> **Nota sobre error 404:** Si una petición devuelve `HTTP 404: models/... is not found for API version v1beta`, significa que el modelo pedido no está en el catálogo de tu cuenta. Orbio usa `gemini-2.5-flash` (y cae automáticamente a `gemini-flash-latest`). Además, las claves de nuevo formato requieren el encabezado `x-goog-api-key`.

#### 2. Prueba rápida de generación de texto
```bash
curl -i "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -d '{"contents":[{"role":"user","parts":[{"text":"¿Qué países ganaron mundiales?"}]}]}'
```

#### 3. Prueba con el esquema JSON estructurado exacto de Orbio
Esta es la misma consulta que hace la app internamente, forzando un JSON estricto con códigos ISO-3, píldoras y resumen:
```bash
curl -i "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -d '{
    "contents": [
      {
        "role": "user",
        "parts": [{"text": "¿Qué países ganaron la Copa del Mundo de fútbol?"}]
      }
    ],
    "generationConfig": {
      "temperature": 0.2,
      "responseMimeType": "application/json",
      "responseSchema": {
        "type": "OBJECT",
        "properties": {
          "summary": {"type": "STRING"},
          "ordered": {"type": "BOOLEAN"},
          "items": {
            "type": "ARRAY",
            "items": {
              "type": "OBJECT",
              "properties": {
                "code": {"type": "STRING"},
                "badge": {"type": "STRING"},
                "detail": {"type": "STRING"}
              },
              "required": ["code"]
            }
          }
        },
        "required": ["summary", "ordered", "items"]
      }
    }
  }'
```

### 3.4 Alternativa con Ollama local en tu Mac (sin API key)
  1. Por defecto Ollama solo escucha en `127.0.0.1` (la propia Mac). Para que tu iPhone pueda entrar por Wi-Fi, en la Mac habilitá `0.0.0.0`:
     - Si usás la app de barra de menú de Ollama: cerrala y corré en la terminal `OLLAMA_HOST=0.0.0.0 ollama serve` (o ejecutá `launchctl setenv OLLAMA_HOST "0.0.0.0"` y reiniciá la app de Ollama).
  2. Averiguá la IP Wi-Fi de tu Mac en la terminal:
     ```bash
     ipconfig getifaddr en0
     ```
  3. En la app del iPhone: tocá la barra inferior (**Preguntas**) → botón del proveedor arriba a la derecha → elegí **Ollama (Local)**.
  4. En **URL de Ollama** poné `http://<IP-de-tu-Mac>:11434` (ej. `http://192.168.1.45:11434`) y tocá el ícono `🔄`: la app consulta `/api/tags` en tu Mac y te muestra como chips todos los modelos que tenés instalados para elegir con un toque (y si dejás el campo Modelo vacío, usa automáticamente el primero instalado).

---

## 4. Qué probar

Con el póster armado según [PHYSICAL_CANVAS.md](PHYSICAL_CANVAS.md):

- [ ] La cámara muestra la vista en vivo con el marco guía 2:1.
- [ ] Sacá la snapshot desde arriba, con las 4 anchors en cuadro, luz pareja y sin flash.
- [ ] En Calibrate se detectan las 4 anchors (handles verdes). Si no, ajustá a mano con la lupa.
- [ ] En Explore, las banderas caen sobre los países impresos.
- [ ] Probá también **Import canvas photo**, que abre la galería del iPhone, y la demo snapshot.

### Live view y preguntas por voz / IA

Imprimí el póster (con los cuadraditos en los océanos) y corré en release: `flutter run --release -d <id>`.

- [ ] En la pantalla de cámara tocá el ícono 🧊 (Live view).
- [ ] En el modo por defecto (**Todas las banderas**), apuntá al póster: aparecen las banderas pintadas sobre los países y los nombres flotando.
- [ ] Tocá la barra inferior (**Preguntas**) y elegí una de las preguntas precargadas (ej. *¿Qué países ganaron mundiales de fútbol?*) o preguntá una nueva con el micrófono (`🎤`) tras configurar tu clave en **Proveedor de IA**.
- [ ] Se pintan las banderas dentro de las fronteras de los países de la respuesta y su píldora flotante con la bandera y el ranking (`#1 · 🇧🇷 Brasil · 5 🏆`), con la vista despejada y sin tarjetas de descripción invasivas.
- [ ] El modo debug (ícono 🐞, activo por defecto) muestra cada marker detectado en verde con su número, y arriba a la izquierda `N marcadores · X ms`.

El resto del checklist de Calibrate y Explore es igual al de [TESTING_MACOS.md](TESTING_MACOS.md) §4.

---

## 5. Limitaciones de la cuenta gratuita

| Tema | Cuenta gratuita | Apple Developer Program (99 USD/año) |
|---|---|---|
| Vencimiento de la app instalada | **7 días**; se reinstala con `flutter run` | 1 año |
| Apps instaladas a la vez | hasta 3 | sin límite práctico |
| Distribuir a otros (TestFlight, App Store) | no | sí |

---

## 6. Problemas comunes

| Síntoma | Solución |
|---|---|
| `flutter devices` no muestra el iPhone (o `xcrun: error: unable to find utility "devicectl"`) | Corré `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` y `sudo xcodebuild -runFirstLaunch` (§1.0). Además, desbloqueá el iPhone, revisá el cable, aceptá "Confiar" y verificá el Modo desarrollador. |
| `No valid code signing certificates were found` | Falta el Team en Signing & Capabilities (§1.3). |
| `Failed to register bundle identifier` | El Bundle Identifier ya existe en otra cuenta: cambialo y apretá Enter para que se guarde en `ios/Runner.xcodeproj/project.pbxproj` (§1.3, paso 5). |
| "Desarrollador no confiable" al abrir la app | §1.5. |
| La app dejó de abrir después de una semana | Venció la firma gratuita: `flutter run -d <id>` de nuevo. |
| `Could not run build/ios/...` o errores de CocoaPods | `cd ios && pod install && cd ..` y reintentar; si sigue, `flutter clean && flutter pub get`. |
| La app va lenta | Estás en debug: probá con `--release`. |
