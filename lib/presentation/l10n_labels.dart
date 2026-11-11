import 'package:flutter/widgets.dart';

import '../data/models/map_layer.dart';
import '../data/models/note.dart';
import '../data/models/pin.dart';
import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Current locale as an intl locale name (e.g. `es`, `en_US`).
  String get localeName => Localizations.localeOf(this).toString();
}

extension MapLayerLabel on MapLayer {
  String label(AppLocalizations l) => switch (this) {
        MapLayer.flags => l.layerFlags,
        MapLayer.government => l.layerGovernment,
        MapLayer.physical => l.layerPhysical,
      };
}

extension PinKindLabel on PinKind {
  String label(AppLocalizations l) => switch (this) {
        PinKind.volcano => l.pinVolcano,
        PinKind.peak => l.pinPeak,
        PinKind.depression => l.pinDepression,
      };
}

extension NoteKindLabel on NoteKind {
  String label(AppLocalizations l) => switch (this) {
        NoteKind.fact => l.noteFact,
        NoteKind.story => l.noteStory,
      };
}
