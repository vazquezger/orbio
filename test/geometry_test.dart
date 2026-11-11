import 'package:flutter_test/flutter_test.dart';
import 'package:orbio/core/geometry/homography.dart';
import 'package:orbio/core/geometry/map_projection.dart';
import 'package:orbio/core/geometry/perspective_projector.dart';
import 'package:vector_math/vector_math_64.dart' show Vector4;

void expectOffset(Offset actual, Offset expected, {double tol = 1e-6}) {
  expect((actual - expected).distance, lessThan(tol), reason: '$actual != $expected');
}

void main() {
  group('Homography', () {
    test('identity correspondences give identity transform', () {
      const pts = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
      final h = Homography.fromCorrespondences(pts, pts);
      expectOffset(h.transform(const Offset(0.3, 0.7)), const Offset(0.3, 0.7));
    });

    test('maps the 4 source points exactly onto the destinations', () {
      const src = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
      const dst = [Offset(312, 205), Offset(3810, 140), Offset(3920, 2480), Offset(250, 2610)];
      final h = Homography.fromCorrespondences(src, dst);
      for (var i = 0; i < 4; i++) {
        expectOffset(h.transform(src[i]), dst[i], tol: 1e-6);
      }
    });

    test('inverse round-trips', () {
      const src = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
      const dst = [Offset(100, 80), Offset(900, 120), Offset(950, 700), Offset(60, 650)];
      final h = Homography.fromCorrespondences(src, dst);
      final inv = h.inverse();
      for (final p in const [Offset(0.25, 0.4), Offset(0.9, 0.1), Offset(0.5, 0.5)]) {
        expectOffset(inv.transform(h.transform(p)), p, tol: 1e-9);
      }
      final id = inv.compose(h);
      expectOffset(id.transform(const Offset(0.2, 0.8)), const Offset(0.2, 0.8), tol: 1e-9);
    });

    test('collinear points are rejected', () {
      expect(
        () => Homography.fromCorrespondences(
          const [Offset(0, 0), Offset(1, 1), Offset(2, 2), Offset(3, 3)],
          const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)],
        ),
        throwsA(isA<DegenerateHomographyException>()),
      );
    });

    test('toMatrix4 agrees with transform', () {
      const dst = [Offset(10, 20), Offset(200, 5), Offset(220, 180), Offset(0, 160)];
      final h = Homography.fromCorrespondences(PerspectiveProjector.normalizedCorners, dst);
      final v = h.toMatrix4().transform(Vector4(0.4, 0.6, 0, 1));
      expectOffset(Offset(v.x / v.w, v.y / v.w), h.transform(const Offset(0.4, 0.6)), tol: 1e-9);
    });
  });

  group('PerspectiveProjector', () {
    const anchors = [Offset(330, 360), Offset(2090, 290), Offset(2180, 1290), Offset(240, 1340)];

    test('anchors map to exact normalized map boundaries', () {
      final proj = PerspectiveProjector(anchors);
      expectOffset(proj.imageToMap(anchors[0]), const Offset(0, 0));
      expectOffset(proj.imageToMap(anchors[1]), const Offset(1, 0));
      expectOffset(proj.imageToMap(anchors[2]), const Offset(1, 1));
      expectOffset(proj.imageToMap(anchors[3]), const Offset(0, 1));
    });

    test('geo corners land on anchors', () {
      final proj = PerspectiveProjector(anchors);
      expectOffset(proj.geoToImage(90, -180), anchors[0], tol: 1e-6);
      expectOffset(proj.geoToImage(-90, 180), anchors[2], tol: 1e-6);
    });

    test('convexity check', () {
      expect(isConvexQuad(anchors), isTrue);
      expect(isConvexQuad([anchors[0], anchors[2], anchors[1], anchors[3]]), isFalse);
    });
  });

  test('MapProjection round-trip', () {
    final n = MapProjection.toNormalized(-34.6, -58.4);
    final g = MapProjection.toGeo(n);
    expect(g.lat, closeTo(-34.6, 1e-9));
    expect(g.lon, closeTo(-58.4, 1e-9));
  });
}

