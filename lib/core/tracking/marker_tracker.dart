import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import '../geometry/homography.dart';
import 'aruco_detector.dart';

/// Where each printed marker sits on the canvas, in normalized map space.
class MarkerLayout {
  const MarkerLayout(this.cornersById);

  /// Parses `assets/maps/canvas_markers.json` (written by
  /// tool/generate_canvas.py).
  factory MarkerLayout.fromJson(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return MarkerLayout({
      for (final m in (json['markers'] as List<dynamic>).cast<Map<String, dynamic>>())
        m['id'] as int: [
          for (final c in (m['corners'] as List<dynamic>).cast<List<dynamic>>())
            Offset((c[0] as num).toDouble(), (c[1] as num).toDouble()),
        ],
    });
  }

  static const asset = 'assets/maps/canvas_markers.json';

  /// `[TL, TR, BR, BL]` normalized corners per marker id.
  final Map<int, List<Offset>> cornersById;
}

/// Result of tracking one frame.
class TrackingResult {
  const TrackingResult({required this.mapToImage, required this.markers});

  /// Normalized map → image pixels of the analysed frame.
  final Homography mapToImage;

  /// Markers used (only ids present in the layout).
  final List<DetectedMarker> markers;
}

/// Detects canvas markers in a grayscale frame and solves the homography
/// from all their corners at once (least squares). One marker is enough.
class MarkerTracker {
  MarkerTracker(this.layout, {ArucoDetector? detector})
      : detector = detector ?? ArucoDetector();

  final MarkerLayout layout;
  final ArucoDetector detector;

  TrackingResult? track(Uint8List gray, int width, int height) {
    final markers = [
      for (final m in detector.detect(gray, width, height))
        if (layout.cornersById.containsKey(m.id)) m,
    ];
    if (markers.isEmpty) return null;
    final src = <Offset>[], dst = <Offset>[];
    for (final m in markers) {
      src.addAll(layout.cornersById[m.id]!);
      dst.addAll(m.corners);
    }
    try {
      return TrackingResult(
        mapToImage: Homography.fromPoints(src, dst),
        markers: markers,
      );
    } on DegenerateHomographyException {
      return null;
    }
  }
}
