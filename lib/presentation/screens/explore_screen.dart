import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/geometry/perspective_projector.dart';
import '../../data/models/country.dart';
import '../../data/models/government_system.dart';
import '../../data/models/map_layer.dart';
import '../../data/repositories/map_repository.dart';
import '../l10n_labels.dart';
import '../painter/government_style.dart';
import '../painter/map_overlay_painter.dart';
import '../widgets/country_detail_sheet.dart';
import '../widgets/layer_toggle_bar.dart';

/// Step 3 (Explore): zoomable snapshot with the layers projected on top.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.image,
    required this.corners,
    required this.repository,
  });

  /// Owned by this screen (disposed with it).
  final ui.Image image;

  /// Calibrated corner handles in image pixels, `[TL, TR, BR, BL]`.
  final List<Offset> corners;
  final MapRepository repository;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _transform = TransformationController();
  late final PerspectiveProjector _projector = PerspectiveProjector(
    widget.corners,
  );
  Set<MapLayer> _layers = {MapLayer.flags};
  List<Country> _countries = const [];
  Map<String, PictureInfo> _flags = const {};
  String? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _transform.dispose();
    widget.image.dispose();
    for (final f in _flags.values) {
      f.picture.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final countries = await widget.repository.loadCountries();
      if (!mounted) return;
      setState(() => _countries = countries);
      await _loadFlags(countries);
    } catch (e) {
      if (mounted) {
        setState(() => _error = context.l10n.exploreLoadFailed('$e'));
      }
    }
  }

  /// Loads flag artwork; a missing or broken flag just leaves that country
  /// unfilled.
  Future<void> _loadFlags(List<Country> countries) async {
    final loaded = <String, PictureInfo>{};
    for (final c in countries) {
      try {
        loaded[c.code] = await vg.loadPicture(
          SvgAssetLoader(c.flagAsset),
          null,
        );
      } catch (e) {
        debugPrint('Flag ${c.flagAsset} failed: $e');
      }
    }
    if (!mounted) {
      for (final f in loaded.values) {
        f.picture.dispose();
      }
      return;
    }
    setState(() => _flags = loaded);
  }

  Future<void> _onTap(Offset imagePoint, double labelScale) async {
    final hit = MapOverlayPainter.countryAt(
      imagePoint,
      _projector,
      _countries,
      labelRadiusPx: 36 * labelScale,
    );
    if (hit == null) {
      setState(() => _selected = null);
      return;
    }
    setState(() => _selected = hit.code);
    await CountryDetailSheet.show(context, country: hit);
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: Text(context.l10n.exploreTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.exploreResetZoom,
            onPressed: () => _transform.value = Matrix4.identity(),
            icon: const Icon(Icons.zoom_out_map),
          ),
          IconButton(
            tooltip: context.l10n.exploreRecalibrate,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.crop_free),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: LayerToggleBar(
              active: _layers,
              onChanged: (l) => setState(() => _layers = l),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _buildViewer(image, iw, ih)),
                if (_layers.contains(MapLayer.government))
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: IgnorePointer(
                      child: _GovernmentLegend(countries: _countries),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                context.l10n.exploreHint,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Colors.white60),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewer(ui.Image image, double iw, double ih) {
    return LayoutBuilder(
      builder: (context, box) {
        final fit = math.min(box.maxWidth / iw, box.maxHeight / ih);
        return InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 16,
          child: SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: FittedBox(
              child: SizedBox(
                width: iw,
                height: ih,
                child: ListenableBuilder(
                  listenable: _transform,
                  builder: (context, _) {
                    final zoom = _transform.value.getMaxScaleOnAxis();
                    final labelScale = 1 / (fit * zoom);
                    return GestureDetector(
                      onTapUp: (d) => _onTap(d.localPosition, labelScale),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RawImage(
                            image: image,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.medium,
                          ),
                          CustomPaint(
                            painter: MapOverlayPainter(
                              projector: _projector,
                              countries: _countries,
                              layers: _layers,
                              l10n: context.l10n,
                              flags: _flags,
                              labelScale: labelScale,
                              selectedCode: _selected,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fixed legend for the Government layer; lists only systems on the map.
class _GovernmentLegend extends StatelessWidget {
  const _GovernmentLegend({required this.countries});
  final List<Country> countries;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final present = {for (final c in countries) c.governmentSystem};
    final systems = GovernmentSystem.values.where(present.contains).toList();
    if (systems.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final g in systems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: GovernmentStyle.color(g),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      GovernmentStyle.label(g, l),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (systems.any((g) => g.isMonarchy))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.govMonarchyHint,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
