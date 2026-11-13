import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/geometry/map_projection.dart';
import '../../core/geometry/perspective_projector.dart';
import '../../data/models/country.dart';
import '../../data/repositories/map_repository.dart';
import '../../data/repositories/question_store.dart';
import '../l10n_labels.dart';
import '../painter/flag_artwork.dart';
import '../painter/map_overlay_painter.dart';
import '../widgets/country_card.dart';
import '../widgets/question_bar.dart';

/// Step 3 (Explore): zoomable snapshot with flags and question answers
/// projected on top.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.image,
    required this.corners,
    required this.repository,
    this.projection = MapProjection.equirectangular,
    this.questionStore,
  });

  /// Owned by this screen (disposed with it).
  final ui.Image image;

  /// Calibrated corner handles in image pixels, `[TL, TR, BR, BL]`.
  final List<Offset> corners;
  final MapRepository repository;
  final MapProjection projection;
  final QuestionStore? questionStore;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _transform = TransformationController();
  late final PerspectiveProjector _projector = PerspectiveProjector(
    widget.corners,
    projection: widget.projection,
  );
  late final QuestionStore _questionStore =
      widget.questionStore ?? QuestionStore();

  List<Country> _countries = const [];
  Map<String, PictureInfo> _flags = const {};
  String? _selected;
  String? _error;
  bool _barCollapsed = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _transform.dispose();
    widget.image.dispose();
    FlagArtwork.disposeAll(_flags);
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

  Future<void> _loadFlags(List<Country> countries) async {
    final loaded = await FlagArtwork.loadAll(countries);
    debugPrint('ExploreScreen: received ${loaded.length} loaded flags');
    if (!mounted) {
      FlagArtwork.disposeAll(loaded);
      return;
    }
    setState(() => _flags = loaded);
  }

  void _onTap(Offset imagePoint, double labelScale) {
    final active = _questionStore.activeQuestion;
    final candidates = active != null
        ? [
            for (final c in _countries)
              if (active.itemsByCode.containsKey(c.code)) c,
          ]
        : _countries;
    final hit = MapOverlayPainter.countryAt(
      imagePoint,
      _projector,
      candidates,
      labelRadiusPx: 36 * labelScale,
    );
    setState(() {
      _selected = (hit == null || _selected == hit.code) ? null : hit.code;
      _barCollapsed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final iw = image.width.toDouble(), ih = image.height.toDouble();

    Country? selectedCountry;
    if (_selected != null) {
      for (final c in _countries) {
        if (c.code == _selected) {
          selectedCountry = c;
          break;
        }
      }
    }
    final activeQ = _questionStore.activeQuestion;
    final selectedItem = selectedCountry != null ? activeQ?.itemsByCode[selectedCountry.code] : null;
    final selectedRank = selectedCountry != null ? activeQ?.rankOf(selectedCountry.code) : null;

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
                if (selectedCountry != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: _barCollapsed ? 12 : 78,
                    child: SafeArea(
                      top: false,
                      child: CountryCard(
                        country: selectedCountry,
                        item: selectedItem,
                        rank: selectedRank,
                        onClose: () => setState(() => _selected = null),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: _barCollapsed ? null : 12,
                  bottom: selectedCountry != null && _barCollapsed ? 148 : 12,
                  child: SafeArea(
                    top: false,
                    child: QuestionBar(
                      store: _questionStore,
                      countries: _countries,
                      collapsed: _barCollapsed,
                      onCollapsedChanged: (c) =>
                          setState(() => _barCollapsed = c),
                    ),
                  ),
                ),
              ],
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
          onInteractionStart: (_) {
            if (!_barCollapsed) {
              setState(() => _barCollapsed = true);
            }
          },
          child: SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: FittedBox(
              child: SizedBox(
                width: iw,
                height: ih,
                child: ListenableBuilder(
                  listenable: Listenable.merge([_transform, _questionStore]),
                  builder: (context, _) {
                    final zoom = _transform.value.getMaxScaleOnAxis();
                    final labelScale = 1 / (fit * zoom);
                    final MapDetailLevel detailLevel;
                    if (zoom < 1.6) {
                      detailLevel = MapDetailLevel.overview;
                    } else if (zoom < 3.0) {
                      detailLevel = MapDetailLevel.regional;
                    } else {
                      detailLevel = MapDetailLevel.closeUp;
                    }
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
                              l10n: context.l10n,
                              flags: _flags,
                              labelScale: labelScale,
                              activeQuestion: _questionStore.activeQuestion,
                              selectedCode: _selected,
                              isCloseUp: zoom >= 3.0,
                              detailLevel: detailLevel,
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
