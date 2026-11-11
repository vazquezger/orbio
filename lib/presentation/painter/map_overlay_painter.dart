import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/geometry/homography.dart';
import '../../core/geometry/perspective_projector.dart';
import '../../data/models/country.dart';
import '../../data/models/map_layer.dart';
import '../../data/models/pin.dart';
import '../l10n_labels.dart';
import 'government_style.dart';

/// Paints the layers (Areas and Pins) on top of the snapshot.
///
/// Paints in image pixel space: every geographic coordinate is projected
/// through the calibrated homography. [labelScale] is the number of image
/// pixels per logical screen pixel at the current zoom, so text and markers
/// keep a constant on-screen size while the photo is zoomed.
class MapOverlayPainter extends CustomPainter {
  MapOverlayPainter({
    required this.projector,
    required this.countries,
    required this.layers,
    required this.labelScale,
    required this.l10n,
    this.flags = const {},
    this.selectedCode,
    this.floatingNames = false,
  });

  final PerspectiveProjector projector;
  final List<Country> countries;
  final Set<MapLayer> layers;
  final double labelScale;
  final AppLocalizations l10n;

  /// Flag artwork by country code (may be partially loaded).
  final Map<String, PictureInfo> flags;
  final String? selectedCode;

  /// Live view style: names float above each country on a soft pill.
  final bool floatingNames;

  /// Opacity of area fills, so the canvas's black outlines stay visible.
  static const fillOpacity = 0.72;

  /// Below this on-screen size (√area, logical px) a country is too small to
  /// read a fill, so it gets a marker (flag icon / colour dot) instead.
  static const smallAreaThreshold = 40.0;

  /// Flag icon size for small countries, logical px (4:3).
  static const flagIconSize = Size(26, 19.5);

  /// Whether a country whose projected outline is [imagePoints] is too small
  /// on screen at [labelScale] (image px per logical px) to show a fill.
  static bool isSmallOnScreen(List<Offset> imagePoints, double labelScale) =>
      math.sqrt(polygonArea(imagePoints)) / labelScale < smallAreaThreshold;

  @override
  void paint(Canvas canvas, Size size) {
    final s = labelScale;
    final showFlags = layers.contains(MapLayer.flags);
    final showGov = layers.contains(MapLayer.government);

    final small = <String>{};
    for (final c in countries) {
      final points = [for (final g in c.outline) projector.geoToImage(g.lat, g.lon)];
      final area = Path()..addPolygon(points, true);
      final isSmall = isSmallOnScreen(points, s);
      if (isSmall) small.add(c.code);
      if (!isSmall && showFlags) _paintFlag(canvas, c, area, size);
      if (!isSmall && showGov) _paintGovernmentFill(canvas, c, area);
      if (showFlags || showGov || c.code == selectedCode) {
        _paintAreaOutline(canvas, area, c.code == selectedCode, s);
      }
    }
    if (layers.contains(MapLayer.physical)) {
      for (final c in countries) {
        for (final pin in c.pins) {
          _paintPin(canvas, pin, s);
        }
      }
    }
    for (final c in countries) {
      final isSmall = small.contains(c.code);
      final at = projector.geoToImage(c.centroid.lat, c.centroid.lon);
      if (isSmall && showFlags) _paintFlagIcon(canvas, c, at, s);
      if (isSmall && showGov) _paintGovernmentDot(canvas, c, at, s);
      if (showGov && c.governmentSystem.isMonarchy) _paintCrown(canvas, c, s);
      if (showFlags || showGov) {
        // Below the marker when there is one, centred on the area otherwise.
        final markerHalf = showFlags ? flagIconSize.height / 2 : 7.0;
        if (floatingNames) {
          _paintFloatingName(canvas, c, at, isSmall ? markerHalf : 0, s);
        } else {
          _paintName(canvas, c, isSmall ? at + Offset(0, (markerHalf + 9) * s) : at, s);
        }
      }
    }
  }

  /// Small flag icon (with border and shadow) for countries too small to fill.
  void _paintFlagIcon(Canvas canvas, Country c, Offset center, double s) {
    final flag = flags[c.code];
    if (flag == null || flag.size.isEmpty) return;
    final rect = Rect.fromCenter(
      center: center,
      width: flagIconSize.width * s,
      height: flagIconSize.height * s,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(2.5 * s));
    canvas
      ..drawRRect(rrect.shift(Offset(0, 1.5 * s)), Paint()..color = Colors.black38)
      ..save()
      ..clipRRect(rrect)
      ..translate(rect.left, rect.top)
      ..scale(rect.width / flag.size.width, rect.height / flag.size.height)
      ..drawPicture(flag.picture)
      ..restore()
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * s
          ..color = Colors.white,
      );
  }

  /// Colour dot for countries too small to fill in the Government layer.
  void _paintGovernmentDot(Canvas canvas, Country c, Offset center, double s) {
    canvas
      ..drawCircle(center, 8 * s, Paint()..color = Colors.white)
      ..drawCircle(center, 6.5 * s, Paint()..color = GovernmentStyle.color(c.governmentSystem));
  }

  /// Fills the country Area with its flag, warped by the same perspective as
  /// the snapshot so it looks painted on the canvas.
  void _paintFlag(Canvas canvas, Country c, Path area, Size size) {
    final flag = flags[c.code];
    if (flag == null || flag.size.isEmpty) return;
    // Up close a country can be far bigger than the screen: only composite
    // the visible part.
    final bounds = area.getBounds().intersect(Offset.zero & size);
    if (bounds.isEmpty) return;
    canvas
      ..saveLayer(
        bounds,
        Paint()..color = Colors.white.withValues(alpha: fillOpacity),
      )
      ..clipPath(area)
      ..transform(_flagToImage(c, flag.size).toMatrix4().storage)
      ..drawPicture(flag.picture)
      ..restore();
  }

  /// Flag pixels → image pixels: scale the flag to cover the country's
  /// bounding box on the (2:1) map, then apply the calibration homography.
  Homography _flagToImage(Country c, Size flagSize) {
    // Work in "map units" where the map is 2 x 1, so the flag keeps its
    // aspect ratio on the physical canvas.
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final g in c.outline) {
      final n = g.normalized;
      final x = n.dx * 2, y = n.dy;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    final w = maxX - minX, h = maxY - minY;
    final scale = [w / flagSize.width, h / flagSize.height].reduce((a, b) => a > b ? a : b);
    final ox = minX + (w - flagSize.width * scale) / 2;
    final oy = minY + (h - flagSize.height * scale) / 2;
    // flag (fx, fy) → normalized (u, v) = ((ox + fx*scale) / 2, oy + fy*scale)
    final flagToNormalized = Homography.fromValues([
      scale / 2, 0, ox / 2, //
      0, scale, oy, //
      0, 0, 1, //
    ]);
    return projector.mapToImageMatrix.compose(flagToNormalized);
  }

  void _paintGovernmentFill(Canvas canvas, Country c, Path area) {
    canvas.drawPath(
      area,
      Paint()
        ..color = GovernmentStyle.color(c.governmentSystem)
            .withValues(alpha: fillOpacity * 0.8),
    );
  }

  void _paintAreaOutline(Canvas canvas, Path area, bool selected, double s) {
    canvas.drawPath(
      area,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = (selected ? 3 : 1.2) * s
        ..color = selected ? Colors.amber : Colors.black54,
    );
  }

  void _paintName(Canvas canvas, Country c, Offset at, double s) {
    _paintText(
      canvas,
      c.name,
      at,
      TextStyle(
        fontSize: 11 * s,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        shadows: [
          Shadow(color: Colors.white, blurRadius: 3 * s),
          Shadow(color: Colors.white, blurRadius: 1.5 * s),
        ],
      ),
    );
  }

  /// Name on a soft pill floating above the country, with a short stem.
  void _paintFloatingName(Canvas canvas, Country c, Offset at, double markerHalf, double s) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: c.name,
        style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w700, color: Colors.black87),
      ),
    )..layout();
    final lift = (markerHalf + 16) * s;
    final rect = Rect.fromCenter(
      center: at - Offset(0, lift + tp.height / 2),
      width: tp.width + 14 * s,
      height: tp.height + 6 * s,
    );
    final pill = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    canvas
      ..drawLine(
        at - Offset(0, markerHalf * s),
        Offset(at.dx, rect.bottom),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.5 * s,
      )
      ..drawRRect(pill.shift(Offset(0, 2 * s)), Paint()..color = Colors.black26)
      ..drawRRect(pill, Paint()..color = Colors.white.withValues(alpha: 0.9));
    tp
      ..paint(canvas, rect.topLeft + Offset(7 * s, 3 * s))
      ..dispose();
  }

  void _paintCrown(Canvas canvas, Country c, double s) {
    final at = projector.geoToImage(c.capital.lat, c.capital.lon);
    _paintText(
      canvas,
      GovernmentStyle.crown,
      at - Offset(0, 14 * s),
      TextStyle(fontSize: 18 * s),
    );
  }

  void _paintText(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(text: text, style: style),
    )..layout();
    tp
      ..paint(canvas, center - Offset(tp.width / 2, tp.height / 2))
      ..dispose();
  }

  void _paintPin(Canvas canvas, Pin pin, double s) {
    final p = projector.geoToImage(pin.location.lat, pin.location.lon);
    final r = 7 * s;
    final fill = switch (pin.kind) {
      PinKind.volcano => const Color(0xFFE2462D),
      PinKind.peak => const Color(0xFF7A5230),
      PinKind.depression => const Color(0xFF2B7BB9),
    };
    final tri = pin.kind == PinKind.depression
        ? (Path()
          ..moveTo(p.dx - r, p.dy - r * 0.8)
          ..lineTo(p.dx + r, p.dy - r * 0.8)
          ..lineTo(p.dx, p.dy + r)
          ..close())
        : (Path()
          ..moveTo(p.dx, p.dy - r)
          ..lineTo(p.dx + r, p.dy + r * 0.8)
          ..lineTo(p.dx - r, p.dy + r * 0.8)
          ..close());
    canvas
      ..drawPath(tri, Paint()..color = fill)
      ..drawPath(
        tri,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 * s
          ..color = Colors.white,
      );
    if (pin.kind == PinKind.volcano) {
      final plume = Paint()..color = Colors.grey.withValues(alpha: 0.8);
      canvas
        ..drawCircle(p + Offset(1.5 * s, -r - 3 * s), 2.2 * s, plume)
        ..drawCircle(p + Offset(4 * s, -r - 6.5 * s), 1.6 * s, plume);
    }
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: '${pin.name} · ${l10n.elevationMeters(pin.elevationM)}',
        style: TextStyle(
          fontSize: 9.5 * s,
          fontWeight: FontWeight.w600,
          color: fill,
          shadows: [
            Shadow(color: Colors.white, blurRadius: 3 * s),
            Shadow(color: Colors.white, blurRadius: 1.5 * s),
          ],
        ),
      ),
    )..layout();
    tp
      ..paint(canvas, Offset(p.dx + r + 2 * s, p.dy - tp.height / 2))
      ..dispose();
  }

  /// Returns the country under [imagePoint] (image pixels), if any.
  static Country? countryAt(
    Offset imagePoint,
    PerspectiveProjector projector,
    List<Country> countries, {
    double labelRadiusPx = 0,
  }) {
    final n = projector.imageToMap(imagePoint);
    for (final c in countries) {
      if (_pointInPolygon(n, [for (final g in c.outline) g.normalized])) return c;
    }
    // Fallback for tiny countries: nearest centroid within the radius.
    Country? best;
    var bestDist = double.infinity;
    for (final c in countries) {
      final d = (projector.geoToImage(c.centroid.lat, c.centroid.lon) - imagePoint)
          .distance;
      if (d < bestDist) {
        bestDist = d;
        best = c;
      }
    }
    return bestDist <= labelRadiusPx ? best : null;
  }

  static bool _pointInPolygon(Offset p, List<Offset> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  @override
  bool shouldRepaint(MapOverlayPainter old) =>
      old.projector != projector ||
      old.countries != countries ||
      old.labelScale != labelScale ||
      old.selectedCode != selectedCode ||
      old.l10n != l10n ||
      old.flags != flags ||
      old.floatingNames != floatingNames ||
      !(old.layers.length == layers.length && old.layers.containsAll(layers));
}
