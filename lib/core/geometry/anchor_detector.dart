import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'perspective_projector.dart';

/// Detects the four bullseye calibration anchors of the printable Orbio map
/// (`assets/maps/orbio_printable_canvas.svg`) in a captured still.
///
/// Returns points in image pixel space ordered `[TL, TR, BR, BL]`. Any corner
/// that cannot be found with reasonable confidence falls back to a 10% inset
/// default point; if the resulting quad is not a sane convex shape, all four
/// corners fall back.
Future<List<Offset>> detectAnchorPoints(
  Uint8List imageBytes,
  ui.Size imageSize,
) async =>
    (await AnchorDetector.detect(imageBytes, imageSize)).points;

/// Outcome of an anchor detection pass.
class AnchorDetectionResult {
  const AnchorDetectionResult({
    required this.points,
    required this.confidences,
    required this.detected,
  });

  factory AnchorDetectionResult.fallback(ui.Size imageSize) =>
      AnchorDetectionResult(
        points: defaultCornerHandles(imageSize),
        confidences: const [0, 0, 0, 0],
        detected: const [false, false, false, false],
      );

  /// `[TL, TR, BR, BL]` in image pixels.
  final List<Offset> points;

  /// Per-corner confidence in `[0, 1]`.
  final List<double> confidences;

  /// Per-corner flag: true when the point came from detection, not fallback.
  final List<bool> detected;

  int get detectedCount => detected.where((d) => d).length;
  bool get isComplete => detectedCount == 4;
}

/// A candidate anchor found in the analysis (downsampled) image.
@immutable
class AnchorCandidate {
  const AnchorCandidate(this.x, this.y, this.score);
  final double x;
  final double y;
  final double score;

  @override
  String toString() =>
      'AnchorCandidate(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, '
      'score: ${score.toStringAsFixed(2)})';
}

class _AnalysisInput {
  const _AnalysisInput(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width;
  final int height;
}

abstract final class AnchorDetector {
  /// Longest side of the image used for analysis.
  static const int analysisMaxDimension = 960;

  /// Minimum score for a corner to count as detected.
  static const double minConfidence = 0.55;

  /// Decodes [imageBytes] (JPEG/PNG), downsamples and scans it on a
  /// background isolate. Never throws: on any failure returns the fallback.
  static Future<AnchorDetectionResult> detect(
    Uint8List imageBytes,
    ui.Size imageSize,
  ) async {
    try {
      final input = await _decodeForAnalysis(imageBytes, imageSize);
      final candidates = await compute(_scanRgba, input);
      return _assemble(
        candidates,
        analysisSize: ui.Size(input.width.toDouble(), input.height.toDouble()),
        imageSize: imageSize,
      );
    } catch (e, st) {
      debugPrint('Anchor detection failed: $e\n$st');
      return AnchorDetectionResult.fallback(imageSize);
    }
  }

  static Future<_AnalysisInput> _decodeForAnalysis(
    Uint8List bytes,
    ui.Size imageSize,
  ) async {
    final landscape = imageSize.width >= imageSize.height;
    final longest = math.max(imageSize.width, imageSize.height);
    final target = math.min(analysisMaxDimension, longest.round());
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: landscape ? target : null,
      targetHeight: landscape ? null : target,
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) throw StateError('Could not read pixels');
        return _AnalysisInput(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          image.width,
          image.height,
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  static List<AnchorCandidate?> _scanRgba(_AnalysisInput input) {
    final n = input.width * input.height;
    final gray = Uint8List(n);
    final rgba = input.rgba;
    for (var i = 0, j = 0; i < n; i++, j += 4) {
      gray[i] = (0.299 * rgba[j] + 0.587 * rgba[j + 1] + 0.114 * rgba[j + 2])
          .round();
    }
    return scanGray(gray, input.width, input.height);
  }

  static AnchorDetectionResult _assemble(
    List<AnchorCandidate?> candidates, {
    required ui.Size analysisSize,
    required ui.Size imageSize,
  }) {
    final sx = imageSize.width / analysisSize.width;
    final sy = imageSize.height / analysisSize.height;
    final defaults = defaultCornerHandles(imageSize);
    final points = <Offset>[];
    final confidences = <double>[];
    final detected = <bool>[];
    for (var i = 0; i < 4; i++) {
      final c = candidates[i];
      if (c != null && c.score >= minConfidence) {
        points.add(Offset(c.x * sx, c.y * sy));
        confidences.add(c.score.clamp(0.0, 1.0));
        detected.add(true);
      } else {
        points.add(defaults[i]);
        confidences.add(c?.score.clamp(0.0, 1.0) ?? 0);
        detected.add(false);
      }
    }
    final minArea = imageSize.width * imageSize.height * 0.05;
    if (!isConvexQuad(points) || polygonArea(points) < minArea) {
      return AnchorDetectionResult.fallback(imageSize);
    }
    return AnchorDetectionResult(
      points: points,
      confidences: confidences,
      detected: detected,
    );
  }

  /// Core detector on an 8-bit grayscale buffer (row-major, [w] x [h]).
  ///
  /// Returns the best candidate per quadrant `[TL, TR, BR, BL]` (in buffer
  /// pixel coordinates, sub-pixel), or null when a quadrant has none.
  ///
  /// Pipeline:
  /// 1. Adaptive (local-mean) threshold → dark mask + per-pixel darkness.
  /// 2. 4-connected components on the dark mask.
  /// 3. Shape filter: compact, roughly square bbox, not touching the border.
  /// 4. Bullseye check: dark centre, bright inner ring, dark outer ring,
  ///    sampled along the diagonals (avoids the crosshair lines).
  /// 5. Score = shape/symmetry/bullseye, weighted by closeness to the
  ///    quadrant's outer image corner; keep the best per quadrant.
  static List<AnchorCandidate?> scanGray(Uint8List gray, int w, int h) {
    if (w < 16 || h < 16) return List.filled(4, null);

    // 1. Integral image for O(1) local means.
    final stride = w + 1;
    final integral = Float64List(stride * (h + 1));
    for (var y = 0; y < h; y++) {
      var rowSum = 0.0;
      for (var x = 0; x < w; x++) {
        rowSum += gray[y * w + x];
        integral[(y + 1) * stride + x + 1] = integral[y * stride + x + 1] + rowSum;
      }
    }
    double localMean(int cx, int cy, int half) {
      final x0 = math.max(0, cx - half), y0 = math.max(0, cy - half);
      final x1 = math.min(w - 1, cx + half), y1 = math.min(h - 1, cy + half);
      final sum = integral[(y1 + 1) * stride + x1 + 1] -
          integral[y0 * stride + x1 + 1] -
          integral[(y1 + 1) * stride + x0] +
          integral[y0 * stride + x0];
      return sum / ((x1 - x0 + 1) * (y1 - y0 + 1));
    }

    final half = math.max(4, math.min(w, h) ~/ 20);
    final darkness = Float32List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final mean = localMean(x, y, half);
        final g = gray[i];
        final diff = mean - g;
        if (diff > 18 && g < mean * 0.80) darkness[i] = diff;
      }
    }

    // 2. Connected components (iterative flood fill).
    final visited = Uint8List(w * h);
    final stack = Int32List(w * h);
    final maxSide = math.min(w, h) * 0.18;
    final best = List<AnchorCandidate?>.filled(4, null);
    final halfDiag = math.sqrt(w * w + h * h) / 2;

    for (var start = 0; start < w * h; start++) {
      if (darkness[start] == 0 || visited[start] == 1) continue;
      var sp = 0;
      stack[sp++] = start;
      visited[start] = 1;
      var area = 0;
      var wSum = 0.0, wx = 0.0, wy = 0.0;
      var minX = w, minY = h, maxX = 0, maxY = 0;
      var touchesBorder = false;
      while (sp > 0) {
        final p = stack[--sp];
        final px = p % w, py = p ~/ w;
        area++;
        final d = darkness[p];
        wSum += d;
        wx += d * (px + 0.5);
        wy += d * (py + 0.5);
        if (px < minX) minX = px;
        if (px > maxX) maxX = px;
        if (py < minY) minY = py;
        if (py > maxY) maxY = py;
        if (px == 0 || py == 0 || px == w - 1 || py == h - 1) {
          touchesBorder = true;
        }
        if (px > 0) {
          final q = p - 1;
          if (darkness[q] > 0 && visited[q] == 0) {
            visited[q] = 1;
            stack[sp++] = q;
          }
        }
        if (px < w - 1) {
          final q = p + 1;
          if (darkness[q] > 0 && visited[q] == 0) {
            visited[q] = 1;
            stack[sp++] = q;
          }
        }
        if (py > 0) {
          final q = p - w;
          if (darkness[q] > 0 && visited[q] == 0) {
            visited[q] = 1;
            stack[sp++] = q;
          }
        }
        if (py < h - 1) {
          final q = p + w;
          if (darkness[q] > 0 && visited[q] == 0) {
            visited[q] = 1;
            stack[sp++] = q;
          }
        }
      }

      // 3. Shape filter.
      if (touchesBorder || area < 10) continue;
      final bw = maxX - minX + 1, bh = maxY - minY + 1;
      if (bw < 5 || bh < 5 || bw > maxSide || bh > maxSide) continue;
      final aspect = math.max(bw, bh) / math.min(bw, bh);
      if (aspect > 1.6) continue;
      final fill = area / (bw * bh);
      if (fill < 0.2 || fill > 0.95) continue;

      final cx = wx / wSum, cy = wy / wSum;
      final bcx = (minX + maxX + 1) / 2, bcy = (minY + maxY + 1) / 2;
      final symmetry =
          (1 - 4 * math.max((cx - bcx).abs() / bw, (cy - bcy).abs() / bh))
              .clamp(0.0, 1.0);
      final shape = (1 - (aspect - 1) / 0.6 * 0.5).clamp(0.0, 1.0);

      // 4. Bullseye profile along the diagonals.
      final r = (bw + bh) / 4;
      double sampleRing(double radiusFactor) {
        var sum = 0.0;
        var count = 0;
        final rr = r * radiusFactor / math.sqrt2;
        for (final (sx, sy) in const [(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
          final x = (cx + sx * rr).floor(), y = (cy + sy * rr).floor();
          if (x < 0 || y < 0 || x >= w || y >= h) continue;
          sum += gray[y * w + x];
          count++;
        }
        return count == 0 ? 255 : sum / count;
      }

      final centre = gray[cy.floor().clamp(0, h - 1) * w + cx.floor().clamp(0, w - 1)]
          .toDouble();
      final gap = [0.38, 0.48, 0.58].map(sampleRing).reduce(math.max);
      final outer = [0.78, 0.86, 0.94].map(sampleRing).reduce(math.min);
      final bg = localMean(cx.floor(), cy.floor(), math.max(half, (r * 2).ceil()));
      final contrastRef = math.max(30.0, bg * 0.5);
      final bullseye = ((gap - centre) / contrastRef).clamp(0.0, 1.0) *
          ((gap - outer) / contrastRef).clamp(0.0, 1.0);

      // 5. Score and corner proximity.
      final q = cy < h / 2 ? (cx < w / 2 ? 0 : 1) : (cx < w / 2 ? 3 : 2);
      final corner = switch (q) {
        0 => (0.0, 0.0),
        1 => (w.toDouble(), 0.0),
        2 => (w.toDouble(), h.toDouble()),
        _ => (0.0, h.toDouble()),
      };
      final dist = math.sqrt(math.pow(cx - corner.$1, 2) + math.pow(cy - corner.$2, 2));
      final proximity = 1 - 0.3 * (dist / halfDiag).clamp(0.0, 1.0);
      final score = (0.3 * shape + 0.15 * symmetry + 0.55 * bullseye) * proximity;

      final current = best[q];
      if (current == null || score > current.score) {
        best[q] = AnchorCandidate(cx, cy, score);
      }
    }
    return best;
  }
}
