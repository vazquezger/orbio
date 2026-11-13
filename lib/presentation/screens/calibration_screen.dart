import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/geometry/anchor_detector.dart';
import '../../core/geometry/map_projection.dart';
import '../../core/geometry/perspective_projector.dart';
import '../../data/repositories/map_repository.dart';
import '../../data/repositories/question_store.dart';
import '../../data/repositories/snapshot_store.dart';
import '../l10n_labels.dart';
import '../widgets/magnifier_loupe.dart';
import 'explore_screen.dart';

/// Step 2 (Calibrate): the snapshot with four draggable corner handles
/// `[TL, TR, BR, BL]`.
///
/// Handles are pre-positioned by [AnchorDetector] on the printed anchors; a
/// loupe appears while dragging for pixel-accurate alignment.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({
    super.key,
    required this.imagePath,
    required this.repository,
    this.initialProjectionType = MapProjectionType.equirectangular,
    this.questionStore,
    this.snapshotStore,
  });

  final String imagePath;
  final MapRepository repository;
  final MapProjectionType initialProjectionType;
  final QuestionStore? questionStore;
  final SnapshotStore? snapshotStore;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  static const _labels = ['TL', 'TR', 'BR', 'BL'];
  static const _handleHitSize = 56.0;

  ui.Image? _image;
  Uint8List? _bytes;
  List<Offset> _corners = const [];
  AnchorDetectionResult? _detection;
  bool _detecting = false;
  String? _loadError;
  int? _activeHandle;
  int _detectionRun = 0;
  late MapProjectionType _projectionType = widget.initialProjectionType;

  ui.Size get _imageSize =>
      ui.Size(_image!.width.toDouble(), _image!.height.toDouble());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _bytes = bytes;
        _image = frame.image;
        _corners = defaultCornerHandles(_imageSize);
      });
      await _autoDetect();
    } catch (e) {
      if (mounted) setState(() => _loadError = context.l10n.calibrateLoadFailed('$e'));
    }
  }

  Future<void> _autoDetect() async {
    final bytes = _bytes;
    if (bytes == null || _image == null) return;
    final run = ++_detectionRun;
    setState(() => _detecting = true);
    final result = await AnchorDetector.detect(bytes, _imageSize);
    if (!mounted || run != _detectionRun) return;
    setState(() {
      _detecting = false;
      _detection = result;
      // Don't yank a handle out from under the user's finger.
      _corners = [
        for (var i = 0; i < 4; i++) i == _activeHandle ? _corners[i] : result.points[i],
      ];
    });
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(switch (result.detectedCount) {
        4 => l.calibrateFoundAll,
        0 => l.calibrateFoundNone,
        final n => l.calibrateFoundSome(n),
      }),
    ));
  }

  void _resetAnchors() {
    if (_image == null) return;
    _detectionRun++; // cancel any in-flight detection
    setState(() {
      _detecting = false;
      _detection = null;
      _corners = defaultCornerHandles(_imageSize);
    });
  }

  void _confirm() {
    final image = _image;
    if (image == null) return;
    if (!isConvexQuad(_corners)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.calibrateCrossed),
      ));
      return;
    }
    widget.snapshotStore?.saveLastCalibration(
      widget.imagePath,
      _corners,
      projectionType: _projectionType,
    );
    final projection = switch (_projectionType) {
      MapProjectionType.equirectangular => MapProjection.equirectangular,
      MapProjectionType.mercatorSchool => MapProjection.mercatorSchool,
      MapProjectionType.mercatorStandard => MapProjection.mercatorStandard,
    };
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ExploreScreen(
        image: image.clone(),
        corners: List.of(_corners),
        repository: widget.repository,
        projection: projection,
        questionStore: widget.questionStore,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.l10n.calibrateTitle),
        backgroundColor: Colors.black45,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.l10n.calibrateConfirmTooltip,
            onPressed: image == null ? null : _confirm,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _loadError != null
          ? Center(child: Text(_loadError!, style: const TextStyle(color: Colors.white)))
          : image == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCanvas(image),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: SafeArea(
                        top: false,
                        child: AnimatedOpacity(
                          opacity: _activeHandle != null ? 0.05 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: IgnorePointer(
                            ignoring: _activeHandle != null,
                            child: _buildToolbar(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCanvas(ui.Image image) {
    return LayoutBuilder(builder: (context, box) {
      final iw = image.width.toDouble(), ih = image.height.toDouble();
      final scale = math.min(box.maxWidth / iw, box.maxHeight / ih);
      final origin = Offset(
        (box.maxWidth - iw * scale) / 2,
        (box.maxHeight - ih * scale) / 2,
      );
      Offset toScreen(Offset p) => origin + p * scale;

      final active = _activeHandle;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: origin.dx,
            top: origin.dy,
            width: iw * scale,
            height: ih * scale,
            child: RawImage(image: image, fit: BoxFit.fill),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _QuadPainter(
                  points: [for (final c in _corners) toScreen(c)],
                  labels: _labels,
                  detected: _detection?.detected,
                  activeIndex: active,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          for (var i = 0; i < 4; i++)
            Positioned(
              left: toScreen(_corners[i]).dx - _handleHitSize / 2,
              top: toScreen(_corners[i]).dy - _handleHitSize / 2,
              width: _handleHitSize,
              height: _handleHitSize,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => setState(() => _activeHandle = i),
                onPanUpdate: (d) => setState(() {
                  final next = _corners[i] + d.delta / scale;
                  _corners = List.of(_corners)
                    ..[i] = Offset(next.dx.clamp(0, iw), next.dy.clamp(0, ih));
                }),
                onPanEnd: (_) => setState(() => _activeHandle = null),
                onPanCancel: () => setState(() => _activeHandle = null),
                child: Semantics(
                  label: context.l10n.cornerHandleSemantics(_labels[i]),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          if (active != null) _buildLoupe(image, toScreen(_corners[active]), scale, box),
          if (_detecting)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Chip(
                  avatar: const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  label: Text(context.l10n.calibrateDetecting),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildLoupe(ui.Image image, Offset handleScreen, double scale, BoxConstraints box) {
    const d = 132.0, lift = 96.0;
    // Show above the finger; flip below when too close to the top edge.
    var top = handleScreen.dy - lift - d;
    if (top < 4) top = handleScreen.dy + lift;
    final left = (handleScreen.dx - d / 2).clamp(4.0, math.max(4.0, box.maxWidth - d - 4)).toDouble();
    final p = _corners[_activeHandle!];
    return Positioned(
      left: left,
      top: top,
      child: MagnifierLoupe(
        image: image,
        imagePoint: p,
        displayScale: scale,
        diameter: d,
        label: '${_labels[_activeHandle!]}  ${p.dx.toStringAsFixed(1)}, ${p.dy.toStringAsFixed(1)}',
      ),
    );
  }

  Widget _buildToolbar() {
    final det = _detection;
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        return Material(
          color: const Color(0xEB1C1C1C),
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: isLandscape
                ? Row(
                    children: [
                      SegmentedButton<MapProjectionType>(
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        segments: [
                          ButtonSegment(
                            value: MapProjectionType.equirectangular,
                            label: Text(l.projectionOrbioCanvas),
                            icon: const Icon(Icons.crop_original, size: 16),
                          ),
                          ButtonSegment(
                            value: MapProjectionType.mercatorSchool,
                            label: Text(l.projectionSchoolMap),
                            icon: const Icon(Icons.school, size: 16),
                          ),
                        ],
                        selected: {_projectionType},
                        onSelectionChanged: (set) {
                          setState(() => _projectionType = set.first);
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          det == null
                              ? l.calibrateHint
                              : l.calibrateDetectedStatus(det.detectedCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _detecting ? null : _resetAnchors,
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: Text(l.calibrateReset),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton.icon(
                        onPressed: _detecting ? null : _autoDetect,
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: Text(l.calibrateAutoDetect),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _confirm,
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text(l.calibrateExplore),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SegmentedButton<MapProjectionType>(
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          segments: [
                            ButtonSegment(
                              value: MapProjectionType.equirectangular,
                              label: Text(l.projectionOrbioCanvas),
                              icon: const Icon(Icons.crop_original, size: 16),
                            ),
                            ButtonSegment(
                              value: MapProjectionType.mercatorSchool,
                              label: Text(l.projectionSchoolMap),
                              icon: const Icon(Icons.school, size: 16),
                            ),
                          ],
                          selected: {_projectionType},
                          onSelectionChanged: (set) {
                            setState(() => _projectionType = set.first);
                          },
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            det == null
                                ? l.calibrateHint
                                : l.calibrateDetectedStatus(det.detectedCount),
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: _detecting ? null : _resetAnchors,
                                icon: const Icon(Icons.restart_alt, size: 18),
                                label: Text(l.calibrateReset),
                              ),
                              const SizedBox(width: 4),
                              OutlinedButton.icon(
                                onPressed: _detecting ? null : _autoDetect,
                                icon: const Icon(Icons.auto_fix_high, size: 18),
                                label: Text(l.calibrateAutoDetect),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: _confirm,
                                icon: const Icon(Icons.map_outlined, size: 18),
                                label: Text(l.calibrateExplore),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _QuadPainter extends CustomPainter {
  _QuadPainter({
    required this.points,
    required this.labels,
    required this.detected,
    required this.activeIndex,
    required this.color,
  });

  final List<Offset> points;
  final List<String> labels;
  final List<bool>? detected;
  final int? activeIndex;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length != 4) return;
    final valid = isConvexQuad(points);
    final edge = valid ? color : Colors.redAccent;
    canvas
      ..drawPath(
        Path()..addPolygon(points, true),
        Paint()..color = edge.withValues(alpha: 0.12),
      )
      ..drawPath(
        Path()..addPolygon(points, true),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = edge,
      );

    for (var i = 0; i < 4; i++) {
      final p = points[i];
      final isActive = i == activeIndex;
      final wasDetected = detected?[i] ?? false;
      final ringColor = wasDetected ? Colors.greenAccent : Colors.amberAccent;
      // Hollow ring + fine crosshair so the target stays visible under the handle.
      canvas
        ..drawCircle(
          p,
          isActive ? 20 : 16,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.black54,
        )
        ..drawCircle(
          p,
          isActive ? 20 : 16,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = ringColor,
        );
      final cross = Paint()
        ..color = ringColor
        ..strokeWidth = 1;
      canvas
        ..drawLine(p - const Offset(8, 0), p - const Offset(3, 0), cross)
        ..drawLine(p + const Offset(3, 0), p + const Offset(8, 0), cross)
        ..drawLine(p - const Offset(0, 8), p - const Offset(0, 3), cross)
        ..drawLine(p + const Offset(0, 3), p + const Offset(0, 8), cross);

      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800),
        ),
      )..layout();
      // Put the tag outside the quad, diagonally away from the centre.
      final centre = points.reduce((a, b) => a + b) / 4;
      final dir = p - centre;
      final unit = dir.distance == 0 ? Offset.zero : dir / dir.distance;
      final tagCenter = p + unit * 32;
      final rect = Rect.fromCenter(center: tagCenter, width: tp.width + 10, height: tp.height + 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = ringColor,
      );
      tp
        ..paint(canvas, rect.topLeft + const Offset(5, 2))
        ..dispose();
    }
  }

  @override
  bool shouldRepaint(_QuadPainter old) => true;
}
