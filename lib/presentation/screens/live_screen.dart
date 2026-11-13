import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/geometry/homography.dart';
import '../../core/geometry/perspective_projector.dart';
import '../../core/tracking/aruco_detector.dart';
import '../../core/tracking/marker_tracker.dart';
import '../../data/models/country.dart';
import '../../data/repositories/map_repository.dart';
import '../../data/repositories/question_store.dart';
import '../l10n_labels.dart';
import '../painter/flag_artwork.dart';
import '../painter/map_overlay_painter.dart';
import '../widgets/country_card.dart';
import '../widgets/question_bar.dart';

/// Live view (AR): the camera stream with flags and question answers painted on
/// the physical canvas.
///
/// Every frame the printed ArUco markers are detected (pure Dart, on a
/// background isolate) and the canvas homography is solved from all visible
/// marker corners, so the phone can look at any part of the canvas. Moving
/// closer is the zoom, revealing each country's description on the map.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    required this.repository,
    this.questionStore,
  });

  final MapRepository repository;
  final QuestionStore? questionStore;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  static const _analysisSize = 1280;
  static const _lostAfter = Duration(milliseconds: 2000);
  static const _smoothing = 0.55;

  late final QuestionStore _questionStore =
      widget.questionStore ?? QuestionStore();

  CameraController? _controller;
  MarkerTracker? _tracker;
  List<Country> _countries = const [];
  Map<String, PictureInfo> _flags = const {};
  String? _selected;
  String? _error;

  bool _busy = false;
  DateTime _lastSeen = DateTime.fromMillisecondsSinceEpoch(0);

  List<Offset>? _screenCorners;
  Size? _previewSize;

  bool _debug = false;
  List<List<Offset>> _debugQuads = const [];
  List<int> _debugIds = const [];
  int _lastMs = 0;
  bool _isBarCollapsed = false;

  double _minZoom = 1.0;
  double _maxZoom = 4.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    final c = _controller;
    _controller = null;
    if (c != null) {
      if (c.value.isStreamingImages) c.stopImageStream().catchError((_) {});
      c.dispose();
    }
    FlagArtwork.disposeAll(_flags);
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final layoutRaw =
          await DefaultAssetBundle.of(context).loadString(MarkerLayout.asset);
      _tracker = MarkerTracker(MarkerLayout.fromJson(layoutRaw));
      final countries = await widget.repository.loadCountries();
      final flags = await FlagArtwork.loadAll(countries);
      if (!mounted) {
        FlagArtwork.disposeAll(flags);
        return;
      }
      setState(() {
        _countries = countries;
        _flags = flags;
      });

      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final minZ = await controller.getMinZoomLevel().catchError((_) => 1.0);
      final maxZ = await controller.getMaxZoomLevel().catchError((_) => 4.0);
      _minZoom = minZ;
      _maxZoom = math.min(5.0, maxZ);
      _currentZoom = _minZoom;

      setState(() => _controller = controller);
      await controller.startImageStream(_onFrame);
    } catch (e) {
      if (mounted) setState(() => _error = context.l10n.liveUnavailable);
      debugPrint('Live view failed to start: $e');
    }
  }

  Future<void> _setZoom(double zoom) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    if ((clamped - _currentZoom).abs() < 0.02) return;
    try {
      await c.setZoomLevel(clamped);
      if (mounted) setState(() => _currentZoom = clamped);
    } catch (_) {}
  }

  Future<void> _onFrame(CameraImage frame) async {
    final tracker = _tracker;
    if (_busy || tracker == null || !mounted) return;
    _busy = true;
    try {
      final plane = frame.planes.first;
      final step = math.max(
        1,
        (math.max(frame.width, frame.height) / _analysisSize).ceil(),
      );
      final gw = frame.width ~/ step, gh = frame.height ~/ step;
      final gray = Uint8List(gw * gh);
      final src = plane.bytes, rowBytes = plane.bytesPerRow;
      for (var y = 0; y < gh; y++) {
        final row = y * step * rowBytes;
        for (var x = 0; x < gw; x++) {
          gray[y * gw + x] = src[row + x * step];
        }
      }

      final sw = Stopwatch()..start();
      final result = await compute(_trackJob, (tracker, gray, gw, gh));
      sw.stop();
      if (!mounted) return;
      _apply(result, step, frame.width, frame.height, sw.elapsedMilliseconds);
    } catch (e) {
      debugPrint('Tracking frame failed: $e');
    } finally {
      _busy = false;
    }
  }

  void _apply(
    TrackingResult? result,
    int step,
    int frameW,
    int frameH,
    int ms,
  ) {
    final preview = _previewSize;
    if (preview == null) return;
    final now = DateTime.now();
    if (result == null) {
      if (now.difference(_lastSeen) > _lostAfter && _screenCorners != null) {
        setState(() {
          _screenCorners = null;
          _debugQuads = const [];
          _debugIds = const [];
          _lastMs = ms;
        });
      }
      return;
    }
    _lastSeen = now;

    final toPreview = _frameToPreview(frameW, frameH, preview).compose(
      Homography.fromValues(
        [step.toDouble(), 0, 0, 0, step.toDouble(), 0, 0, 0, 1],
      ),
    );
    final mapToScreen = toPreview.compose(result.mapToImage);
    final target = [
      for (final c in PerspectiveProjector.normalizedCorners)
        mapToScreen.transform(c),
    ];
    final prev = _screenCorners;
    final smoothed = prev == null
        ? target
        : [
            for (var i = 0; i < 4; i++)
              Offset.lerp(prev[i], target[i], _smoothing)!,
          ];

    setState(() {
      _screenCorners = smoothed;
      _lastMs = ms;
      if (_debug) {
        _debugQuads = [
          for (final DetectedMarker m in result.markers)
            [for (final p in m.corners) toPreview.transform(p)],
        ];
        _debugIds = [for (final m in result.markers) m.id];
      }
    });
  }

  Homography _frameToPreview(int frameW, int frameH, Size preview) {
    final frameLandscape = frameW > frameH;
    final previewLandscape = preview.width > preview.height;
    if (frameLandscape == previewLandscape) {
      final sx = preview.width / frameW, sy = preview.height / frameH;
      return Homography.fromValues([sx, 0, 0, 0, sy, 0, 0, 0, 1]);
    }
    final sensor = _controller?.description.sensorOrientation ?? 90;
    final sx = preview.width / frameH, sy = preview.height / frameW;
    return sensor == 270
        ? Homography.fromValues([0, sx, 0, -sy, 0, sy * frameW, 0, 0, 1])
        : Homography.fromValues([0, -sx, sx * frameH, sy, 0, 0, 0, 0, 1]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = _controller;
    final corners = _screenCorners;

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l.liveTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: l.liveDebugTooltip,
            isSelected: _debug,
            onPressed: () => setState(() => _debug = !_debug),
            icon: const Icon(Icons.bug_report_outlined),
            selectedIcon: const Icon(Icons.bug_report),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          else if (controller == null || !controller.value.isInitialized)
            const Center(child: CircularProgressIndicator())
          else
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (_) => _baseZoom = _currentZoom,
                onScaleUpdate: (d) => _setZoom(_baseZoom * d.scale),
                onTapUp: (d) {
                  final c = _screenCorners;
                  if (c == null) return;
                  final proj = PerspectiveProjector(c);
                  final hit = MapOverlayPainter.countryAt(
                    d.localPosition,
                    proj,
                    _countries,
                    labelRadiusPx: 36,
                  );
                  setState(() => _selected = (hit == null || _selected == hit.code) ? null : hit.code);
                },
                child: CameraPreview(
                  controller,
                  child: LayoutBuilder(builder: (context, box) {
                    _previewSize = box.biggest;
                    final detailLevel = _currentZoom >= 2.5
                        ? MapDetailLevel.closeUp
                        : (_currentZoom >= 1.5
                            ? MapDetailLevel.regional
                            : MapDetailLevel.overview);
                    return ListenableBuilder(
                      listenable: _questionStore,
                      builder: (context, _) => Stack(
                        fit: StackFit.expand,
                        children: [
                          if (corners != null)
                            CustomPaint(
                              painter: MapOverlayPainter(
                                projector: PerspectiveProjector(corners),
                                countries: _countries,
                                labelScale: 1 / _currentZoom,
                                l10n: l,
                                flags: _flags,
                                activeQuestion: _questionStore.activeQuestion,
                                selectedCode: _selected,
                                floatingNames: true,
                                detailLevel: detailLevel,
                                isCloseUp: _currentZoom >= 2.5,
                              ),
                            ),
                          if (_debug)
                            CustomPaint(
                              painter: _DebugPainter(_debugQuads, _debugIds),
                            ),
                          if (corners == null)
                            Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 44),
                                child: Chip(label: Text(l.liveSearching)),
                              ),
                            ),
                          if (_debug)
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                color: Colors.black54,
                                child: Text(
                                  l.liveDebugStats(_debugIds.length, _lastMs),
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: selectedCountry != null
                ? 155
                : (_isBarCollapsed ? 20 : 74),
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final z in [1.0, 2.0, 3.0])
                      if (z <= _maxZoom)
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _setZoom(z),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (_currentZoom - z).abs() < 0.2
                                  ? Colors.white24
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${z.toInt()}x',
                              style: TextStyle(
                                color: (_currentZoom - z).abs() < 0.2
                                    ? Colors.amberAccent
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
          if (selectedCountry != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 74,
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
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: QuestionBar(
                store: _questionStore,
                countries: _countries,
                initiallyCollapsed: _questionStore.activeQuestion != null,
                onCollapsedChanged: (collapsed) {
                  setState(() => _isBarCollapsed = collapsed);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TrackingResult? _trackJob((MarkerTracker, Uint8List, int, int) job) =>
    job.$1.track(job.$2, job.$3, job.$4);

class _DebugPainter extends CustomPainter {
  _DebugPainter(this.quads, this.ids);
  final List<List<Offset>> quads;
  final List<int> ids;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.greenAccent;
    for (var i = 0; i < quads.length; i++) {
      final q = quads[i];
      canvas
        ..drawPath(Path()..addPolygon(q, true), stroke)
        ..drawCircle(q[0], 4, Paint()..color = Colors.redAccent);
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: '${ids[i]}',
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      )..layout();
      tp
        ..paint(canvas, q[0] + const Offset(2, -14))
        ..dispose();
    }
  }

  @override
  bool shouldRepaint(_DebugPainter old) =>
      old.quads != quads || old.ids != ids;
}
