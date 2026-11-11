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
  String get cameraImportButton => 'Importar foto del lienzo';

  @override
  String get cameraDemoButton => 'Usar captura demo';

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
  String get exploreHint =>
      'Tocá un país para saber más · pellizcá para hacer zoom';

  @override
  String exploreLoadFailed(String details) {
    return 'No se pudieron cargar los datos del mapa: $details';
  }

  @override
  String get layerFlags => 'Banderas';

  @override
  String get layerGovernment => 'Gobierno';

  @override
  String get layerPhysical => 'Física';

  @override
  String get pinVolcano => 'Volcán';

  @override
  String get pinPeak => 'Montaña';

  @override
  String get pinDepression => 'Depresión';

  @override
  String elevationMeters(int meters) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return '$metersString m';
  }

  @override
  String get noteFact => '¿Sabías que…?';

  @override
  String get noteStory => 'Historia';

  @override
  String get sheetPolitical => 'Política';

  @override
  String get sheetPhysical => 'Física';

  @override
  String get sheetStories => 'Historias';

  @override
  String get sheetCapital => 'Capital';

  @override
  String get sheetGovernment => 'Gobierno';

  @override
  String get govPresidentialRepublic => 'República presidencial';

  @override
  String get govParliamentaryRepublic => 'República parlamentaria';

  @override
  String get govConstitutionalMonarchy => 'Monarquía constitucional';

  @override
  String get govAbsoluteMonarchy => 'Monarquía absoluta';

  @override
  String get govMonarchyHint => '👑 un rey, reina o emperador';

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
}
