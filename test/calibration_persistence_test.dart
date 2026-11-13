import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbio/core/geometry/map_projection.dart';
import 'package:orbio/data/repositories/snapshot_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SnapshotStore saves, loads and clears last calibration', () async {
    // Create a temporary dummy image file
    final tempDir = Directory.systemTemp.createTempSync('orbio_calib_test_');
    final dummyImg = File('${tempDir.path}/test_map.jpg');
    dummyImg.writeAsStringSync('fake-jpeg-data');
    final store = SnapshotStore(directoryProvider: () async => tempDir);

    try {
      const corners = [
        Offset(10, 20),
        Offset(100, 25),
        Offset(95, 80),
        Offset(15, 85),
      ];

      await store.saveLastCalibration(
        dummyImg.path,
        corners,
        projectionType: MapProjectionType.mercatorSchool,
      );

      final loaded = await store.loadLastCalibration();
      expect(loaded, isNotNull);
      expect(loaded!.imagePath, dummyImg.path);
      expect(loaded.corners.length, 4);
      expect(loaded.corners[0], const Offset(10, 20));
      expect(loaded.corners[1], const Offset(100, 25));
      expect(loaded.projectionType, MapProjectionType.mercatorSchool);

      // Clear
      await store.clearLastCalibration();
      final afterClear = await store.loadLastCalibration();
      expect(afterClear, isNull);

      // If saved file is deleted, loadLastCalibration returns null
      await store.saveLastCalibration(dummyImg.path, corners);
      dummyImg.deleteSync();
      final afterDeletedFile = await store.loadLastCalibration();
      expect(afterDeletedFile, isNull);
    } finally {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    }
  });
}
