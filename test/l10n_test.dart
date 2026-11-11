import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbio/data/models/map_layer.dart';
import 'package:orbio/data/models/note.dart';
import 'package:orbio/presentation/l10n_labels.dart';

void main() {
  test('supports English and Spanish', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode),
      containsAll(['en', 'es']),
    );
  });

  test('layer and note labels are translated', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    expect(MapLayer.flags.label(en), 'Flags');
    expect(MapLayer.government.label(es), 'Gobierno');
    expect(NoteKind.fact.label(es), '¿Sabías que…?');
    expect(es.calibrateFoundSome(3), contains('3 de 4'));
    expect(en.elevationMeters(6961), '6,961 m');
    expect(es.elevationMeters(6961), '6.961 m');
  });

  test('legacy note kind "trivia" maps to fact', () {
    expect(NoteKind.parse('trivia'), NoteKind.fact);
  });
}
