import 'dart:ui' show Offset;

/// Equirectangular projection between geographic coordinates and the
/// normalized map square used throughout Orbio.
///
/// Normalized space: `(0,0)` is the top-left anchor (lon -180, lat 90) and
/// `(1,1)` the bottom-right anchor (lon 180, lat -90) of the printed canvas.
abstract final class MapProjection {
  static Offset toNormalized(double lat, double lon) =>
      Offset((lon + 180.0) / 360.0, (90.0 - lat) / 180.0);

  static ({double lat, double lon}) toGeo(Offset normalized) => (
        lat: 90.0 - normalized.dy * 180.0,
        lon: normalized.dx * 360.0 - 180.0,
      );
}
