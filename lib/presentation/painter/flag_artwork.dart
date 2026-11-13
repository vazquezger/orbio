import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/models/country.dart';

/// Loads flag SVGs as pictures, keyed by country code. Countries without a
/// bundled SVG file use their flag emoji and highlight fill instead.
abstract final class FlagArtwork {
  /// In-memory cache of raw SVG XML strings so subsequent loads are instant
  /// and don't re-read the asset bundle from disk.
  static final Map<String, String> _svgStringCache = {};

  static Future<Map<String, PictureInfo>> loadAll(
    List<Country> countries, {
    AssetBundle? bundle,
  }) async {
    final b = bundle ?? rootBundle;
    Set<String>? available;
    if (_svgStringCache.isEmpty) {
      try {
        final manifest = await AssetManifest.loadFromAssetBundle(b);
        available = manifest.listAssets().toSet();
      } catch (e) {
        debugPrint('FlagArtwork: AssetManifest.load failed ($e)');
        available = null;
      }
    }

    final loaded = <String, PictureInfo>{};
    await Future.wait(
      countries.map((c) async {
        try {
          String? svgXml = _svgStringCache[c.code];
          if (svgXml == null) {
            String? targetKey;
            if (available != null) {
              if (available.contains(c.flagAsset)) {
                targetKey = c.flagAsset;
              } else {
                targetKey = available.cast<String?>().firstWhere(
                      (a) => a != null && a.endsWith('/${c.iso2}.svg'),
                      orElse: () => null,
                    );
              }
            } else {
              targetKey = c.flagAsset;
            }

            if (targetKey == null) return;
            try {
              svgXml = await b.loadString(targetKey);
            } catch (_) {
              svgXml = await b.loadString(c.flagAsset);
            }
            _svgStringCache[c.code] = svgXml;
          }

          final pic = await vg.loadPicture(
            SvgStringLoader(svgXml),
            null,
          );
          loaded[c.code] = pic;
        } catch (e) {
          debugPrint('Flag ${c.code} (${c.flagAsset}) failed: $e');
        }
      }),
    );
    return loaded;
  }

  static void disposeAll(Map<String, PictureInfo> flags) {
    for (final f in flags.values) {
      f.picture.dispose();
    }
  }
}
