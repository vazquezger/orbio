import 'dart:ui' show Offset;

import 'package:vector_math/vector_math_64.dart' show Matrix4;

/// Thrown when four point correspondences do not define a valid homography
/// (e.g. three points are collinear or two points coincide).
class DegenerateHomographyException implements Exception {
  const DegenerateHomographyException(this.message);
  final String message;

  @override
  String toString() => 'DegenerateHomographyException: $message';
}

/// A 3x3 planar homography stored row-major, implemented in pure Dart.
///
/// ```
/// | h0 h1 h2 |   | x |   | x' * w |
/// | h3 h4 h5 | * | y | = | y' * w |
/// | h6 h7 h8 |   | 1 |   |   w    |
/// ```
class Homography {
  Homography._(List<double> values) : _m = List<double>.unmodifiable(values);

  factory Homography.identity() =>
      Homography._(const [1, 0, 0, 0, 1, 0, 0, 0, 1]);

  /// Builds a homography from 9 row-major values.
  factory Homography.fromValues(List<double> values) {
    if (values.length != 9) {
      throw ArgumentError.value(values, 'values', 'Expected 9 entries');
    }
    return Homography._(values);
  }

  /// Solves the homography that maps each `src[i]` onto `dst[i]`.
  ///
  /// Uses the direct linear transform with `h8 = 1`, giving an 8x8 linear
  /// system solved by Gaussian elimination with partial pivoting.
  factory Homography.fromCorrespondences(List<Offset> src, List<Offset> dst) {
    if (src.length != 4 || dst.length != 4) {
      throw ArgumentError('Exactly 4 source and 4 destination points required');
    }
    final a = List<List<double>>.generate(8, (_) => List<double>.filled(9, 0));
    for (var i = 0; i < 4; i++) {
      final x = src[i].dx, y = src[i].dy;
      final u = dst[i].dx, v = dst[i].dy;
      a[2 * i]
        ..[0] = x
        ..[1] = y
        ..[2] = 1
        ..[6] = -u * x
        ..[7] = -u * y
        ..[8] = u;
      a[2 * i + 1]
        ..[3] = x
        ..[4] = y
        ..[5] = 1
        ..[6] = -v * x
        ..[7] = -v * y
        ..[8] = v;
    }
    final h = _solveAugmented(a);
    return Homography._([...h, 1.0]);
  }

  /// Least-squares homography mapping `src[i]` onto `dst[i]` for N ≥ 4
  /// correspondences (e.g. all corners of every detected marker).
  ///
  /// Both point sets are normalized (Hartley: centroid at origin, mean
  /// distance √2) before solving the normal equations, which keeps the
  /// system well conditioned for pixel-scale coordinates.
  factory Homography.fromPoints(List<Offset> src, List<Offset> dst) {
    if (src.length != dst.length || src.length < 4) {
      throw ArgumentError('Need the same number (≥ 4) of source and destination points');
    }
    if (src.length == 4) return Homography.fromCorrespondences(src, dst);
    final ts = _normalizer(src), td = _normalizer(dst);
    final s = [for (final p in src) ts.transform(p)];
    final d = [for (final p in dst) td.transform(p)];

    // Normal equations AᵀA h = Aᵀb, accumulated row by row (8 unknowns).
    final ata = List<List<double>>.generate(8, (_) => List<double>.filled(9, 0));
    void addRow(List<double> row, double b) {
      for (var i = 0; i < 8; i++) {
        if (row[i] == 0) continue;
        for (var j = 0; j < 8; j++) {
          ata[i][j] += row[i] * row[j];
        }
        ata[i][8] += row[i] * b;
      }
    }

    for (var i = 0; i < s.length; i++) {
      final x = s[i].dx, y = s[i].dy, u = d[i].dx, v = d[i].dy;
      addRow([x, y, 1, 0, 0, 0, -u * x, -u * y], u);
      addRow([0, 0, 0, x, y, 1, -v * x, -v * y], v);
    }
    final hn = Homography._([..._solveAugmented(ata), 1.0]);
    return td.inverse().compose(hn).compose(ts)._normalized();
  }

  /// Similarity transform moving [pts] to centroid 0 and mean distance √2.
  static Homography _normalizer(List<Offset> pts) {
    var cx = 0.0, cy = 0.0;
    for (final p in pts) {
      cx += p.dx;
      cy += p.dy;
    }
    cx /= pts.length;
    cy /= pts.length;
    var mean = 0.0;
    for (final p in pts) {
      mean += (p - Offset(cx, cy)).distance;
    }
    mean /= pts.length;
    if (mean < 1e-12) {
      throw const DegenerateHomographyException('All points coincide');
    }
    final k = 1.4142135623730951 / mean;
    return Homography._([k, 0, -k * cx, 0, k, -k * cy, 0, 0, 1]);
  }

  Homography _normalized() {
    final s = _m[8].abs() > 1e-15 ? _m[8] : 1.0;
    return Homography._([for (final v in _m) v / s]);
  }

  final List<double> _m;

  /// Row-major 3x3 values.
  List<double> get values => _m;

  /// Projects [p] through this homography.
  ///
  /// Returns an offset with NaN components when the point maps to infinity.
  Offset transform(Offset p) {
    final x = p.dx, y = p.dy;
    final w = _m[6] * x + _m[7] * y + _m[8];
    if (w.abs() < 1e-12) return const Offset(double.nan, double.nan);
    return Offset(
      (_m[0] * x + _m[1] * y + _m[2]) / w,
      (_m[3] * x + _m[4] * y + _m[5]) / w,
    );
  }

  double get determinant =>
      _m[0] * (_m[4] * _m[8] - _m[5] * _m[7]) -
      _m[1] * (_m[3] * _m[8] - _m[5] * _m[6]) +
      _m[2] * (_m[3] * _m[7] - _m[4] * _m[6]);

  /// Inverse via the adjugate matrix.
  Homography inverse() {
    final det = determinant;
    if (det.abs() < 1e-15) {
      throw const DegenerateHomographyException('Matrix is not invertible');
    }
    final m = _m;
    final inv = <double>[
      (m[4] * m[8] - m[5] * m[7]) / det,
      (m[2] * m[7] - m[1] * m[8]) / det,
      (m[1] * m[5] - m[2] * m[4]) / det,
      (m[5] * m[6] - m[3] * m[8]) / det,
      (m[0] * m[8] - m[2] * m[6]) / det,
      (m[2] * m[3] - m[0] * m[5]) / det,
      (m[3] * m[7] - m[4] * m[6]) / det,
      (m[1] * m[6] - m[0] * m[7]) / det,
      (m[0] * m[4] - m[1] * m[3]) / det,
    ];
    final s = inv[8].abs() > 1e-15 ? inv[8] : 1.0;
    return Homography._([for (final v in inv) v / s]);
  }

  /// `this ∘ other`: applies [other] first, then this.
  Homography compose(Homography other) {
    final a = _m, b = other._m;
    final r = List<double>.filled(9, 0);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        var sum = 0.0;
        for (var k = 0; k < 3; k++) {
          sum += a[row * 3 + k] * b[k * 3 + col];
        }
        r[row * 3 + col] = sum;
      }
    }
    return Homography._(r);
  }

  /// Embeds the 2D projective transform into a 4x4 matrix usable with
  /// `Canvas.transform` / `Transform` (z passes through untouched).
  Matrix4 toMatrix4() {
    final m = _m;
    // Matrix4 constructor arguments are column-major.
    return Matrix4(
      m[0], m[3], 0, m[6], //
      m[1], m[4], 0, m[7], //
      0, 0, 1, 0, //
      m[2], m[5], 0, m[8], //
    );
  }

  static List<double> _solveAugmented(List<List<double>> a) {
    const n = 8;
    for (var col = 0; col < n; col++) {
      var pivot = col;
      var best = a[col][col].abs();
      for (var r = col + 1; r < n; r++) {
        final v = a[r][col].abs();
        if (v > best) {
          best = v;
          pivot = r;
        }
      }
      if (best < 1e-12) {
        throw const DegenerateHomographyException(
          'Points are degenerate (collinear or coincident)',
        );
      }
      if (pivot != col) {
        final tmp = a[col];
        a[col] = a[pivot];
        a[pivot] = tmp;
      }
      final p = a[col][col];
      for (var r = 0; r < n; r++) {
        if (r == col) continue;
        final f = a[r][col] / p;
        if (f == 0) continue;
        for (var c = col; c <= n; c++) {
          a[r][c] -= f * a[col][c];
        }
      }
    }
    return [for (var i = 0; i < n; i++) a[i][n] / a[i][i]];
  }

  @override
  String toString() => 'Homography(${_m.map((v) => v.toStringAsFixed(6)).join(', ')})';
}
