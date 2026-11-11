import 'package:flutter/material.dart';

import 'data/repositories/snapshot_store.dart';
import 'data/repositories/map_repository.dart';
import 'l10n/app_localizations.dart';
import 'presentation/screens/camera_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(OrbioApp(repository: MapRepository(), snapshotStore: SnapshotStore()));
}

/// Orbio: Camera/Import → Snapshot → Calibrate → Explore.
class OrbioApp extends StatelessWidget {
  const OrbioApp({super.key, required this.repository, required this.snapshotStore});

  final MapRepository repository;
  final SnapshotStore snapshotStore;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1F6FB2));
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F6FB2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: CameraScreen(repository: repository, snapshotStore: snapshotStore),
    );
  }
}
