import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbio/core/geometry/perspective_projector.dart';
import 'package:orbio/data/models/country.dart';
import 'package:orbio/data/models/geo_point.dart';
import 'package:orbio/data/models/world_question.dart';
import 'package:orbio/data/repositories/map_repository.dart';
import 'package:orbio/data/repositories/question_store.dart';
import 'package:orbio/data/services/llm_client.dart';
import 'package:orbio/l10n/app_localizations_es.dart';
import 'package:orbio/presentation/painter/flag_artwork.dart';
import 'package:orbio/presentation/painter/map_overlay_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('world catalog loads all countries with areas and flag assets', () async {
    final countries = await MapRepository().loadCountries();
    expect(countries.length, 174);
    final codes = {for (final c in countries) c.code};
    // Verify countries needed for classic questions (World Cup, Everest, etc.)
    expect(codes, containsAll(['ARG', 'BRA', 'URY', 'DEU', 'NPL', 'PAK', 'IND']));
    for (final c in countries) {
      expect(c.areas, isNotEmpty, reason: c.code);
      expect(c.flag, isNotEmpty, reason: c.code);
      expect(File(c.flagAsset).existsSync(), isTrue, reason: c.flagAsset);
    }
  });

  test('diagnose flag transformation', () async {
    final countries = await MapRepository().loadCountries();
    final arg = countries.firstWhere((c) => c.code == 'ARG');
    final projector = PerspectiveProjector(const [
      Offset(0, 0),
      Offset(1000, 0),
      Offset(1000, 500),
      Offset(0, 500),
    ]);
    final painter = MapOverlayPainter(
      projector: projector,
      countries: countries,
      labelScale: 1,
      l10n: AppLocalizationsEs(),
    );
    final group = MapOverlayPainter.flagGroups(arg.areas).first;
    final rings = [for (final i in group) arg.areas[i]];
    final h = painter.flagToImageForTest(rings, const Size(640, 480));
    final p0 = h.transform(const Offset(0, 0));
    final p1 = h.transform(const Offset(640, 480));
    // ignore: avoid_print
    print('ARG flag box transformed: p0=$p0, p1=$p1');
    final centroidImage = projector.geoToImage(arg.centroid.lat, arg.centroid.lon);
    // ignore: avoid_print
    print('ARG centroidImage: $centroidImage');
  });

  testWidgets('FlagArtwork loads flags', (tester) async {
    await tester.runAsync(() async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final flagAssets = manifest.listAssets().where((k) => k.contains('flags')).take(5).toList();
      // ignore: avoid_print
      print('FLAG_ASSETS_SAMPLE=$flagAssets');
      final countries = await MapRepository().loadCountries();
      final flags = await FlagArtwork.loadAll(countries);
      // ignore: avoid_print
      print('LOADED_FLAGS_COUNT=${flags.length}');
      expect(flags.length, greaterThan(0));
      for (final f in flags.values) {
        f.picture.dispose();
      }
    });
  });

  testWidgets('verify flag pixels are actually painted', (tester) async {
    await tester.runAsync(() async {
      final countries = await MapRepository().loadCountries();
      final flags = await FlagArtwork.loadAll(countries);
      final arg = countries.firstWhere((c) => c.code == 'ARG');
      final projector = PerspectiveProjector(const [
        Offset(0, 0),
        Offset(1000, 0),
        Offset(1000, 500),
        Offset(0, 500),
      ]);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = MapOverlayPainter(
        projector: projector,
        countries: [arg],
        labelScale: 1,
        l10n: AppLocalizationsEs(),
        flags: flags,
      );
      painter.paint(canvas, const Size(1000, 500));
      final pic = recorder.endRecording();
      final img = await pic.toImage(1000, 500);
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = bd!.buffer.asUint8List();
      var nonZero = 0;
      for (var i = 3; i < bytes.length; i += 4) {
        if (bytes[i] > 0) nonZero++;
      }
      // ignore: avoid_print
      print('ARG painted non-zero alpha pixels: $nonZero out of 500000');
      expect(nonZero, greaterThan(100));
      for (final f in flags.values) {
        f.picture.dispose();
      }
    });
  });

  test('WorldQuestion.fromLlmResponse parses fences, ranks and caps items', () {
    const raw = '''
```json
{
  "summary": "Top países por mundiales ganados",
  "ordered": true,
  "items": [
    {"code": "bra", "badge": "5 🏆", "detail": "Pentacampeón mundial."},
    {"code": "DEU", "badge": "4 🏆", "detail": "Cuatro títulos."},
    {"code": "XXX", "badge": "?", "detail": "Código inexistente."},
    {"code": "BRA", "badge": "dup", "detail": "Duplicado."}
  ]
}
```
''';
    final q = WorldQuestion.fromLlmResponse(
      question: '¿Quiénes ganaron mundiales?',
      rawJson: raw,
      validCodes: const {'BRA', 'DEU', 'ARG'},
    );
    expect(q.summary, 'Top países por mundiales ganados');
    expect(q.ordered, isTrue);
    expect(q.items.map((i) => i.code), ['BRA', 'DEU']);
    expect(q.rankOf('BRA'), 1);
    expect(q.rankOf('DEU'), 2);
    expect(q.rankOf('ARG'), isNull);
  });

  test('WorldQuestion.fromLlmResponse recovers truncated JSON and normalizes aliases', () {
    const truncated = '''
{
  "summary": "Campeones del mundo",
  "ordered": true,
  "items": [
    {"code": "URU", "badge": "2 🏆", "detail": "1930 y 1950."},
    {"code": "GER", "badge": "4 🏆", "detail": "Cuatro títulos."},
    {"code": "ENG", "badge": "1 🏆", "detail": "Incompleto
''';
    final q = WorldQuestion.fromLlmResponse(
      question: 'Mundiales',
      rawJson: truncated,
      validCodes: const {'URY', 'DEU', 'GBR'},
    );
    expect(q.items.map((i) => i.code), ['URY', 'DEU']);
  });

  test('WorldQuestion.fromLlmResponse handles global scale lists with up to 180 countries', () {
    final rawItems = [
      for (var i = 0; i < 50; i++) '{"code": "C$i", "badge": "${i}x"}'
    ].join(',');
    final rawJson = '{"summary": "Global test", "items": [$rawItems]}';
    final validCodes = {for (var i = 0; i < 50; i++) 'C$i'};
    final q = WorldQuestion.fromLlmResponse(
      question: 'Global question',
      rawJson: rawJson,
      validCodes: validCodes,
    );
    expect(q.items.length, 50);
    expect(q.items.first.badge, '0x');
    expect(q.items.last.badge, '49x');
  });

  test('WorldQuestion.fromLlmResponse parses ultra-compact dictionary format', () {
    const compactJson = '''
{
  "summary": "Volcanes activos por país",
  "ordered": false,
  "items": {
    "IDN": "127 🌋",
    "USA": "161 🌋",
    "JPN": "111 🌋",
    "CHL": "90 🌋"
  }
}
''';
    final q = WorldQuestion.fromLlmResponse(
      question: '¿Cuántos volcanes hay en cada país?',
      rawJson: compactJson,
      validCodes: const {'IDN', 'USA', 'JPN', 'CHL'},
    );
    expect(q.items.length, 4);
    expect(q.itemsByCode['IDN']?.badge, '127 🌋');
    expect(q.itemsByCode['CHL']?.badge, '90 🌋');
  });

  test('small countries switch to markers until zoomed in', () {
    const square = [
      Offset(0, 0),
      Offset(20, 0),
      Offset(20, 20),
      Offset(0, 20),
    ];
    expect(MapOverlayPainter.isSmallOnScreen([square], 2), isTrue);
    expect(MapOverlayPainter.isSmallOnScreen([square], 0.5), isFalse);
  });

  test('close-up zoom detection triggers when map is zoomed in relative to view', () {
    // Full world spans 1800 px inside a 2000 px canvas → wide zoom (ratio 0.9).
    final wideProjector = PerspectiveProjector(const [
      Offset(100, 80),
      Offset(1900, 80),
      Offset(1900, 980),
      Offset(100, 980),
    ]);
    expect(
      MapOverlayPainter.isCloseUpZoom(wideProjector, const Size(2000, 1000), 1),
      isFalse,
    );

    // Camera moved close to a region: projected world is 4000 px wide on a
    // 1000 px screen → close-up zoom (ratio 4.0 >= 1.75).
    final closeProjector = PerspectiveProjector(const [
      Offset(-1500, -800),
      Offset(2500, -800),
      Offset(2500, 1200),
      Offset(-1500, 1200),
    ]);
    expect(
      MapOverlayPainter.isCloseUpZoom(closeProjector, const Size(1000, 800), 1),
      isTrue,
    );
  });

  test('multi-part countries: nearby islands share a flag, far parts do not', () async {
    final countries = await MapRepository().loadCountries();
    final japan = countries.firstWhere((c) => c.code == 'JPN');
    expect(japan.areas.length, greaterThan(1));
    expect(MapOverlayPainter.flagGroups(japan.areas), hasLength(1));
    final far = [
      ...japan.areas,
      [
        const GeoPoint(-20, -60),
        const GeoPoint(-20, -58),
        const GeoPoint(-22, -58),
      ],
    ];
    expect(MapOverlayPainter.flagGroups(far), hasLength(2));
  });

  testWidgets('painter draws all-flags and question modes (wide and close-up)', (tester) async {
    await tester.runAsync(() async {
      final List<Country> countries = await MapRepository().loadCountries();
      final flags = <String, PictureInfo>{
        for (final c in countries)
          if (File(c.flagAsset).existsSync())
            c.code: await vg.loadPicture(
              SvgStringLoader(File(c.flagAsset).readAsStringSync()),
              null,
            ),
      };
      final projector = PerspectiveProjector(const [
        Offset(100, 80),
        Offset(1900, 60),
        Offset(1950, 980),
        Offset(60, 1000),
      ]);
      final seedQuestion = QuestionStore.defaultSeedQuestions().first;

      for (final question in <WorldQuestion?>[null, seedQuestion]) {
        final recorder = ui.PictureRecorder();
        MapOverlayPainter(
          projector: projector,
          countries: countries,
          labelScale: 1,
          l10n: AppLocalizationsEs(),
          flags: flags,
          activeQuestion: question,
          selectedCode: 'ARG',
        ).paint(Canvas(recorder), const Size(800, 600));
        final image = await recorder.endRecording().toImage(80, 60);
        image.dispose();
      }
      for (final f in flags.values) {
        f.picture.dispose();
      }
    });
  });

  test('LlmConfig.activeModel locks cloud models and allows Ollama custom model', () {
    // Cloud providers always lock to their calibrated default model
    const geminiConfig = LlmConfig(
      provider: LlmProvider.gemini,
      customModel: 'llama3.2',
    );
    expect(geminiConfig.activeModel, 'gemini-3.5-flash');

    const openaiConfig = LlmConfig(
      provider: LlmProvider.openai,
      customModel: 'anything',
    );
    expect(openaiConfig.activeModel, 'gpt-4o-mini');

    const anthropicConfig = LlmConfig(
      provider: LlmProvider.anthropic,
      customModel: 'anything',
    );
    expect(anthropicConfig.activeModel, 'claude-3-5-haiku-latest');

    // Ollama allows custom models
    const ollamaConfig = LlmConfig(
      provider: LlmProvider.ollama,
      customModel: 'qwen2.5:7b',
    );
    expect(ollamaConfig.activeModel, 'qwen2.5:7b');

    // Ollama fallback if empty
    const ollamaEmpty = LlmConfig(
      provider: LlmProvider.ollama,
      customModel: '',
    );
    expect(ollamaEmpty.activeModel, 'llama3.2');
  });

  test('adaptive zoom: pills are compact at wide zoom and expand with full name at close-up', () {
    final projector = PerspectiveProjector(const [
      Offset(100, 80),
      Offset(1900, 60),
      Offset(1950, 980),
      Offset(60, 1000),
    ]);
    final widePainter = MapOverlayPainter(
      projector: projector,
      countries: const [],
      labelScale: 1,
      l10n: AppLocalizationsEs(),
      isCloseUp: false,
    );
    expect(widePainter.closeUp, isFalse);

    final closePainter = MapOverlayPainter(
      projector: projector,
      countries: const [],
      labelScale: 1,
      l10n: AppLocalizationsEs(),
      isCloseUp: true,
    );
    expect(closePainter.closeUp, isTrue);
  });

  test('MapOverlayPainter supports 3-tier MapDetailLevel progression', () {
    final projector = PerspectiveProjector(const [
      Offset(100, 80),
      Offset(1900, 60),
      Offset(1950, 980),
      Offset(60, 1000),
    ]);
    final overviewPainter = MapOverlayPainter(
      projector: projector,
      countries: const [],
      labelScale: 1,
      l10n: AppLocalizationsEs(),
      detailLevel: MapDetailLevel.overview,
    );
    expect(overviewPainter.activeDetailLevel, MapDetailLevel.overview);

    final regionalPainter = MapOverlayPainter(
      projector: projector,
      countries: const [],
      labelScale: 1,
      l10n: AppLocalizationsEs(),
      detailLevel: MapDetailLevel.regional,
    );
    expect(regionalPainter.activeDetailLevel, MapDetailLevel.regional);

    final closePainter = MapOverlayPainter(
      projector: projector,
      countries: const [],
      labelScale: 1,
      l10n: AppLocalizationsEs(),
      detailLevel: MapDetailLevel.closeUp,
    );
    expect(closePainter.activeDetailLevel, MapDetailLevel.closeUp);
  });

  test('redundant continent or category badges are filtered and flags are preserved', () {
    const egypt = Country(
      code: 'EGY',
      iso2: 'eg',
      name: 'Egypt',
      nameEs: 'Egipto',
      flag: '🇪🇬',
      centroid: GeoPoint(26.8, 30.8),
      areas: [],
    );
    final question = WorldQuestion(
      id: '1',
      question: 'países de África',
      summary: 'Países del continente africano',
      ordered: false,
      items: const [
        AnswerItem(code: 'EGY', badge: 'África'),
        AnswerItem(code: 'NGA', badge: 'África'),
        AnswerItem(code: 'ZAF', badge: 'África'),
      ],
      createdAt: DateTime.now(),
    );

    expect(
      MapOverlayPainter.isRedundantBadgeForTest('África', egypt, question),
      isTrue,
    );
    expect(
      MapOverlayPainter.isRedundantBadgeForTest('105M', egypt, question),
      isFalse,
    );
  });
}
