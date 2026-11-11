// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Orbio';

  @override
  String get cameraImportTooltip => 'Import a photo of the canvas';

  @override
  String get cameraDemoTooltip => 'Try with a demo snapshot';

  @override
  String get cameraCaptureTooltip => 'Take snapshot';

  @override
  String get cameraFramingHint =>
      'Hold the phone flat above the canvas.\nKeep all 4 anchors in view.';

  @override
  String get cameraNotFound => 'No camera found on this device.';

  @override
  String get cameraUnavailable => 'Camera is not available here.';

  @override
  String get cameraAccessDenied =>
      'Camera access was denied. Enable it for Orbio in Settings.';

  @override
  String cameraError(String details) {
    return 'Camera error: $details';
  }

  @override
  String get cameraImportButton => 'Import canvas photo';

  @override
  String get cameraDemoButton => 'Use demo snapshot';

  @override
  String get cameraRetryButton => 'Retry camera';

  @override
  String cameraImportFailed(String details) {
    return 'Could not import photo: $details';
  }

  @override
  String cameraDemoFailed(String details) {
    return 'Could not create demo snapshot: $details';
  }

  @override
  String get calibrateTitle => 'Calibrate';

  @override
  String get calibrateConfirmTooltip => 'Use these corners';

  @override
  String calibrateLoadFailed(String details) {
    return 'Could not open photo: $details';
  }

  @override
  String get calibrateDetecting => 'Finding anchors…';

  @override
  String get calibrateFoundAll => 'Found all 4 anchors. Fine-tune if needed.';

  @override
  String get calibrateFoundNone =>
      'No anchors found. Drag the corner handles onto the canvas corners.';

  @override
  String calibrateFoundSome(int count) {
    return 'Found $count of 4 anchors. Place the rest by hand.';
  }

  @override
  String get calibrateCrossed =>
      'The corner handles cross over. Place them clockwise: TL, TR, BR, BL.';

  @override
  String get calibrateHint => 'Drag each corner handle onto an anchor';

  @override
  String calibrateDetectedStatus(int count) {
    return 'Auto-detected $count/4';
  }

  @override
  String get calibrateReset => 'Reset anchors';

  @override
  String get calibrateAutoDetect => 'Auto-detect';

  @override
  String get calibrateExplore => 'Explore';

  @override
  String cornerHandleSemantics(String corner) {
    return 'Corner handle $corner';
  }

  @override
  String get exploreTitle => 'Explore';

  @override
  String get exploreResetZoom => 'Reset zoom';

  @override
  String get exploreRecalibrate => 'Recalibrate';

  @override
  String get exploreHint => 'Tap a country to learn more · pinch to zoom';

  @override
  String exploreLoadFailed(String details) {
    return 'Could not load map data: $details';
  }

  @override
  String get layerFlags => 'Flags';

  @override
  String get layerGovernment => 'Government';

  @override
  String get layerPhysical => 'Physical';

  @override
  String get pinVolcano => 'Volcano';

  @override
  String get pinPeak => 'Mountain';

  @override
  String get pinDepression => 'Depression';

  @override
  String elevationMeters(int meters) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return '$metersString m';
  }

  @override
  String get noteFact => 'Did you know?';

  @override
  String get noteStory => 'Story';

  @override
  String get sheetPolitical => 'Political';

  @override
  String get sheetPhysical => 'Physical';

  @override
  String get sheetStories => 'Stories';

  @override
  String get sheetCapital => 'Capital';

  @override
  String get sheetGovernment => 'Government';

  @override
  String get govPresidentialRepublic => 'Presidential republic';

  @override
  String get govParliamentaryRepublic => 'Parliamentary republic';

  @override
  String get govConstitutionalMonarchy => 'Constitutional monarchy';

  @override
  String get govAbsoluteMonarchy => 'Absolute monarchy';

  @override
  String get govMonarchyHint => '👑 a king, queen or emperor';

  @override
  String get cameraLiveTooltip => 'Live view';

  @override
  String get liveTitle => 'Live';

  @override
  String get liveSearching => 'Point the camera at the canvas';

  @override
  String get liveDebugTooltip => 'Show tracking details';

  @override
  String liveDebugStats(int markers, int ms) {
    return '$markers markers · $ms ms';
  }

  @override
  String get liveUnavailable => 'Live view needs a camera (iPhone or Android).';
}
