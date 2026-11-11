import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/snapshot_store.dart';
import '../../data/repositories/map_repository.dart';
import '../l10n_labels.dart';
import 'calibration_screen.dart';

/// Step 1: live top-down preview to take a snapshot of the canvas, or import
/// an existing photo, or use a demo snapshot.
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.repository,
    required this.snapshotStore,
  });

  final MapRepository repository;
  final SnapshotStore snapshotStore;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      if (controller == null || !controller.value.isInitialized) return;
      _controller = null;
      controller.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = context.l10n.cameraNotFound);
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.max,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off).catchError((_) {});
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = _describe(e));
    } catch (e) {
      // e.g. MissingPluginException on platforms without a camera plugin.
      if (mounted) setState(() => _error = context.l10n.cameraUnavailable);
    }
  }

  String _describe(CameraException e) => switch (e.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' =>
          context.l10n.cameraAccessDenied,
        _ => context.l10n.cameraError(e.description ?? e.code),
      };

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _busy || controller.value.isTakingPicture) return;
    setState(() => _busy = true);
    try {
      final shot = await controller.takePicture();
      final path = await widget.snapshotStore.saveSnapshot(shot.path);
      await controller.pausePreview();
      await _openCalibration(path);
      if (mounted && _controller == controller) await controller.resumePreview();
    } on CameraException catch (e) {
      _snack(_describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useDemo() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await widget.snapshotStore.createDemoSnapshot();
      await _openCalibration(path);
    } catch (e) {
      if (mounted) _snack(context.l10n.cameraDemoFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Imports an existing photo of the map (gallery on mobile, file dialog
  /// on macOS). Keeps the demo and live camera as alternatives.
  Future<void> _importPhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = _controller;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (picked == null) return; // user cancelled
      final path = await widget.snapshotStore.saveSnapshot(picked.path);
      if (controller != null && controller.value.isInitialized) {
        await controller.pausePreview();
      }
      await _openCalibration(path);
      if (mounted && controller != null && _controller == controller) {
        await controller.resumePreview();
      }
    } catch (e) {
      if (mounted) _snack(context.l10n.cameraImportFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCalibration(String path) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalibrationScreen(
          imagePath: path,
          repository: widget.repository,
        ),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.l10n.appTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.l10n.cameraImportTooltip,
            onPressed: _busy ? null : _importPhoto,
            icon: const Icon(Icons.photo_library_outlined),
          ),
          IconButton(
            tooltip: context.l10n.cameraDemoTooltip,
            onPressed: _busy ? null : _useDemo,
            icon: const Icon(Icons.public),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            Center(child: CameraPreview(controller))
          else if (_error != null)
            _Unavailable(
              message: _error!,
              onImport: _busy ? null : _importPhoto,
              onDemo: _busy ? null : _useDemo,
              onRetry: _initCamera,
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (controller != null) const IgnorePointer(child: _FramingGuide()),
          if (_busy) const ColoredBox(color: Colors.black45, child: Center(child: CircularProgressIndicator())),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: controller == null
          ? null
          : FloatingActionButton.large(
              tooltip: context.l10n.cameraCaptureTooltip,
              onPressed: _busy ? null : _capture,
              child: const Icon(Icons.camera_alt),
            ),
    );
  }
}

class _FramingGuide extends StatelessWidget {
  const _FramingGuide();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            context.l10n.cameraFramingHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
        Expanded(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: AspectRatio(
                aspectRatio: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.message,
    required this.onImport,
    required this.onDemo,
    required this.onRetry,
  });
  final String message;
  final VoidCallback? onImport;
  final VoidCallback? onDemo;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(context.l10n.cameraImportButton),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onDemo,
              icon: const Icon(Icons.public),
              label: Text(context.l10n.cameraDemoButton),
            ),
            TextButton(onPressed: onRetry, child: Text(context.l10n.cameraRetryButton)),
          ],
        ),
      ),
    );
  }
}
