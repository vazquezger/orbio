import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/geometry/homography.dart';
import '../../core/geometry/map_projection.dart';
import '../../core/geometry/perspective_projector.dart';
import '../../data/models/country.dart';
import '../../data/models/geo_point.dart';
import '../../data/models/world_question.dart';
import '../l10n_labels.dart';

/// Level of detail for labels and pills based on zoom progression.
enum MapDetailLevel {
  /// Wide view (< 1.6x): only territory flags and outlines, no floating pills.
  overview,

  /// Regional view (1.6x .. 3.0x): compact pills with rank, flag, badge.
  regional,

  /// Close-up view (>= 3.0x or tapped country): full pill with name, badge, and detail fact.
  closeUp,
}

/// Paints country flags and question answers on top of the canvas.
///
/// Works in two modes:
/// - **All flags** ([activeQuestion] == `null`): paints the flags of all
///   countries that have flag artwork.
/// - **Question answer** ([activeQuestion] != `null`): paints only the
///   countries in [WorldQuestion.items], adapting label level of detail
///   from clean overview to regional pills to close-up fact cards.
class MapOverlayPainter extends CustomPainter {
  MapOverlayPainter({
    required this.projector,
    required this.countries,
    required this.labelScale,
    required this.l10n,
    this.flags = const {},
    this.activeQuestion,
    this.selectedCode,
    this.floatingNames = false,
    this.isCloseUp,
    this.detailLevel,
  });

  final PerspectiveProjector projector;
  final List<Country> countries;
  final double labelScale;
  final AppLocalizations l10n;

  /// Flag artwork by country code (may be partially loaded).
  final Map<String, PictureInfo> flags;

  /// Currently selected question, or `null` to show all flags.
  final WorldQuestion? activeQuestion;
  final String? selectedCode;

  /// Live view style: names float above each country on a soft pill.
  final bool floatingNames;

  /// Explicit zoom level flag (e.g. from InteractiveViewer scale). If null,
  /// falls back to estimating close-up zoom from projector and labelScale.
  final bool? isCloseUp;

  /// Optional explicit semantic detail level (overview, regional, closeUp).
  final MapDetailLevel? detailLevel;

  /// Active semantic detail level, defaulting based on zoom/closeUp.
  MapDetailLevel get activeDetailLevel {
    if (detailLevel != null) return detailLevel!;
    if (isCloseUp == true) return MapDetailLevel.closeUp;
    return closeUp ? MapDetailLevel.regional : MapDetailLevel.overview;
  }

  /// Whether the view is currently zoomed in close enough to show full country
  /// names instead of compact flag-only pills.
  bool get closeUp =>
      isCloseUp ?? isCloseUpZoom(projector, const Size(1000, 800), labelScale);

  /// Opacity of area fills, so the canvas's black outlines stay visible.
  static const fillOpacity = 0.72;

  /// Below this on-screen size (√area, logical px) a country is too small to
  /// read a fill, so it gets a flag icon marker instead.
  static const smallAreaThreshold = 14.0;

  /// Ratio of projected world width to viewport width above which the view is
  /// considered a close-up ("zoom cortito") and shows each item's `detail`.
  static const closeUpZoomThreshold = 1.75;

  /// Flag icon size for small countries, logical px (4:3).
  static const flagIconSize = Size(26, 19.5);

  /// Whether a country whose projected rings are [imageRings] is too small
  /// on screen at [labelScale] (image px per logical px) to show a fill.
  static bool isSmallOnScreen(
    Iterable<List<Offset>> imageRings,
    double labelScale,
  ) {
    var area = 0.0;
    for (final r in imageRings) {
      area += polygonArea(r);
    }
    return math.sqrt(area) / labelScale < smallAreaThreshold;
  }

  /// Whether the current camera distance or pinch zoom is close enough to show
  /// the item descriptions (`detail`) below the countries.
  static bool isCloseUpZoom(
    PerspectiveProjector projector,
    Size canvasSize,
    double labelScale,
  ) {
    if (canvasSize.width <= 0) return false;
    final left = projector.geoToImage(0, -180);
    final right = projector.geoToImage(0, 180);
    final worldLogicalWidth = (right - left).distance / labelScale;
    final viewportLogicalWidth = canvasSize.width / labelScale;
    if (viewportLogicalWidth <= 0) return false;
    return (worldLogicalWidth / viewportLogicalWidth) >= closeUpZoomThreshold;
  }

  /// Path of all [rings], filled even-odd so holes stay empty.
  static Path ringsPath(Iterable<List<Offset>> rings) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final r in rings) {
      path.addPolygon(r, true);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = labelScale;
    final question = activeQuestion;
    final itemsByCode = question?.itemsByCode;

    // Filter to countries that should be drawn in the current mode.
    final visibleCountries = question != null
        ? [
            for (final c in countries)
              if (itemsByCode!.containsKey(c.code)) c,
          ]
        : [
            for (final c in countries)
              if (flags.containsKey(c.code) || c.code == selectedCode) c,
          ];

    final countryRings = <String, List<List<Offset>>>{};
    final countryAreas = <String, Path>{};
    final small = <String>{};

    for (final c in visibleCountries) {
      final rings = [
        for (final ring in c.areas)
          [for (final g in ring) projector.geoToImage(g.lat, g.lon)],
      ];
      final isSmall = isSmallOnScreen(rings, s);
      if (isSmall) small.add(c.code);
      countryRings[c.code] = rings;
      countryAreas[c.code] = ringsPath(rings);
    }

    // 1. Fallback fills for query items without SVG flags.
    if (question != null) {
      for (final c in visibleCountries) {
        if (!flags.containsKey(c.code)) {
          _paintFallbackFill(canvas, countryAreas[c.code]!);
        }
      }
    }

    // 2. Batch all SVG flag fills into a single saveLayer pass.
    // In "Todas las banderas" mode there are 174 countries. Calling saveLayer
    // once per country allocates 174 offscreen GPU render targets per frame,
    // which exhausts GPU command buffers and freezes iOS Impeller.
    // Batching everything under one saveLayer makes it 60-120 FPS butter smooth.
    final countriesWithFlags = [
      for (final c in visibleCountries)
        if ((!small.contains(c.code) || question != null) &&
            flags.containsKey(c.code))
          c,
    ];

    if (countriesWithFlags.isNotEmpty) {
      canvas.saveLayer(
        null,
        Paint()
          ..color =
              Color.fromARGB((fillOpacity * 255).round(), 255, 255, 255),
      );
      for (final c in countriesWithFlags) {
        _paintFlagDirect(canvas, c, countryRings[c.code]!);
      }
      canvas.restore();
    }

    // 3. Area outlines.
    for (final c in visibleCountries) {
      _paintAreaOutline(
        canvas,
        countryAreas[c.code]!,
        c.code == selectedCode || question != null,
        s,
      );
    }

    // 4. Icons and annotations.
    for (final c in visibleCountries) {
      final isSmall = small.contains(c.code);
      final at = projector.geoToImage(c.centroid.lat, c.centroid.lon);
      if (isSmall && flags.containsKey(c.code)) {
        _paintFlagIcon(canvas, c, at, s);
      }
      final markerHalf = (isSmall && flags.containsKey(c.code))
          ? flagIconSize.height / 2
          : 0.0;

      final isSelected = c.code == selectedCode;
      final countryLevel =
          isSelected ? MapDetailLevel.closeUp : activeDetailLevel;

      if (question != null) {
        // In overview, omit floating pills to avoid label clutter (especially in Europe),
        // unless the country is explicitly tapped/selected.
        if (countryLevel == MapDetailLevel.overview) {
          continue;
        }
        final item = itemsByCode![c.code]!;
        final rank = question.rankOf(c.code);
        _paintAnswerAnnotation(
          canvas,
          country: c,
          item: item,
          rank: rank,
          at: at,
          markerHalf: markerHalf,
          s: s,
          level: countryLevel,
        );
      } else {
        // In overview/all-flags mode without query, keep the world map clean.
        // Only show a floating pill/name if the user specifically tapped/selected this country.
        // Tapping opens the bottom CountryCard and shows the pin on the map.
        if (c.code != selectedCode) {
          continue;
        }
        final name = '${c.flag} ${c.localizedName(l10n.localeName)}';
        if (floatingNames) {
          _paintFloatingPill(canvas, name, at, markerHalf, s);
        } else {
          _paintName(
            canvas,
            name,
            isSmall ? at + Offset(0, (markerHalf + 9) * s) : at,
            s,
          );
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
      ..drawRRect(
        rrect.shift(Offset(0, 1.5 * s)),
        Paint()..color = Colors.black38,
      )
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

  /// Highlight fill for matched countries that don't have a bundled SVG file.
  void _paintFallbackFill(Canvas canvas, Path area) {
    canvas.drawPath(
      area,
      Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.46),
    );
  }

  /// Fills the country Area with its flag, warped by the same perspective as
  /// the snapshot so it looks painted on the canvas.
  void _paintFlagDirect(
    Canvas canvas,
    Country c,
    List<List<Offset>> rings,
  ) {
    final flag = flags[c.code];
    if (flag == null || flag.size.isEmpty) return;
    for (final group in flagGroups(c.areas)) {
      canvas
        ..save()
        ..clipPath(ringsPath([for (final i in group) rings[i]]))
        ..transform(
          _flagToImage([for (final i in group) c.areas[i]], flag.size)
              .toMatrix4()
              .storage,
        )
        ..drawPicture(flag.picture)
        ..restore();
    }
  }

  /// Groups ring indices that should share one flag: the main (largest)
  /// part plus every part whose centre lies within half a size of it.
  static List<List<int>> flagGroups(
    List<List<GeoPoint>> areas, [
    MapProjection projection = MapProjection.equirectangular,
  ]) {
    final boxes = [for (final r in areas) _mapBox(r, projection)];
    var main = 0;
    for (var i = 1; i < boxes.length; i++) {
      if (boxes[i].width * boxes[i].height >
          boxes[main].width * boxes[main].height) {
        main = i;
      }
    }
    final m = boxes[main];
    final near = m.inflate(math.max(m.width, m.height) * 0.5);
    final grouped = <int>[];
    final groups = <List<int>>[grouped];
    for (var i = 0; i < boxes.length; i++) {
      if (i == main || near.contains(boxes[i].center)) {
        grouped.add(i);
      } else {
        groups.add([i]);
      }
    }
    return groups;
  }

  static Rect _mapBox(
    Iterable<GeoPoint> ring, [
    MapProjection projection = MapProjection.equirectangular,
  ]) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final g in ring) {
      final n = g.normalizedWith(projection);
      final x = n.dx * 2, y = n.dy;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Homography _flagToImage(List<List<GeoPoint>> rings, Size flagSize) {
    final box = rings
        .map((r) => _mapBox(r, projector.projection))
        .reduce((a, b) => a.expandToInclude(b));
    final minX = box.left, minY = box.top;
    final w = box.width, h = box.height;
    final scale = [w / flagSize.width, h / flagSize.height]
        .reduce((a, b) => a > b ? a : b);
    final ox = minX + (w - flagSize.width * scale) / 2;
    final oy = minY + (h - flagSize.height * scale) / 2;
    final flagToNormalized = Homography.fromValues([
      scale / 2, 0, ox / 2, //
      0, scale, oy, //
      0, 0, 1, //
    ]);
    return projector.mapToImageMatrix.compose(flagToNormalized);
  }

  @visibleForTesting
  Homography flagToImageForTest(List<List<GeoPoint>> rings, Size flagSize) =>
      _flagToImage(rings, flagSize);

  void _paintAreaOutline(Canvas canvas, Path area, bool highlighted, double s) {
    canvas.drawPath(
      area,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = (highlighted ? 2.4 : 1.2) * s
        ..color = highlighted ? Colors.amber : Colors.black54,
    );
  }

  void _paintName(Canvas canvas, String name, Offset at, double s) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(
        text: name,
        style: TextStyle(
          fontSize: 11 * s,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
          shadows: [
            Shadow(color: Colors.white, blurRadius: 3 * s),
            Shadow(color: Colors.white, blurRadius: 1.5 * s),
          ],
        ),
      ),
    )..layout();
    tp
      ..paint(canvas, at - Offset(tp.width / 2, tp.height / 2))
      ..dispose();
  }

  /// Name on a soft pill floating above the country, with a short stem.
  /// Name on a soft pill floating above the country, with a short stem.
  /// If [subtitle] is provided, displays a multi-line detail card.
  void _paintFloatingPill(
    Canvas canvas,
    String label,
    Offset at,
    double markerHalf,
    double s, {
    String? subtitle,
  }) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 12.5 * s,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    )..layout();

    TextPainter? tpSub;
    if (subtitle != null && subtitle.trim().isNotEmpty) {
      tpSub = TextPainter(
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '...',
        text: TextSpan(
          text: subtitle.trim(),
          style: TextStyle(
            fontSize: 10.0 * s,
            fontWeight: FontWeight.w500,
            color: Colors.black87.withValues(alpha: 0.85),
            height: 1.15,
          ),
        ),
      )..layout(maxWidth: math.max(160.0 * s, tp.width + 20 * s));
    }

    final contentWidth = tpSub != null ? math.max(tp.width, tpSub.width) : tp.width;
    final contentHeight = tpSub != null
        ? tp.height + 3 * s + tpSub.height
        : tp.height;

    final lift = (markerHalf + 14) * s;
    final pillWidth = contentWidth + 14 * s;
    final pillHeight = contentHeight + 6 * s;
    final rect = Rect.fromCenter(
      center: at - Offset(0, lift + pillHeight / 2),
      width: pillWidth,
      height: pillHeight,
    );
    final radius = tpSub != null ? Radius.circular(8 * s) : Radius.circular(pillHeight / 2);
    final pill = RRect.fromRectAndRadius(rect, radius);

    canvas
      ..drawLine(
        at - Offset(0, markerHalf * s),
        Offset(at.dx, rect.bottom),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.60)
          ..strokeWidth = 1.5 * s,
      )
      ..drawRRect(pill.shift(Offset(0, 1.5 * s)), Paint()..color = Colors.black12)
      ..drawRRect(pill, Paint()..color = Colors.white.withValues(alpha: 0.72))
      ..drawRRect(
        pill,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 * s
          ..color = Colors.white.withValues(alpha: 0.88),
      );

    tp.paint(canvas, rect.topLeft + Offset(7 * s, 3 * s));
    if (tpSub != null) {
      tpSub.paint(canvas, rect.topLeft + Offset(7 * s, 3 * s + tp.height + 3 * s));
      tpSub.dispose();
    }
    tp.dispose();
  }

  static bool _isRedundantBadge(
    String? badge,
    Country country,
    WorldQuestion? question,
  ) {
    if (badge == null || badge.trim().isEmpty) return true;
    final b = badge.trim().toLowerCase();

    // Exact match of country name (English or Spanish).
    if (b == country.name.toLowerCase() || b == country.nameEs.toLowerCase()) {
      return true;
    }

    // Generic continents, regions or filler words.
    const generic = {
      'africa', 'áfrica', 'europa', 'europe', 'asia', 'america', 'américa',
      'oceania', 'oceanía', 'antartida', 'antártida', 'pais', 'país', 'country',
      'estado', 'state', 'nacion', 'nación', 'miembro', 'member', 'region',
      'región',
    };
    if (generic.contains(b)) return true;

    // Check if the badge matches the non-numeric topic of the question.
    if (question != null) {
      final q = question.question.toLowerCase();
      if (q.contains(b) && !RegExp(r'\d').hasMatch(b)) {
        return true;
      }

      // If multiple items share the exact same non-numeric badge, it's a category tag.
      if (question.items.length >= 3 && !RegExp(r'\d').hasMatch(b)) {
        var sameCount = 0;
        for (final it in question.items) {
          if (it.badge?.trim().toLowerCase() == b) sameCount++;
        }
        if (sameCount >= 3 || sameCount >= (question.items.length * 0.4)) {
          return true;
        }
      }
    }
    return false;
  }

  @visibleForTesting
  static bool isRedundantBadgeForTest(
    String? badge,
    Country country,
    WorldQuestion? question,
  ) =>
      _isRedundantBadge(badge, country, question);

  /// Paints the question answer pill on/above the country.
  void _paintAnswerAnnotation(
    Canvas canvas, {
    required Country country,
    required AnswerItem item,
    required int? rank,
    required Offset at,
    required double markerHalf,
    required double s,
    required MapDetailLevel level,
  }) {
    final rawBadge = item.badge?.trim();
    final isRedundant = _isRedundantBadge(rawBadge, country, activeQuestion);
    final badge = isRedundant ? null : rawBadge;
    final countryName = country.localizedName(l10n.localeName);

    // Pill ALWAYS includes the flag (country.flag).
    final parts = <String>[
      if (rank != null) '#$rank',
      country.flag,
      if (level == MapDetailLevel.closeUp || badge == null) countryName,
      if (badge != null && badge.isNotEmpty) badge,
    ];
    final pillText = parts.join(' ');
    _paintFloatingPill(
      canvas,
      pillText,
      at,
      markerHalf,
      s,
      subtitle: level == MapDetailLevel.closeUp ? item.detail : null,
    );
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
      var inside = false;
      for (final ring in c.areas) {
        if (_pointInPolygon(n, [for (final g in ring) g.normalizedWith(projector.projection)])) {
          inside = !inside;
        }
      }
      if (inside) return c;
    }
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
      old.activeQuestion != activeQuestion ||
      old.l10n != l10n ||
      old.flags != flags ||
      old.floatingNames != floatingNames ||
      old.isCloseUp != isCloseUp ||
      old.detailLevel != detailLevel;
}
