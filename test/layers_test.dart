import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbio/core/geometry/perspective_projector.dart';
import 'package:orbio/data/models/country.dart';
import 'package:orbio/data/models/geo_point.dart';
import 'package:orbio/data/models/government_system.dart';
import 'package:orbio/data/models/map_layer.dart';
import 'package:orbio/data/repositories/map_repository.dart';
import 'package:orbio/l10n/app_localizations_en.dart';
import 'package:orbio/presentation/painter/map_overlay_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapLayer.toggle', () {
    test('flags and government are mutually exclusive', () {
      var active = {MapLayer.flags, MapLayer.physical};
      active = MapLayer.toggle(active, MapLayer.government, true);
      expect(active, {MapLayer.government, MapLayer.physical});
      active = MapLayer.toggle(active, MapLayer.flags, true);
      expect(active, {MapLayer.flags, MapLayer.physical});
    });

    test('physical toggles independently', () {
      var active = {MapLayer.flags};
      active = MapLayer.toggle(active, MapLayer.physical, true);
      expect(active, {MapLayer.flags, MapLayer.physical});
      active = MapLayer.toggle(active, MapLayer.flags, false);
      expect(active, {MapLayer.physical});
    });
  });

  test('government systems parse and flag monarchies', () {
    expect(GovernmentSystem.parse('constitutional_monarchy').isMonarchy, isTrue);
    expect(GovernmentSystem.parse('presidential_republic').isMonarchy, isFalse);
    expect(() => GovernmentSystem.parse('empire'), throwsFormatException);
  });

  test('seed content: every country has a flag asset and a government system', () async {
    final countries = await MapRepository().loadCountries();
    expect(countries, hasLength(15));
    for (final c in countries) {
      expect(File(c.flagAsset).existsSync(), isTrue, reason: c.flagAsset);
    }
    final monarchies = countries.where((c) => c.governmentSystem.isMonarchy).map((c) => c.code);
    expect(monarchies, unorderedEquals(['JPN', 'ESP', 'CAN', 'AUS']));
  });

  test('small countries switch to markers until zoomed in', () {
    // A 60 x 60 image-px square.
    const square = [Offset(0, 0), Offset(60, 0), Offset(60, 60), Offset(0, 60)];
    // Zoomed out: 2 image px per screen px → 30 px on screen → small.
    expect(MapOverlayPainter.isSmallOnScreen([square], 2), isTrue);
    // Zoomed in: 0.5 image px per screen px → 120 px on screen → fill.
    expect(MapOverlayPainter.isSmallOnScreen([square], 0.5), isFalse);
  });

  test('multi-part countries: nearby islands share a flag, far parts do not', () async {
    final countries = await MapRepository().loadCountries();
    final japan = countries.firstWhere((c) => c.code == 'JPN');
    expect(japan.areas.length, greaterThan(1));
    expect(MapOverlayPainter.flagGroups(japan.areas), hasLength(1));
    // A far-away part (an overseas territory) gets its own group.
    final far = [
      ...japan.areas,
      [const GeoPoint(-20, -60), const GeoPoint(-20, -58), const GeoPoint(-22, -58)],
    ];
    expect(MapOverlayPainter.flagGroups(far), hasLength(2));
  });

  testWidgets('painter draws every layer with real flags without errors', (tester) async {
    await tester.runAsync(() async {
      final List<Country> countries = await MapRepository().loadCountries();
      final flags = <String, PictureInfo>{
        for (final c in countries)
          c.code: await vg.loadPicture(SvgStringLoader(File(c.flagAsset).readAsStringSync()), null),
      };
      final projector = PerspectiveProjector(const [
        Offset(100, 80), Offset(1900, 60), Offset(1950, 980), Offset(60, 1000),
      ]);
      for (final layers in [
        {MapLayer.flags, MapLayer.physical},
        {MapLayer.government, MapLayer.physical},
      ]) {
        final recorder = ui.PictureRecorder();
        MapOverlayPainter(
          projector: projector,
          countries: countries,
          layers: layers,
          labelScale: 2,
          l10n: AppLocalizationsEn(),
          flags: flags,
          selectedCode: 'ARG',
        ).paint(Canvas(recorder), const Size(2000, 1100));
        final image = await recorder.endRecording().toImage(200, 110);
        image.dispose();
      }
      for (final f in flags.values) {
        f.picture.dispose();
      }
    });
  });
}
