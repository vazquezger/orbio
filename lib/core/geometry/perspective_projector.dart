import 'dart:ui' show Offset, Size;

import 'homography.dart';
import 'map_projection.dart';

/// Maps between photo pixels and normalized map coordinates using four
/// corner handles placed on the calibration anchors, ordered `[TL, TR, BR, BL]`.
///
/// The anchors map to the exact normalized boundaries of the world map:
/// TL → (0,0), TR → (1,0), BR → (1,1), BL → (0,1).
class PerspectiveProjector {
  PerspectiveProjector(List<Offset> imageCorners)
      : assert(imageCorners.length == 4),
        corners = List.unmodifiable(imageCorners),
        _toImage = Homography.fromCorrespondences(normalizedCorners, imageCorners) {
    _toMap = _toImage.inverse();
  }

  /// Builds a projector from a known normalized → image homography (e.g.
  /// from live marker tracking).
  PerspectiveProjector.fromHomography(Homography mapToImage)
      : _toImage = mapToImage,
        corners = List.unmodifiable([
          for (final c in normalizedCorners) mapToImage.transform(c),
        ]) {
    _toMap = _toImage.inverse();
  }

  static const List<Offset> normalizedCorners = [
    Offset(0, 0),
    Offset(1, 0),
    Offset(1, 1),
    Offset(0, 1),
  ];

  /// Corner handles in image pixel space, `[TL, TR, BR, BL]`.
  final List<Offset> corners;
  final Homography _toImage;
  late final Homography _toMap;

  /// Normalized map → image pixels.
  Homography get mapToImageMatrix => _toImage;

  /// Image pixels → normalized map.
  Homography get imageToMapMatrix => _toMap;

  Offset mapToImage(Offset normalized) => _toImage.transform(normalized);

  Offset imageToMap(Offset imagePoint) => _toMap.transform(imagePoint);

  Offset geoToImage(double lat, double lon) =>
      mapToImage(MapProjection.toNormalized(lat, lon));

  /// Whether a point in image space lands inside the calibrated map.
  bool containsImagePoint(Offset imagePoint) {
    final n = imageToMap(imagePoint);
    return n.dx >= 0 && n.dx <= 1 && n.dy >= 0 && n.dy <= 1;
  }
}

/// Default corner handles, inset by [insetFraction] from each image border.
List<Offset> defaultCornerHandles(Size imageSize, {double insetFraction = 0.10}) {
  final dx = imageSize.width * insetFraction;
  final dy = imageSize.height * insetFraction;
  return [
    Offset(dx, dy),
    Offset(imageSize.width - dx, dy),
    Offset(imageSize.width - dx, imageSize.height - dy),
    Offset(dx, imageSize.height - dy),
  ];
}

/// True when the quad `[p0..p3]` is strictly convex with consistent winding,
/// which is required for a well-behaved (non-folding) homography.
bool isConvexQuad(List<Offset> q) {
  if (q.length != 4) return false;
  double? sign;
  for (var i = 0; i < 4; i++) {
    final a = q[i], b = q[(i + 1) % 4], c = q[(i + 2) % 4];
    final cross = (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);
    if (cross.abs() < 1e-9) return false;
    final s = cross.sign;
    if (sign == null) {
      sign = s;
    } else if (s != sign) {
      return false;
    }
  }
  return true;
}

/// Shoelace area of a polygon.
double polygonArea(List<Offset> pts) {
  var sum = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum.abs() / 2;
}
