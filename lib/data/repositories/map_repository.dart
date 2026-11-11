import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/country.dart';

/// Read-only access to the content bundled with the app (countries, pins and
/// notes). Nothing leaves the device.
class MapRepository {
  MapRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const contentAsset = 'assets/data/world_sample.json';

  final AssetBundle _bundle;
  List<Country>? _countries;

  Future<List<Country>> loadCountries() async {
    final cached = _countries;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(contentAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return _countries = (json['countries'] as List<dynamic>)
        .map((c) => Country.fromJson(c as Map<String, dynamic>))
        .toList(growable: false);
  }
}
