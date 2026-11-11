import 'package:flutter/foundation.dart';

import 'geo_point.dart';
import 'government_system.dart';
import 'note.dart';
import 'pin.dart';

@immutable
class Leader {
  const Leader({required this.title, required this.name});

  factory Leader.fromJson(Map<String, dynamic> json) =>
      Leader(title: json['title'] as String, name: json['name'] as String);

  final String title;
  final String name;

  @override
  String toString() => '$title $name';
}

@immutable
class Country {
  const Country({
    required this.code,
    required this.iso2,
    required this.name,
    required this.flag,
    required this.capitalName,
    required this.capital,
    required this.centroid,
    required this.outline,
    required this.governmentType,
    required this.governmentSystem,
    required this.headOfState,
    required this.pins,
    required this.notes,
    this.headOfGovernment,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String;
    final capital = json['capital'] as Map<String, dynamic>;
    final notes = (json['notes'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return Country(
      code: code,
      iso2: json['iso2'] as String,
      name: json['name'] as String,
      flag: json['flag'] as String,
      capitalName: capital['name'] as String,
      capital: GeoPoint.fromJson(capital),
      centroid: GeoPoint.fromJson(json['centroid'] as Map<String, dynamic>),
      outline: (json['outline'] as List<dynamic>)
          .map((p) => GeoPoint.fromLonLat(p as List<dynamic>))
          .toList(growable: false),
      governmentType: json['government_type'] as String,
      governmentSystem: GovernmentSystem.parse(json['government_system'] as String),
      headOfState: Leader.fromJson(json['head_of_state'] as Map<String, dynamic>),
      headOfGovernment: json['head_of_government'] == null
          ? null
          : Leader.fromJson(json['head_of_government'] as Map<String, dynamic>),
      pins: (json['pins'] as List<dynamic>? ?? const [])
          .map((p) => Pin.fromJson(p as Map<String, dynamic>))
          .toList(growable: false),
      notes: [
        for (var i = 0; i < notes.length; i++)
          Note(
            id: '$code-note-$i',
            countryCode: code,
            kind: NoteKind.parse(notes[i]['kind'] as String),
            text: notes[i]['text'] as String,
          ),
      ],
    );
  }

  /// ISO 3166-1 alpha-3 code.
  final String code;

  /// ISO 3166-1 alpha-2 code, lowercase (used for the flag asset).
  final String iso2;
  final String name;

  /// Flag emoji.
  final String flag;
  final String capitalName;
  final GeoPoint capital;

  /// Label anchor for the country.
  final GeoPoint centroid;

  /// Simplified border polygon: the country's Area, used for highlighting
  /// and hit-testing.
  final List<GeoPoint> outline;
  final String governmentType;
  final GovernmentSystem governmentSystem;
  final Leader headOfState;
  final Leader? headOfGovernment;
  final List<Pin> pins;
  final List<Note> notes;

  String get flagAsset => 'assets/flags/$iso2.svg';
}
