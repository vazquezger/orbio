import 'package:flutter/foundation.dart';

import 'geo_point.dart';

enum PinKind {
  volcano,
  peak,
  depression;

  static PinKind parse(String raw) =>
      PinKind.values.firstWhere((t) => t.name == raw, orElse: () => PinKind.peak);
}

/// A point item drawn on the map (volcano, mountain, depression…).
@immutable
class Pin {
  const Pin({
    required this.id,
    required this.name,
    required this.kind,
    required this.location,
    required this.elevationM,
    this.description = '',
  });

  factory Pin.fromJson(Map<String, dynamic> json) => Pin(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: PinKind.parse(json['kind'] as String),
        location: GeoPoint.fromJson(json),
        elevationM: (json['elevation_m'] as num).toInt(),
        description: json['description'] as String? ?? '',
      );

  final String id;
  final String name;
  final PinKind kind;
  final GeoPoint location;

  /// Elevation in metres above sea level (negative below).
  final int elevationM;
  final String description;
}
