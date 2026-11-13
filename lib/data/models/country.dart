import 'package:flutter/foundation.dart';

import 'geo_point.dart';

@immutable
class Country {
  const Country({
    required this.code,
    required this.iso2,
    required this.name,
    required this.nameEs,
    required this.flag,
    required this.centroid,
    required this.areas,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    return Country(
      code: json['code'] as String,
      iso2: json['iso2'] as String,
      name: name,
      nameEs: (json['name_es'] as String?) ?? name,
      flag: json['flag'] as String,
      centroid: GeoPoint.fromJson(json['centroid'] as Map<String, dynamic>),
      areas: [
        for (final ring in (json['areas'] as List<dynamic>).cast<List<dynamic>>())
          [for (final p in ring.cast<List<dynamic>>()) GeoPoint.fromLonLat(p)],
      ],
    );
  }

  /// ISO 3166-1 alpha-3 code (Natural Earth ADM0_A3).
  final String code;

  /// ISO 3166-1 alpha-2 code, lowercase (used for the flag asset).
  final String iso2;
  final String name;
  final String nameEs;

  /// Flag emoji.
  final String flag;

  /// Label point for the country (Natural Earth label position).
  final GeoPoint centroid;

  /// The country's Area: Natural Earth 1:110m rings (islands, exclaves and
  /// holes), filled even-odd. Used for flags, highlighting and hit-testing.
  final List<List<GeoPoint>> areas;

  String localizedName(String languageCode) =>
      languageCode.startsWith('es') ? nameEs : name;

  String get flagAsset => 'assets/flags/$iso2.svg';
}
