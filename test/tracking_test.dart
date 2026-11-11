import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbio/core/geometry/homography.dart';
import 'package:orbio/core/tracking/marker_tracker.dart';

/// Renders the printable canvas so that SVG point (sx, sy) lands at
/// `view.transform(svg point)`, on a dark table; returns grayscale pixels.
Future<Uint8List> renderView(PictureInfo svg, Homography svgToImage, int w, int h) async {
  final rec = ui.PictureRecorder();
  Canvas(rec)
    ..drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = const Color(0xFF5A4A3E))
    ..save()
    ..transform(svgToImage.toMatrix4().storage)
    ..drawRect(const Rect.fromLTWH(-14, -14, 828, 428), Paint()..color = const Color(0xFFF4F2EE))
    ..drawPicture(svg.picture)
    ..restore();
  final img = await rec.endRecording().toImage(w, h);
  final rgba = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  img.dispose();
  final gray = Uint8List(w * h);
  for (var i = 0, j = 0; i < gray.length; i++, j += 4) {
    gray[i] = (0.299 * rgba[j] + 0.587 * rgba[j + 1] + 0.114 * rgba[j + 2]).round();
  }
  return gray;
}

/// SVG units → normalized map space (anchor box 20..780 x 20..380).
Homography svgToNormalized() => Homography.fromValues([1 / 760, 0, -20 / 760, 0, 1 / 360, -20 / 360, 0, 0, 1]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('least-squares homography recovers a known transform from noisy points', () {
    final truth = Homography.fromCorrespondences(
      const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)],
      const [Offset(100, 80), Offset(900, 120), Offset(950, 700), Offset(60, 650)],
    );
    final rnd = math.Random(1);
    final src = <Offset>[], dst = <Offset>[];
    for (var i = 0; i < 40; i++) {
      final p = Offset(rnd.nextDouble(), rnd.nextDouble());
      src.add(p);
      dst.add(truth.transform(p) + Offset(rnd.nextDouble() - 0.5, rnd.nextDouble() - 0.5));
    }
    final h = Homography.fromPoints(src, dst);
    for (final p in const [Offset(0.1, 0.1), Offset(0.5, 0.5), Offset(0.9, 0.8)]) {
      expect((h.transform(p) - truth.transform(p)).distance, lessThan(0.6));
    }
  });

  group('marker tracking on the printable canvas', () {
    late PictureInfo svg;
    late MarkerLayout layout;

    setUpAll(() async {
      svg = await vg.loadPicture(SvgStringLoader(File('assets/maps/orbio_printable_canvas.svg').readAsStringSync()), null);
      layout = MarkerLayout.fromJson(File(MarkerLayout.asset).readAsStringSync());
    });

    Future<void> check(String name, Homography svgToImage, int w, int h, {required int minMarkers, double tol = 2.0}) async {
      final gray = await renderView(svg, svgToImage, w, h);
      final sw = Stopwatch()..start();
      final result = MarkerTracker(layout).track(gray, w, h);
      sw.stop();
      expect(result, isNotNull, reason: '$name: no markers');
      expect(result!.markers.length, greaterThanOrEqualTo(minMarkers), reason: name);
      // Every detected marker must be the one actually printed there.
      final truth = svgToImage.compose(svgToNormalized().inverse());
      for (final m in result.markers) {
        final expected = layout.cornersById[m.id]!.map(truth.transform).toList();
        for (var i = 0; i < 4; i++) {
          expect((m.corners[i] - expected[i]).distance, lessThan(tol), reason: '$name marker ${m.id} corner $i');
        }
      }
      // The solved homography must agree with the truth inside the view.
      for (final n in const [Offset(0.3, 0.3), Offset(0.5, 0.5), Offset(0.7, 0.6)]) {
        final p = truth.transform(n);
        if (p.dx < 0 || p.dy < 0 || p.dx > w || p.dy > h) continue;
        expect((result.mapToImage.transform(n) - p).distance, lessThan(tol * 2), reason: '$name at $n');
      }
      // ignore: avoid_print
      print('$name: ${result.markers.length} markers in ${sw.elapsedMilliseconds} ms');
    }

    testWidgets('whole canvas, perspective', (tester) async {
      await tester.runAsync(() => check(
            'whole',
            Homography.fromCorrespondences(
              const [Offset(0, 0), Offset(800, 0), Offset(800, 400), Offset(0, 400)],
              const [Offset(60, 120), Offset(900, 90), Offset(940, 560), Offset(30, 600)],
            ),
            960, 720, minMarkers: 30, tol: 2.5));
    });

    testWidgets('whole canvas rotated 180 degrees', (tester) async {
      await tester.runAsync(() => check(
            'rotated',
            Homography.fromCorrespondences(
              const [Offset(0, 0), Offset(800, 0), Offset(800, 400), Offset(0, 400)],
              const [Offset(920, 620), Offset(50, 600), Offset(80, 130), Offset(900, 100)],
            ),
            960, 720, minMarkers: 30, tol: 2.5));
    });

    testWidgets('close-up of the South Atlantic (partial view)', (tester) async {
      // ~4x zoom around SVG point (330, 280), mild perspective.
      await tester.runAsync(() => check(
            'close-up',
            Homography.fromCorrespondences(
              const [Offset(250, 220), Offset(410, 220), Offset(410, 340), Offset(250, 340)],
              const [Offset(20, 40), Offset(700, 10), Offset(720, 520), Offset(0, 500)],
            ),
            720, 540, minMarkers: 2, tol: 2.5));
    });
  });
}
