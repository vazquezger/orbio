import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Current locale as an intl locale name (e.g. `es`, `en_US`).
  String get localeName => Localizations.localeOf(this).toString();
}
