import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/models/country.dart';

/// Loads flag SVGs as pictures, keyed by country code. A missing or broken
/// flag is skipped (that country is just not filled).
abstract final class FlagArtwork {
  static Future<Map<String, PictureInfo>> loadAll(List<Country> countries) async {
    final loaded = <String, PictureInfo>{};
    for (final c in countries) {
      try {
        loaded[c.code] = await vg.loadPicture(SvgAssetLoader(c.flagAsset), null);
      } catch (e) {
        debugPrint('Flag ${c.flagAsset} failed: $e');
      }
    }
    return loaded;
  }

  static void disposeAll(Map<String, PictureInfo> flags) {
    for (final f in flags.values) {
      f.picture.dispose();
    }
  }
}
