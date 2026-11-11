import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../../core/geometry/map_projection.dart';

@immutable
class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        (json['lat'] as num).toDouble(),
        (json['lon'] as num).toDouble(),
      );

  /// Parses a GeoJSON-ordered `[lon, lat]` pair.
  factory GeoPoint.fromLonLat(List<dynamic> pair) =>
      GeoPoint((pair[1] as num).toDouble(), (pair[0] as num).toDouble());

  final double lat;
  final double lon;

  Offset get normalized => MapProjection.toNormalized(lat, lon);

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};
}
