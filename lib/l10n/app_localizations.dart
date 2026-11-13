import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Orbio'**
  String get appTitle;

  /// No description provided for @cameraImportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import a photo of the canvas'**
  String get cameraImportTooltip;

  /// No description provided for @cameraDemoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Try with a demo snapshot'**
  String get cameraDemoTooltip;

  /// No description provided for @cameraResumeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Resume last calibration'**
  String get cameraResumeTooltip;

  /// No description provided for @cameraResumeButton.
  ///
  /// In en, this message translates to:
  /// **'Resume last calibration'**
  String get cameraResumeButton;

  /// No description provided for @cameraResumeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No previous calibration found.'**
  String get cameraResumeUnavailable;

  /// No description provided for @cameraResumeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not resume last map: {details}'**
  String cameraResumeFailed(String details);

  /// No description provided for @cameraCaptureTooltip.
  ///
  /// In en, this message translates to:
  /// **'Take snapshot'**
  String get cameraCaptureTooltip;

  /// No description provided for @cameraFramingHint.
  ///
  /// In en, this message translates to:
  /// **'Hold the phone flat above the canvas.\nKeep all 4 anchors in view.'**
  String get cameraFramingHint;

  /// No description provided for @cameraNotFound.
  ///
  /// In en, this message translates to:
  /// **'No camera found on this device.'**
  String get cameraNotFound;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera is not available here.'**
  String get cameraUnavailable;

  /// No description provided for @cameraAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access was denied. Enable it for Orbio in Settings.'**
  String get cameraAccessDenied;

  /// No description provided for @cameraError.
  ///
  /// In en, this message translates to:
  /// **'Camera error: {details}'**
  String cameraError(String details);

  /// No description provided for @cameraTakePhotoButton.
  ///
  /// In en, this message translates to:
  /// **'Take photo with camera'**
  String get cameraTakePhotoButton;

  /// No description provided for @cameraPickGalleryButton.
  ///
  /// In en, this message translates to:
  /// **'Choose photo from gallery'**
  String get cameraPickGalleryButton;

  /// No description provided for @cameraDemoButton.
  ///
  /// In en, this message translates to:
  /// **'Try sample map (no paper needed)'**
  String get cameraDemoButton;

  /// No description provided for @cameraRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry camera'**
  String get cameraRetryButton;

  /// No description provided for @cameraImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import photo: {details}'**
  String cameraImportFailed(String details);

  /// No description provided for @cameraDemoFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create demo snapshot: {details}'**
  String cameraDemoFailed(String details);

  /// No description provided for @calibrateTitle.
  ///
  /// In en, this message translates to:
  /// **'Calibrate'**
  String get calibrateTitle;

  /// No description provided for @calibrateConfirmTooltip.
  ///
  /// In en, this message translates to:
  /// **'Use these corners'**
  String get calibrateConfirmTooltip;

  /// No description provided for @calibrateLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open photo: {details}'**
  String calibrateLoadFailed(String details);

  /// No description provided for @calibrateDetecting.
  ///
  /// In en, this message translates to:
  /// **'Finding anchors…'**
  String get calibrateDetecting;

  /// No description provided for @calibrateFoundAll.
  ///
  /// In en, this message translates to:
  /// **'Found all 4 anchors. Fine-tune if needed.'**
  String get calibrateFoundAll;

  /// No description provided for @calibrateFoundNone.
  ///
  /// In en, this message translates to:
  /// **'No anchors found. Drag the corner handles onto the canvas corners.'**
  String get calibrateFoundNone;

  /// No description provided for @calibrateFoundSome.
  ///
  /// In en, this message translates to:
  /// **'Found {count} of 4 anchors. Place the rest by hand.'**
  String calibrateFoundSome(int count);

  /// No description provided for @calibrateCrossed.
  ///
  /// In en, this message translates to:
  /// **'The corner handles cross over. Place them clockwise: TL, TR, BR, BL.'**
  String get calibrateCrossed;

  /// No description provided for @calibrateHint.
  ///
  /// In en, this message translates to:
  /// **'Drag each corner handle onto an anchor'**
  String get calibrateHint;

  /// No description provided for @calibrateDetectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Auto-detected {count}/4'**
  String calibrateDetectedStatus(int count);

  /// No description provided for @calibrateReset.
  ///
  /// In en, this message translates to:
  /// **'Reset anchors'**
  String get calibrateReset;

  /// No description provided for @calibrateAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect'**
  String get calibrateAutoDetect;

  /// No description provided for @calibrateExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get calibrateExplore;

  /// No description provided for @cornerHandleSemantics.
  ///
  /// In en, this message translates to:
  /// **'Corner handle {corner}'**
  String cornerHandleSemantics(String corner);

  /// No description provided for @exploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get exploreTitle;

  /// No description provided for @exploreResetZoom.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get exploreResetZoom;

  /// No description provided for @exploreRecalibrate.
  ///
  /// In en, this message translates to:
  /// **'Recalibrate'**
  String get exploreRecalibrate;

  /// No description provided for @exploreHint.
  ///
  /// In en, this message translates to:
  /// **'Zoom in or tap a country to read its detail'**
  String get exploreHint;

  /// No description provided for @exploreLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load map data: {details}'**
  String exploreLoadFailed(String details);

  /// No description provided for @cameraLiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Live view'**
  String get cameraLiveTooltip;

  /// No description provided for @liveTitle.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get liveTitle;

  /// No description provided for @liveSearching.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the canvas'**
  String get liveSearching;

  /// No description provided for @liveDebugTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show tracking details'**
  String get liveDebugTooltip;

  /// No description provided for @liveDebugStats.
  ///
  /// In en, this message translates to:
  /// **'{markers} markers · {ms} ms'**
  String liveDebugStats(int markers, int ms);

  /// No description provided for @liveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live view needs a camera (iPhone or Android).'**
  String get liveUnavailable;

  /// No description provided for @questionHint.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about the world…'**
  String get questionHint;

  /// No description provided for @questionAllFlags.
  ///
  /// In en, this message translates to:
  /// **'All flags'**
  String get questionAllFlags;

  /// No description provided for @questionClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show all flags'**
  String get questionClearTooltip;

  /// No description provided for @questionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get questionHistoryTitle;

  /// No description provided for @questionAskButton.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get questionAskButton;

  /// No description provided for @questionListening.
  ///
  /// In en, this message translates to:
  /// **'Listening… tap to send'**
  String get questionListening;

  /// No description provided for @questionMicTooltip.
  ///
  /// In en, this message translates to:
  /// **'Ask by voice'**
  String get questionMicTooltip;

  /// No description provided for @questionMicUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice recognition isn\'t available here. Type your question below.'**
  String get questionMicUnavailable;

  /// No description provided for @questionThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get questionThinking;

  /// No description provided for @questionEmptyResult.
  ///
  /// In en, this message translates to:
  /// **'No matching countries found.'**
  String get questionEmptyResult;

  /// No description provided for @questionCloseUpHint.
  ///
  /// In en, this message translates to:
  /// **'Move closer or zoom in on a country to read its description'**
  String get questionCloseUpHint;

  /// No description provided for @questionCollapseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Collapse question bar'**
  String get questionCollapseTooltip;

  /// No description provided for @questionExpandTooltip.
  ///
  /// In en, this message translates to:
  /// **'Ask or view questions'**
  String get questionExpandTooltip;

  /// No description provided for @llmSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Provider'**
  String get llmSettingsTitle;

  /// No description provided for @llmProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get llmProviderLabel;

  /// No description provided for @llmModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get llmModelLabel;

  /// No description provided for @llmApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get llmApiKeyLabel;

  /// No description provided for @llmApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Paste your API key'**
  String get llmApiKeyHint;

  /// No description provided for @llmOllamaUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Ollama URL'**
  String get llmOllamaUrlLabel;

  /// No description provided for @llmOllamaUrlHint.
  ///
  /// In en, this message translates to:
  /// **'http://192.168.1.x:11434'**
  String get llmOllamaUrlHint;

  /// No description provided for @llmSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get llmSaveButton;

  /// No description provided for @llmMissingKeyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Configure an AI provider (Gemini, ChatGPT, Claude or local Ollama) to ask new questions.'**
  String get llmMissingKeyPrompt;

  /// No description provided for @projectionOrbioCanvas.
  ///
  /// In en, this message translates to:
  /// **'Orbio Canvas'**
  String get projectionOrbioCanvas;

  /// No description provided for @projectionSchoolMap.
  ///
  /// In en, this message translates to:
  /// **'School Map'**
  String get projectionSchoolMap;

  /// No description provided for @projectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Projection'**
  String get projectionLabel;

  /// No description provided for @homeScanSchoolMap.
  ///
  /// In en, this message translates to:
  /// **'Scan School Map'**
  String get homeScanSchoolMap;

  /// No description provided for @homeScanSchoolMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of any wall poster and explore with AI'**
  String get homeScanSchoolMapSubtitle;

  /// No description provided for @homeOrbioCanvas.
  ///
  /// In en, this message translates to:
  /// **'Orbio Canvas & AR'**
  String get homeOrbioCanvas;

  /// No description provided for @homeOrbioCanvasSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-detection with anchors & real-time AR tracking'**
  String get homeOrbioCanvasSubtitle;

  /// No description provided for @homeDownloadCanvas.
  ///
  /// In en, this message translates to:
  /// **'Download printable canvas (PDF)'**
  String get homeDownloadCanvas;

  /// No description provided for @homeOpenLive.
  ///
  /// In en, this message translates to:
  /// **'Open Live AR'**
  String get homeOpenLive;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
