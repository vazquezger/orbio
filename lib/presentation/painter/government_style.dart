import 'package:flutter/material.dart';

import '../../data/models/government_system.dart';
import '../l10n_labels.dart';

/// Shared colours/labels for the Government layer (painter + legend).
abstract final class GovernmentStyle {
  static const crown = '👑';

  static Color color(GovernmentSystem g) => switch (g) {
        GovernmentSystem.presidentialRepublic => const Color(0xFF2B7BB9),
        GovernmentSystem.parliamentaryRepublic => const Color(0xFF2E9E6B),
        GovernmentSystem.constitutionalMonarchy => const Color(0xFF8E5BB5),
        GovernmentSystem.absoluteMonarchy => const Color(0xFFC0392B),
      };

  static String label(GovernmentSystem g, AppLocalizations l) => switch (g) {
        GovernmentSystem.presidentialRepublic => l.govPresidentialRepublic,
        GovernmentSystem.parliamentaryRepublic => l.govParliamentaryRepublic,
        GovernmentSystem.constitutionalMonarchy => l.govConstitutionalMonarchy,
        GovernmentSystem.absoluteMonarchy => l.govAbsoluteMonarchy,
      };
}
