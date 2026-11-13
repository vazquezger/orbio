import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/geometry/homography.dart';
import '../../core/geometry/map_projection.dart';

/// Persisted record of the last successfully calibrated map snapshot.
class SavedCalibration {
  const SavedCalibration({
    required this.imagePath,
    required this.corners,
    required this.timestamp,
    this.projectionType = MapProjectionType.equirectangular,
  });

  final String imagePath;
  final List<Offset> corners;
  final DateTime timestamp;
  final MapProjectionType projectionType;

  Map<String, dynamic> toJson() => {
        'imagePath': imagePath,
        'corners': [
          for (final c in corners) {'dx': c.dx, 'dy': c.dy},
        ],
        'timestamp': timestamp.toIso8601String(),
        'projectionType': projectionType.name,
      };

  factory SavedCalibration.fromJson(Map<String, dynamic> json) {
    final rawCorners =
        (json['corners'] as List<dynamic>).cast<Map<String, dynamic>>();
    final projStr = json['projectionType'] as String?;
    final proj = projStr != null
        ? MapProjectionType.values.firstWhere(
            (e) => e.name == projStr,
            orElse: () => MapProjectionType.equirectangular,
          )
        : MapProjectionType.equirectangular;
    return SavedCalibration(
      imagePath: json['imagePath'] as String,
      corners: [
        for (final m in rawCorners)
          Offset((m['dx'] as num).toDouble(), (m['dy'] as num).toDouble()),
      ],
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      projectionType: proj,
    );
  }
}

/// Stores snapshots (captured or imported stills) in the app's private documents directory.
class SnapshotStore {
  SnapshotStore({Future<Directory> Function()? directoryProvider})
      : _dirProvider = directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _dirProvider;
  static const printableCanvasAsset = 'assets/maps/orbio_printable_canvas.svg';

  Future<Directory> _snapshotsDir() async {
    final docs = await _dirProvider();
    final dir = Directory(p.join(docs.path, 'orbio', 'snapshots'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _calibrationFile() async {
    final docs = await _dirProvider();
    final dir = Directory(p.join(docs.path, 'orbio'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return File(p.join(dir.path, 'last_calibration.json'));
  }

  /// Saves the last confirmed calibration so Explore can be resumed later.
  Future<void> saveLastCalibration(
    String imagePath,
    List<Offset> corners, {
    MapProjectionType projectionType = MapProjectionType.equirectangular,
  }) async {
    try {
      final file = await _calibrationFile();
      final cal = SavedCalibration(
        imagePath: imagePath,
        corners: corners,
        timestamp: DateTime.now(),
        projectionType: projectionType,
      );
      await file.writeAsString(jsonEncode(cal.toJson()), flush: true);
    } catch (_) {}
  }

  /// Loads the last confirmed calibration, or null if missing/deleted.
  Future<SavedCalibration?> loadLastCalibration() async {
    try {
      final file = await _calibrationFile();
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final cal = SavedCalibration.fromJson(raw);
      if (!await File(cal.imagePath).exists()) {
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }
      return cal;
    } catch (_) {
      return null;
    }
  }

  /// Removes the persisted last calibration.
  Future<void> clearLastCalibration() async {
    try {
      final file = await _calibrationFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Decodes an image file into a [ui.Image].
  static Future<ui.Image> decodeImageFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  /// Copies a camera still into app storage and returns the new path.
  Future<String> saveSnapshot(String sourcePath) async {
    final dir = await _snapshotsDir();
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final target = p.join(dir.path, 'snapshot_${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(sourcePath).copy(target);
    return target;
  }

  /// Renders the bundled printable map as if photographed at an angle on a
  /// table. Used on devices without a camera and for trying out calibration.
  Future<String> createDemoSnapshot() async {
    const outW = 2400, outH = 1600;
    final info = await vg.loadPicture(const SvgAssetLoader(printableCanvasAsset), null);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final full = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
      canvas.drawRect(
        full,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFF8A7563), Color(0xFF4E4036)],
            radius: 0.9,
          ).createShader(full),
      );

      final w = info.size.width, h = info.size.height;
      final perspective = Homography.fromCorrespondences(
        [Offset.zero, Offset(w, 0), Offset(w, h), Offset(0, h)],
        const [
          Offset(330, 360),
          Offset(2090, 290),
          Offset(2180, 1290),
          Offset(240, 1340),
        ],
      );
      canvas
        ..save()
        ..transform(perspective.toMatrix4().storage)
        ..drawRect(
          Rect.fromLTWH(-14, -14, w + 28, h + 28),
          Paint()..color = const Color(0xFFFAFAF7),
        )
        ..drawPicture(info.picture)
        ..restore();

      final image = await recorder.endRecording().toImage(outW, outH);
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) throw StateError('PNG encoding failed');
        final dir = await _snapshotsDir();
        final path = p.join(dir.path, 'demo_${DateTime.now().millisecondsSinceEpoch}.png');
        await File(path).writeAsBytes(png.buffer.asUint8List(), flush: true);
        return path;
      } finally {
        image.dispose();
      }
    } finally {
      info.picture.dispose();
    }
  }
}
