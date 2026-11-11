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

  /// No description provided for @cameraImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import canvas photo'**
  String get cameraImportButton;

  /// No description provided for @cameraDemoButton.
  ///
  /// In en, this message translates to:
  /// **'Use demo snapshot'**
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
  /// **'Tap a country to learn more · pinch to zoom'**
  String get exploreHint;

  /// No description provided for @exploreLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load map data: {details}'**
  String exploreLoadFailed(String details);

  /// No description provided for @layerFlags.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get layerFlags;

  /// No description provided for @layerGovernment.
  ///
  /// In en, this message translates to:
  /// **'Government'**
  String get layerGovernment;

  /// No description provided for @layerPhysical.
  ///
  /// In en, this message translates to:
  /// **'Physical'**
  String get layerPhysical;

  /// No description provided for @pinVolcano.
  ///
  /// In en, this message translates to:
  /// **'Volcano'**
  String get pinVolcano;

  /// No description provided for @pinPeak.
  ///
  /// In en, this message translates to:
  /// **'Mountain'**
  String get pinPeak;

  /// No description provided for @pinDepression.
  ///
  /// In en, this message translates to:
  /// **'Depression'**
  String get pinDepression;

  /// No description provided for @elevationMeters.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String elevationMeters(int meters);

  /// No description provided for @noteFact.
  ///
  /// In en, this message translates to:
  /// **'Did you know?'**
  String get noteFact;

  /// No description provided for @noteStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get noteStory;

  /// No description provided for @sheetPolitical.
  ///
  /// In en, this message translates to:
  /// **'Political'**
  String get sheetPolitical;

  /// No description provided for @sheetPhysical.
  ///
  /// In en, this message translates to:
  /// **'Physical'**
  String get sheetPhysical;

  /// No description provided for @sheetStories.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get sheetStories;

  /// No description provided for @sheetCapital.
  ///
  /// In en, this message translates to:
  /// **'Capital'**
  String get sheetCapital;

  /// No description provided for @sheetGovernment.
  ///
  /// In en, this message translates to:
  /// **'Government'**
  String get sheetGovernment;

  /// No description provided for @govPresidentialRepublic.
  ///
  /// In en, this message translates to:
  /// **'Presidential republic'**
  String get govPresidentialRepublic;

  /// No description provided for @govParliamentaryRepublic.
  ///
  /// In en, this message translates to:
  /// **'Parliamentary republic'**
  String get govParliamentaryRepublic;

  /// No description provided for @govConstitutionalMonarchy.
  ///
  /// In en, this message translates to:
  /// **'Constitutional monarchy'**
  String get govConstitutionalMonarchy;

  /// No description provided for @govAbsoluteMonarchy.
  ///
  /// In en, this message translates to:
  /// **'Absolute monarchy'**
  String get govAbsoluteMonarchy;

  /// No description provided for @govMonarchyHint.
  ///
  /// In en, this message translates to:
  /// **'👑 a king, queen or emperor'**
  String get govMonarchyHint;
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
