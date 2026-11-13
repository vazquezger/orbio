import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// On-device speech-to-text bridge (`orbio/speech`).
///
/// Uses Apple's `SFSpeechRecognizer` on iOS with zero external plugins, and
/// degrades gracefully on platforms without a microphone/speech recognizer.
class SpeechService {
  SpeechService() {
    _channel.setMethodCallHandler(_handleCall);
  }

  static const _channel = MethodChannel('orbio/speech');

  ValueChanged<String>? _onResult;
  ValueChanged<bool>? _onState;
  bool _listening = false;

  bool get isListening => _listening;

  Future<bool> start({
    required String localeId,
    required ValueChanged<String> onResult,
    required ValueChanged<bool> onListeningChanged,
  }) async {
    _onResult = onResult;
    _onState = onListeningChanged;
    try {
      final ok = await _channel.invokeMethod<bool>('start', {'locale': localeId});
      _setListening(ok ?? false);
      return _listening;
    } on MissingPluginException {
      _setListening(false);
      return false;
    } on PlatformException catch (e) {
      debugPrint('Speech start failed: $e');
      _setListening(false);
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // Ignore if not supported.
    } finally {
      _setListening(false);
    }
  }

  Future<void> _handleCall(MethodCall call) async {
    if (call.method == 'onSpeechResult') {
      final args = call.arguments as Map<dynamic, dynamic>?;
      final text = args?['text'] as String? ?? '';
      final isFinal = args?['isFinal'] as bool? ?? false;
      if (text.isNotEmpty) _onResult?.call(text);
      if (isFinal) _setListening(false);
    } else if (call.method == 'onSpeechStopped') {
      _setListening(false);
    }
  }

  void _setListening(bool value) {
    if (_listening == value) return;
    _listening = value;
    _onState?.call(value);
  }
}

