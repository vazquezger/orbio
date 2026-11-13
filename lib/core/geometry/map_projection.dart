import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Supported map projection models.
enum MapProjectionType {
  /// Plate Carrée / Equirectangular linear projection (used by Orbio canvas).
  equirectangular,

  /// Commercial school wall map Mercator with Antarctica cut around -60°.
  mercatorSchool,

  /// Full Web Mercator (EPSG:3857) with bounds ~[-85.05°, 85.05°].
  mercatorStandard,
}

/// Abstract base class for converting between geographic coordinates
/// (lat, lon) and the normalized [0, 1] x [0, 1] map space.
abstract class MapProjection {
  const MapProjection();

  static const MapProjection equirectangular = EquirectangularProjection();
  static const MapProjection mercatorSchool = MercatorProjection.schoolWallMap();
  static const MapProjection mercatorStandard = MercatorProjection.standard();

  MapProjectionType get type;

  /// Maps geographic (lat, lon) in degrees to normalized map coordinates [0..1] x [0..1].
  Offset toNormalized(double lat, double lon);

  /// Maps normalized map coordinates [0..1] x [0..1] back to geographic (lat, lon).
  ({double lat, double lon}) toGeo(Offset normalized);

  /// Backwards-compatible convenience methods delegating to [equirectangular].
  static Offset toNormalizedDefault(double lat, double lon) =>
      equirectangular.toNormalized(lat, lon);

  static ({double lat, double lon}) toGeoDefault(Offset normalized) =>
      equirectangular.toGeo(normalized);
}

/// Equirectangular (Plate Carrée) projection.
///
/// Normalized space: `(0,0)` is top-left (lon -180, lat 90) and
/// `(1,1)` is bottom-right (lon 180, lat -90).
class EquirectangularProjection extends MapProjection {
  const EquirectangularProjection();

  @override
  MapProjectionType get type => MapProjectionType.equirectangular;

  @override
  Offset toNormalized(double lat, double lon) =>
      Offset((lon + 180.0) / 360.0, (90.0 - lat) / 180.0);

  @override
  ({double lat, double lon}) toGeo(Offset normalized) => (
        lat: 90.0 - normalized.dy * 180.0,
        lon: normalized.dx * 360.0 - 180.0,
      );
}

/// Mercator projection supporting custom latitude clipping (e.g. school maps).
class MercatorProjection extends MapProjection {
  const MercatorProjection({
    this.minLat = -60.0,
    this.maxLat = 85.0,
    this.minLon = -180.0,
    this.maxLon = 180.0,
  });

  /// Standard square Web Mercator (including Antarctica down to -85.0511°).
  const MercatorProjection.standard()
      : minLat = -85.05112878,
        maxLat = 85.05112878,
        minLon = -180.0,
        maxLon = 180.0;

  /// Commercial school wall map (Antarctica cut at -60°).
  const MercatorProjection.schoolWallMap()
      : minLat = -60.0,
        maxLat = 85.0,
        minLon = -180.0,
        maxLon = 180.0;

  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  @override
  MapProjectionType get type =>
      minLat <= -80 ? MapProjectionType.mercatorStandard : MapProjectionType.mercatorSchool;

  static double _mercatorY(double latDeg) {
    final clamped = latDeg.clamp(-89.9999, 89.9999);
    final rad = clamped * math.pi / 180.0;
    return math.log(math.tan(math.pi / 4.0 + rad / 2.0));
  }

  static double _inverseMercatorY(double y) {
    final rad = 2.0 * math.atan(math.exp(y)) - math.pi / 2.0;
    return rad * 180.0 / math.pi;
  }

  @override
  Offset toNormalized(double lat, double lon) {
    final x = (lon - minLon) / (maxLon - minLon);
    final yMax = _mercatorY(maxLat);
    final yMin = _mercatorY(minLat);
    final yVal = _mercatorY(lat);
    final y = (yMax - yVal) / (yMax - yMin);
    return Offset(x, y);
  }

  @override
  ({double lat, double lon}) toGeo(Offset normalized) {
    final lon = normalized.dx * (maxLon - minLon) + minLon;
    final yMax = _mercatorY(maxLat);
    final yMin = _mercatorY(minLat);
    final yVal = yMax - normalized.dy * (yMax - yMin);
    final lat = _inverseMercatorY(yVal);
    return (lat: lat, lon: lon);
  }
}
