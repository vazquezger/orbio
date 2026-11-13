import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbio/data/repositories/map_repository.dart';
import 'package:orbio/presentation/l10n_labels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('supports English and Spanish', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode),
      containsAll(['en', 'es']),
    );
  });

  test('question and calibration labels are translated', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    expect(en.questionAllFlags, 'All flags');
    expect(es.questionAllFlags, 'Todas las banderas');
    expect(en.questionCollapseTooltip, 'Collapse question bar');
    expect(es.questionCollapseTooltip, 'Ocultar barra de preguntas');
    expect(en.questionExpandTooltip, 'Ask or view questions');
    expect(es.questionExpandTooltip, 'Hacer o ver preguntas');
    expect(es.calibrateFoundSome(3), contains('3 de 4'));
    expect(en.cameraResumeTooltip, 'Resume last calibration');
    expect(es.cameraResumeTooltip, 'Reanudar última calibración');
    expect(en.cameraResumeButton, 'Resume last calibration');
    expect(es.cameraResumeButton, 'Reanudar última calibración');
    expect(en.llmSettingsTitle, 'AI Provider');
    expect(es.llmSettingsTitle, 'Proveedor de IA');
  });

  test('countries provide English and Spanish names', () async {
    final countries = await MapRepository().loadCountries();
    final germany = countries.firstWhere((c) => c.code == 'DEU');
    expect(germany.localizedName('en'), 'Germany');
    expect(germany.localizedName('es'), 'Alemania');
  });
}
