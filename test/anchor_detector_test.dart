import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbio/core/geometry/anchor_detector.dart';
import 'package:orbio/core/geometry/homography.dart';
import 'package:orbio/core/geometry/perspective_projector.dart';

/// Draws a printable-style bullseye (outer black r, white 2/3 r, dot 0.3 r).
void drawBullseye(Uint8List g, int w, int h, double cx, double cy, double r) {
  for (var y = (cy - r - 1).floor(); y <= (cy + r + 1).ceil(); y++) {
    for (var x = (cx - r - 1).floor(); x <= (cx + r + 1).ceil(); x++) {
      if (x < 0 || y < 0 || x >= w || y >= h) continue;
      final d = math.sqrt(math.pow(x + 0.5 - cx, 2) + math.pow(y + 0.5 - cy, 2));
      if (d <= 0.3 * r || (d > 0.66 * r && d <= r)) g[y * w + x] = 15;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnchorDetector.scanGray', () {
    test('finds four synthetic bullseyes with sub-pixel accuracy', () {
      const w = 640, h = 420;
      final g = Uint8List(w * h)..fillRange(0, w * h, 235);
      // Distractors: a thick line and a solid blob.
      for (var x = 100; x < 540; x++) {
        for (var y = 200; y < 203; y++) {
          g[y * w + x] = 20;
        }
      }
      for (var y = 120; y < 135; y++) {
        for (var x = 300; x < 315; x++) {
          g[y * w + x] = 10;
        }
      }
      const truth = [Offset(60.3, 48.7), Offset(585.5, 40.2), Offset(598.1, 370.4), Offset(45.6, 380.9)];
      for (final t in truth) {
        drawBullseye(g, w, h, t.dx, t.dy, 11);
      }
      final found = AnchorDetector.scanGray(g, w, h);
      for (var i = 0; i < 4; i++) {
        expect(found[i], isNotNull, reason: 'corner $i');
        expect(found[i]!.score, greaterThan(AnchorDetector.minConfidence));
        expect((Offset(found[i]!.x, found[i]!.y) - truth[i]).distance, lessThan(0.6),
            reason: 'corner $i at ${found[i]} vs ${truth[i]}');
      }
    });

    test('blank image yields no confident candidates', () {
      const w = 200, h = 120;
      final g = Uint8List(w * h)..fillRange(0, w * h, 240);
      final found = AnchorDetector.scanGray(g, w, h);
      expect(found.every((c) => c == null || c.score < AnchorDetector.minConfidence), isTrue);
    });
  });

  testWidgets('detects anchors on the printable SVG photographed in perspective',
      (tester) async {
    await tester.runAsync(() async {
      final svg = File('assets/maps/orbio_printable_canvas.svg').readAsStringSync();
      final info = await vg.loadPicture(SvgStringLoader(svg), null);
      const outW = 1600, outH = 1100;
      final quad = const [Offset(210, 230), Offset(1400, 180), Offset(1460, 860), Offset(150, 900)];
      final hom = Homography.fromCorrespondences(
        [Offset.zero, Offset(info.size.width, 0), Offset(info.size.width, info.size.height), Offset(0, info.size.height)],
        quad,
      );
      final rec = ui.PictureRecorder();
      Canvas(rec)
        ..drawRect(const Rect.fromLTWH(0, 0, 1600, 1100), Paint()..color = const Color(0xFF5A4A3E))
        ..save()
        ..transform(hom.toMatrix4().storage)
        ..drawRect(Rect.fromLTWH(-14, -14, info.size.width + 28, info.size.height + 28),
            Paint()..color = Colors.white)
        ..drawPicture(info.picture)
        ..restore();
      final img = await rec.endRecording().toImage(outW, outH);
      final png = (await img.toByteData(format: ui.ImageByteFormat.png))!;
      final result = await AnchorDetector.detect(
        png.buffer.asUint8List(),
        const Size(outW + 0.0, outH + 0.0),
      );
      // Anchor centres in SVG units are inset 20px from each edge.
      final expected = [
        hom.transform(const Offset(20, 20)),
        hom.transform(const Offset(780, 20)),
        hom.transform(const Offset(780, 380)),
        hom.transform(const Offset(20, 380)),
      ];
      expect(result.detectedCount, 4, reason: '${result.points} conf ${result.confidences}');
      for (var i = 0; i < 4; i++) {
        expect((result.points[i] - expected[i]).distance, lessThan(2.5),
            reason: 'corner $i: ${result.points[i]} vs ${expected[i]}');
      }
      final proj = PerspectiveProjector(result.points);
      expect((proj.imageToMap(result.points[0])).distance, lessThan(1e-6));
      img.dispose();
      info.picture.dispose();
    });
  });

  test('fallback returns 10% inset points', () async {
    final r = AnchorDetectionResult.fallback(const Size(1000, 500));
    expect(r.points, const [Offset(100, 50), Offset(900, 50), Offset(900, 450), Offset(100, 450)]);
    expect(r.detectedCount, 0);
  });

  test('undecodable bytes fall back gracefully', () async {
    final pts = await detectAnchorPoints(Uint8List.fromList([1, 2, 3]), const Size(1000, 500));
    expect(pts.first, const Offset(100, 50));
  });
}
