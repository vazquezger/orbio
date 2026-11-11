import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import '../geometry/homography.dart';
import 'aruco_dictionary.dart';

/// A marker found in an image.
class DetectedMarker {
  const DetectedMarker(this.id, this.corners);

  /// Dictionary id.
  final int id;

  /// Outer corners of the black border, `[TL, TR, BR, BL]` of the marker as
  /// printed, in image pixels.
  final List<Offset> corners;

  double get perimeter {
    var p = 0.0;
    for (var i = 0; i < 4; i++) {
      p += (corners[(i + 1) % 4] - corners[i]).distance;
    }
    return p;
  }
}

/// Pure-Dart ArUco detector for 4x4 dictionaries (6x6 cells with border).
///
/// Pipeline (same idea as OpenCV's):
/// 1. Adaptive threshold (local mean via integral image).
/// 2. 8-connected dark components; outer boundary by Moore tracing.
/// 3. Douglas–Peucker → convex quadrilaterals.
/// 4. Sub-pixel corners by fitting a line to each side and intersecting.
/// 5. Unwarp the quad to a 6x6 grid, read cells, check the black border and
///    match the inner 4x4 code (any of 4 rotations, ≤ 1 bit error).
class ArucoDetector {
  ArucoDetector({this.codes = kAruco4x4x50, this.maxBitErrors = 1});

  /// Dictionary codes; the index is the marker id.
  final List<int> codes;
  final int maxBitErrors;

  static const _cells = 6;

  List<DetectedMarker> detect(Uint8List gray, int width, int height) {
    final w = width, h = height;
    if (w < 20 || h < 20) return const [];

    // 1. Adaptive threshold.
    final stride = w + 1;
    final integral = Int32List(stride * (h + 1));
    for (var y = 0; y < h; y++) {
      var row = 0;
      for (var x = 0; x < w; x++) {
        row += gray[y * w + x];
        integral[(y + 1) * stride + x + 1] = integral[y * stride + x + 1] + row;
      }
    }
    final half = (math.min(w, h) ~/ 30).clamp(4, 25);
    final dark = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      final y0 = math.max(0, y - half), y1 = math.min(h - 1, y + half);
      for (var x = 0; x < w; x++) {
        final x0 = math.max(0, x - half), x1 = math.min(w - 1, x + half);
        final sum = integral[(y1 + 1) * stride + x1 + 1] -
            integral[y0 * stride + x1 + 1] -
            integral[(y1 + 1) * stride + x0] +
            integral[y0 * stride + x0];
        final mean = sum / ((x1 - x0 + 1) * (y1 - y0 + 1));
        if (gray[y * w + x] < mean - 7) dark[y * w + x] = 1;
      }
    }

    // 2. Components → boundary → quads.
    final labels = Int32List(w * h);
    final stack = Int32List(w * h);
    final minSide = 8;
    final maxSide = math.min(w, h) * 0.9;
    final found = <int, DetectedMarker>{};
    var next = 0;
    for (var start = 0; start < w * h; start++) {
      if (dark[start] == 0 || labels[start] != 0) continue;
      final label = ++next;
      var sp = 0;
      stack[sp++] = start;
      labels[start] = label;
      var area = 0;
      var minX = w, minY = h, maxX = 0, maxY = 0;
      var touches = false;
      while (sp > 0) {
        final p = stack[--sp];
        final px = p % w, py = p ~/ w;
        area++;
        if (px < minX) minX = px;
        if (px > maxX) maxX = px;
        if (py < minY) minY = py;
        if (py > maxY) maxY = py;
        if (px == 0 || py == 0 || px == w - 1 || py == h - 1) touches = true;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = py + dy;
          if (ny < 0 || ny >= h) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = px + dx;
            if (nx < 0 || nx >= w || (dx == 0 && dy == 0)) continue;
            final q = ny * w + nx;
            if (dark[q] == 1 && labels[q] == 0) {
              labels[q] = label;
              stack[sp++] = q;
            }
          }
        }
      }
      final bw = maxX - minX + 1, bh = maxY - minY + 1;
      if (touches || bw < minSide || bh < minSide || bw > maxSide || bh > maxSide) continue;
      // A marker's dark part covers a good share of its bounding box.
      if (area < bw * bh * 0.25) continue;

      final contour = _traceBoundary(labels, w, h, start, label);
      if (contour.length < 4 * minSide) continue;
      final quad = _approxQuad(contour);
      if (quad == null) continue;
      final refined = _refineCorners(contour, quad) ?? [for (final i in quad) contour[i]];
      final marker = _decode(gray, w, h, refined);
      if (marker == null) continue;
      final prev = found[marker.id];
      if (prev == null || marker.perimeter > prev.perimeter) found[marker.id] = marker;
    }
    return found.values.toList(growable: false);
  }

  /// Moore-neighbour tracing of the outer boundary, starting at [start]
  /// (the first pixel of the component in raster order).
  static List<Offset> _traceBoundary(Int32List labels, int w, int h, int start, int label) {
    const dxs = [1, 1, 0, -1, -1, -1, 0, 1];
    const dys = [0, 1, 1, 1, 0, -1, -1, -1];
    bool inside(int x, int y) => x >= 0 && y >= 0 && x < w && y < h && labels[y * w + x] == label;

    final sx = start % w, sy = start ~/ w;
    final pts = <Offset>[];
    var x = sx, y = sy;
    var dir = 7; // came from the west/top: start searching from north-west
    final maxSteps = 4 * (w + h) * 4;
    for (var steps = 0; steps < maxSteps; steps++) {
      pts.add(Offset(x + 0.5, y + 0.5));
      var foundNext = false;
      for (var k = 0; k < 8; k++) {
        final d = (dir + 6 + k) % 8; // start left of the previous direction
        final nx = x + dxs[d], ny = y + dys[d];
        if (inside(nx, ny)) {
          x = nx;
          y = ny;
          dir = d;
          foundNext = true;
          break;
        }
      }
      if (!foundNext) break; // isolated pixel
      if (x == sx && y == sy) break;
    }
    return pts;
  }

  /// Douglas–Peucker reduction of a closed contour; returns indices of the
  /// 4 corners (clockwise in image space) or null if it is not a convex quad.
  static List<int>? _approxQuad(List<Offset> c) {
    final n = c.length;
    // Two far-apart points split the closed contour into two chains.
    var a = 0;
    var b = 0;
    var best = 0.0;
    for (var i = 0; i < n; i++) {
      final d = (c[i] - c[0]).distanceSquared;
      if (d > best) {
        best = d;
        b = i;
      }
    }
    best = 0;
    for (var i = 0; i < n; i++) {
      final d = (c[i] - c[b]).distanceSquared;
      if (d > best) {
        best = d;
        a = i;
      }
    }
    var perimeter = 0.0;
    for (var i = 0; i < n; i++) {
      perimeter += (c[(i + 1) % n] - c[i]).distance;
    }
    final eps = math.max(1.5, perimeter * 0.03);

    final keep = <int>{a, b};
    void dp(int i0, int i1) {
      // indices along the closed contour from i0 to i1 (forward)
      final len = (i1 - i0 + n) % n;
      if (len < 2) return;
      final p0 = c[i0], p1 = c[i1];
      final seg = p1 - p0;
      final segLen = seg.distance;
      var maxD = -1.0;
      var maxI = -1;
      for (var k = 1; k < len; k++) {
        final i = (i0 + k) % n;
        final v = c[i] - p0;
        final d = segLen < 1e-9
            ? v.distance
            : (seg.dx * v.dy - seg.dy * v.dx).abs() / segLen;
        if (d > maxD) {
          maxD = d;
          maxI = i;
        }
      }
      if (maxD > eps) {
        keep.add(maxI);
        dp(i0, maxI);
        dp(maxI, i1);
      }
    }

    dp(a, b);
    dp(b, a);
    if (keep.length != 4) return null;
    final idx = keep.toList()..sort();
    final pts = [for (final i in idx) c[i]];
    // Convexity + reasonable side lengths.
    double? sign;
    for (var i = 0; i < 4; i++) {
      final p0 = pts[i], p1 = pts[(i + 1) % 4], p2 = pts[(i + 2) % 4];
      if ((p1 - p0).distance < perimeter * 0.08) return null;
      final cross = (p1.dx - p0.dx) * (p2.dy - p1.dy) - (p1.dy - p0.dy) * (p2.dx - p1.dx);
      if (cross.abs() < 1e-9) return null;
      if (sign == null) {
        sign = cross.sign;
      } else if (cross.sign != sign) {
        return null;
      }
    }
    // Clockwise in image space (y down) = positive shoelace sum.
    var area2 = 0.0;
    for (var i = 0; i < 4; i++) {
      area2 += pts[i].dx * pts[(i + 1) % 4].dy - pts[(i + 1) % 4].dx * pts[i].dy;
    }
    return area2 > 0 ? idx : [idx[0], idx[3], idx[2], idx[1]];
  }

  /// Fits a line to the middle part of each side and intersects neighbours.
  /// Pixel centres sit half a pixel inside the dark border, so each line is
  /// pushed half a pixel outwards to land on the actual edge.
  static List<Offset>? _refineCorners(List<Offset> c, List<int> q) {
    final n = c.length;
    final lines = <(Offset, Offset)>[]; // (point, unit direction)
    final centre = [for (final i in q) c[i]].reduce((a, b) => a + b) / 4;
    for (var s = 0; s < 4; s++) {
      final i0 = q[s], i1 = q[(s + 1) % 4];
      // Walk from i0 to i1 in whichever direction is shorter.
      final fwd = (i1 - i0 + n) % n, back = (i0 - i1 + n) % n;
      final len = math.min(fwd, back);
      final step = fwd <= back ? 1 : -1;
      final pts = <Offset>[];
      final trim = (len * 0.15).ceil();
      for (var k = trim; k <= len - trim; k++) {
        pts.add(c[(i0 + step * k + n) % n]);
      }
      if (pts.length < 3) return null;
      var mx = 0.0, my = 0.0;
      for (final p in pts) {
        mx += p.dx;
        my += p.dy;
      }
      mx /= pts.length;
      my /= pts.length;
      var sxx = 0.0, sxy = 0.0, syy = 0.0;
      for (final p in pts) {
        final dx = p.dx - mx, dy = p.dy - my;
        sxx += dx * dx;
        sxy += dx * dy;
        syy += dy * dy;
      }
      final angle = 0.5 * math.atan2(2 * sxy, sxx - syy);
      final dir = Offset(math.cos(angle), math.sin(angle));
      var point = Offset(mx, my);
      // Normal pointing away from the quad centre.
      var normal = Offset(-dir.dy, dir.dx);
      if ((point - centre).dx * normal.dx + (point - centre).dy * normal.dy < 0) {
        normal = -normal;
      }
      point += normal * 0.5;
      lines.add((point, dir));
    }
    final out = <Offset>[];
    for (var s = 0; s < 4; s++) {
      final (p1, d1) = lines[(s + 3) % 4];
      final (p2, d2) = lines[s];
      final denom = d1.dx * d2.dy - d1.dy * d2.dx;
      if (denom.abs() < 1e-6) return null;
      final t = ((p2.dx - p1.dx) * d2.dy - (p2.dy - p1.dy) * d2.dx) / denom;
      final corner = p1 + d1 * t;
      // Reject wild intersections (refinement should move corners slightly).
      if ((corner - c[q[s]]).distance > 4) return null;
      out.add(corner);
    }
    return out;
  }

  DetectedMarker? _decode(Uint8List gray, int w, int h, List<Offset> quad) {
    final cellValues = Float64List(_cells * _cells);
    final grid = Homography.fromCorrespondences(
      const [Offset(0, 0), Offset(6, 0), Offset(6, 6), Offset(0, 6)],
      quad,
    );
    double sample(double gx, double gy) {
      final p = grid.transform(Offset(gx, gy));
      final x = p.dx - 0.5, y = p.dy - 0.5;
      final x0 = x.floor(), y0 = y.floor();
      if (x0 < 0 || y0 < 0 || x0 + 1 >= w || y0 + 1 >= h) return double.nan;
      final fx = x - x0, fy = y - y0;
      final i = y0 * w + x0;
      return gray[i] * (1 - fx) * (1 - fy) +
          gray[i + 1] * fx * (1 - fy) +
          gray[i + w] * (1 - fx) * fy +
          gray[i + w + 1] * fx * fy;
    }

    var lo = 255.0, hi = 0.0;
    for (var r = 0; r < _cells; r++) {
      for (var col = 0; col < _cells; col++) {
        var sum = 0.0;
        for (final oy in const [0.3, 0.5, 0.7]) {
          for (final ox in const [0.3, 0.5, 0.7]) {
            final v = sample(col + ox, r + oy);
            if (v.isNaN) return null;
            sum += v;
          }
        }
        final v = sum / 9;
        cellValues[r * _cells + col] = v;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    }
    if (hi - lo < 30) return null;
    final threshold = (lo + hi) / 2;
    var borderWhite = 0;
    final bits = List<int>.filled(16, 0);
    for (var r = 0; r < _cells; r++) {
      for (var col = 0; col < _cells; col++) {
        final white = cellValues[r * _cells + col] > threshold;
        final border = r == 0 || col == 0 || r == _cells - 1 || col == _cells - 1;
        if (border) {
          if (white) borderWhite++;
        } else if (white) {
          bits[(r - 1) * 4 + (col - 1)] = 1;
        }
      }
    }
    if (borderWhite > 2) return null;

    // Try the 4 rotations: rotation k means the printed TL is quad[k].
    for (var k = 0; k < 4; k++) {
      final code = _codeForRotation(bits, k);
      final id = _match(code);
      if (id != null) {
        return DetectedMarker(id, [for (var i = 0; i < 4; i++) quad[(k + i) % 4]]);
      }
    }
    return null;
  }

  /// Reads the 4x4 [bits] (grid anchored at quad[0]) as if the grid started
  /// at quad[k] (rotating the grid k quarter turns).
  static int _codeForRotation(List<int> bits, int k) {
    var code = 0;
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        // Map marker-space (r, c) to grid-space for a grid rotated k times
        // clockwise: corner order TL,TR,BR,BL shifts by k.
        int gr = r, gc = c;
        for (var t = 0; t < k; t++) {
          final nr = gc, nc = 3 - gr;
          gr = nr;
          gc = nc;
        }
        code = (code << 1) | bits[gr * 4 + gc];
      }
    }
    return code;
  }

  int? _match(int code) {
    for (var id = 0; id < codes.length; id++) {
      final diff = codes[id] ^ code;
      if (_popCount(diff) <= maxBitErrors) return id;
    }
    return null;
  }

  static int _popCount(int v) {
    var c = 0;
    while (v != 0) {
      v &= v - 1;
      c++;
    }
    return c;
  }
}
