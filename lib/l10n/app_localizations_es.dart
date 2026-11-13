// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Orbio';

  @override
  String get cameraImportTooltip => 'Importar una foto del lienzo';

  @override
  String get cameraDemoTooltip => 'Probar con una captura demo';

  @override
  String get cameraResumeTooltip => 'Reanudar última calibración';

  @override
  String get cameraResumeButton => 'Reanudar última calibración';

  @override
  String get cameraResumeUnavailable =>
      'No se encontró una calibración anterior.';

  @override
  String cameraResumeFailed(String details) {
    return 'No se pudo reanudar el último mapa: $details';
  }

  @override
  String get cameraCaptureTooltip => 'Sacar captura';

  @override
  String get cameraFramingHint =>
      'Sostené el teléfono derecho sobre el lienzo.\nQue se vean las 4 anclas.';

  @override
  String get cameraNotFound => 'No se encontró una cámara en este dispositivo.';

  @override
  String get cameraUnavailable => 'La cámara no está disponible acá.';

  @override
  String get cameraAccessDenied =>
      'Se denegó el acceso a la cámara. Habilitalo para Orbio en Ajustes.';

  @override
  String cameraError(String details) {
    return 'Error de cámara: $details';
  }

  @override
  String get cameraTakePhotoButton => 'Sacar foto con la cámara';

  @override
  String get cameraPickGalleryButton => 'Elegir foto de la galería';

  @override
  String get cameraDemoButton => 'Probar mapa de ejemplo (sin papel)';

  @override
  String get cameraRetryButton => 'Reintentar cámara';

  @override
  String cameraImportFailed(String details) {
    return 'No se pudo importar la foto: $details';
  }

  @override
  String cameraDemoFailed(String details) {
    return 'No se pudo crear la captura demo: $details';
  }

  @override
  String get calibrateTitle => 'Calibrar';

  @override
  String get calibrateConfirmTooltip => 'Usar estas esquinas';

  @override
  String calibrateLoadFailed(String details) {
    return 'No se pudo abrir la foto: $details';
  }

  @override
  String get calibrateDetecting => 'Buscando anclas…';

  @override
  String get calibrateFoundAll =>
      'Se encontraron las 4 anclas. Ajustá si hace falta.';

  @override
  String get calibrateFoundNone =>
      'No se encontraron anclas. Arrastrá las esquinas a las esquinas del lienzo.';

  @override
  String calibrateFoundSome(int count) {
    return 'Se encontraron $count de 4 anclas. Ubicá el resto a mano.';
  }

  @override
  String get calibrateCrossed =>
      'Las esquinas se cruzan. Ubicalas en sentido horario: TL, TR, BR, BL.';

  @override
  String get calibrateHint => 'Arrastrá cada esquina sobre un ancla';

  @override
  String calibrateDetectedStatus(int count) {
    return 'Detectadas $count/4';
  }

  @override
  String get calibrateReset => 'Reiniciar anclas';

  @override
  String get calibrateAutoDetect => 'Detectar';

  @override
  String get calibrateExplore => 'Explorar';

  @override
  String cornerHandleSemantics(String corner) {
    return 'Esquina $corner';
  }

  @override
  String get exploreTitle => 'Explorar';

  @override
  String get exploreResetZoom => 'Restablecer zoom';

  @override
  String get exploreRecalibrate => 'Recalibrar';

  @override
  String get exploreHint => 'Hacé zoom o tocá un país para leer su detalle';

  @override
  String exploreLoadFailed(String details) {
    return 'No se pudieron cargar los datos del mapa: $details';
  }

  @override
  String get cameraLiveTooltip => 'Vista en vivo';

  @override
  String get liveTitle => 'En vivo';

  @override
  String get liveSearching => 'Apuntá la cámara al lienzo';

  @override
  String get liveDebugTooltip => 'Ver detalles del seguimiento';

  @override
  String liveDebugStats(int markers, int ms) {
    return '$markers marcadores · $ms ms';
  }

  @override
  String get liveUnavailable =>
      'La vista en vivo necesita cámara (iPhone o Android).';

  @override
  String get questionHint => 'Preguntá algo sobre el mundo…';

  @override
  String get questionAllFlags => 'Todas las banderas';

  @override
  String get questionClearTooltip => 'Ver todas las banderas';

  @override
  String get questionHistoryTitle => 'Preguntas';

  @override
  String get questionAskButton => 'Preguntar';

  @override
  String get questionListening => 'Escuchando… tocá para enviar';

  @override
  String get questionMicTooltip => 'Preguntar por voz';

  @override
  String get questionMicUnavailable =>
      'El dictado por voz no está disponible acá. Escribí tu pregunta abajo.';

  @override
  String get questionThinking => 'Pensando…';

  @override
  String get questionEmptyResult =>
      'No se encontraron países para esa pregunta.';

  @override
  String get questionCloseUpHint =>
      'Acercate o hacé zoom sobre un país para leer su descripción';

  @override
  String get questionCollapseTooltip => 'Ocultar barra de preguntas';

  @override
  String get questionExpandTooltip => 'Hacer o ver preguntas';

  @override
  String get llmSettingsTitle => 'Proveedor de IA';

  @override
  String get llmProviderLabel => 'Proveedor';

  @override
  String get llmModelLabel => 'Modelo';

  @override
  String get llmApiKeyLabel => 'Clave API';

  @override
  String get llmApiKeyHint => 'Pegá tu clave API';

  @override
  String get llmOllamaUrlLabel => 'URL de Ollama';

  @override
  String get llmOllamaUrlHint => 'http://192.168.1.x:11434';

  @override
  String get llmSaveButton => 'Guardar';

  @override
  String get llmMissingKeyPrompt =>
      'Configurá un proveedor de IA (Gemini, ChatGPT, Claude u Ollama local) para hacer preguntas nuevas.';

  @override
  String get projectionOrbioCanvas => 'Lienzo Orbio';

  @override
  String get projectionSchoolMap => 'Mapa escolar';

  @override
  String get projectionLabel => 'Proyección';

  @override
  String get homeScanSchoolMap => 'Escanear mapa escolar';

  @override
  String get homeScanSchoolMapSubtitle =>
      'Sacá una foto a cualquier póster o mapa y exploralo con IA';

  @override
  String get homeOrbioCanvas => 'Lienzo Orbio y AR';

  @override
  String get homeOrbioCanvasSubtitle =>
      'Detección automática con anclas y seguimiento AR en vivo';

  @override
  String get homeDownloadCanvas => 'Descargar lienzo para imprimir (PDF)';

  @override
  String get homeOpenLive => 'Abrir Live AR';
}
