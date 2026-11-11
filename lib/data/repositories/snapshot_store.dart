import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/geometry/homography.dart';

/// Stores snapshots (captured or imported stills) in the app's private documents directory.
class SnapshotStore {
  static const printableCanvasAsset = 'assets/maps/orbio_printable_canvas.svg';

  Future<Directory> _snapshotsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'orbio', 'snapshots'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
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
