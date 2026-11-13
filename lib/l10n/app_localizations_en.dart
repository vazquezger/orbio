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
  String get cameraResumeTooltip => 'Resume last calibration';

  @override
  String get cameraResumeButton => 'Resume last calibration';

  @override
  String get cameraResumeUnavailable => 'No previous calibration found.';

  @override
  String cameraResumeFailed(String details) {
    return 'Could not resume last map: $details';
  }

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
  String get cameraTakePhotoButton => 'Take photo with camera';

  @override
  String get cameraPickGalleryButton => 'Choose photo from gallery';

  @override
  String get cameraDemoButton => 'Try sample map (no paper needed)';

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
  String get exploreHint => 'Zoom in or tap a country to read its detail';

  @override
  String exploreLoadFailed(String details) {
    return 'Could not load map data: $details';
  }

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

  @override
  String get questionHint => 'Ask anything about the world…';

  @override
  String get questionAllFlags => 'All flags';

  @override
  String get questionClearTooltip => 'Show all flags';

  @override
  String get questionHistoryTitle => 'Questions';

  @override
  String get questionAskButton => 'Ask';

  @override
  String get questionListening => 'Listening… tap to send';

  @override
  String get questionMicTooltip => 'Ask by voice';

  @override
  String get questionMicUnavailable =>
      'Voice recognition isn\'t available here. Type your question below.';

  @override
  String get questionThinking => 'Thinking…';

  @override
  String get questionEmptyResult => 'No matching countries found.';

  @override
  String get questionCloseUpHint =>
      'Move closer or zoom in on a country to read its description';

  @override
  String get questionCollapseTooltip => 'Collapse question bar';

  @override
  String get questionExpandTooltip => 'Ask or view questions';

  @override
  String get llmSettingsTitle => 'AI Provider';

  @override
  String get llmProviderLabel => 'Provider';

  @override
  String get llmModelLabel => 'Model';

  @override
  String get llmApiKeyLabel => 'API key';

  @override
  String get llmApiKeyHint => 'Paste your API key';

  @override
  String get llmOllamaUrlLabel => 'Ollama URL';

  @override
  String get llmOllamaUrlHint => 'http://192.168.1.x:11434';

  @override
  String get llmSaveButton => 'Save';

  @override
  String get llmMissingKeyPrompt =>
      'Configure an AI provider (Gemini, ChatGPT, Claude or local Ollama) to ask new questions.';

  @override
  String get projectionOrbioCanvas => 'Orbio Canvas';

  @override
  String get projectionSchoolMap => 'School Map';

  @override
  String get projectionLabel => 'Projection';

  @override
  String get homeScanSchoolMap => 'Scan School Map';

  @override
  String get homeScanSchoolMapSubtitle =>
      'Take a photo of any wall poster and explore with AI';

  @override
  String get homeOrbioCanvas => 'Orbio Canvas & AR';

  @override
  String get homeOrbioCanvasSubtitle =>
      'Auto-detection with anchors & real-time AR tracking';

  @override
  String get homeDownloadCanvas => 'Download printable canvas (PDF)';

  @override
  String get homeOpenLive => 'Open Live AR';
}
