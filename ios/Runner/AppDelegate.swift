import AVFoundation
import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var speechChannel: FlutterMethodChannel?
  private let audioEngine = AVAudioEngine()
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(name: "orbio/speech", binaryMessenger: messenger)
    speechChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "start":
        let args = call.arguments as? [String: Any]
        let localeId = (args?["locale"] as? String) ?? "es-AR"
        self.startSpeech(localeId: localeId, result: result)
      case "stop":
        self.stopSpeech()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startSpeech(localeId: String, result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { [weak self] status in
      DispatchQueue.main.async {
        guard let self = self, status == .authorized else {
          result(false)
          return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          DispatchQueue.main.async {
            guard granted else {
              result(false)
              return
            }
            let started = self.beginRecording(localeId: localeId)
            result(started)
          }
        }
      }
    }
  }

  /// Resolves a short language code like "es" or "en" to a full locale
  /// identifier supported by `SFSpeechRecognizer` (which requires a region,
  /// e.g. "es-AR", "es-ES", "en-US").
  private func resolveRecognizer(for requested: String) -> SFSpeechRecognizer? {
    let normalized = requested.replacingOccurrences(of: "_", with: "-")
    if let exact = SFSpeechRecognizer(locale: Locale(identifier: normalized)) {
      return exact
    }
    let langPrefix = normalized.split(separator: "-").first.map(String.init)?.lowercased() ?? "es"
    let fallbacks: [String] =
      langPrefix == "es"
      ? ["es-AR", "es-419", "es-MX", "es-ES", "es-US"]
      : ["en-US", "en-GB", "en-AU"]
    for candidate in fallbacks {
      if let rec = SFSpeechRecognizer(locale: Locale(identifier: candidate)) {
        return rec
      }
    }
    if let match = SFSpeechRecognizer.supportedLocales().first(where: {
      $0.identifier.lowercased().hasPrefix(langPrefix)
    }) {
      return SFSpeechRecognizer(locale: match)
    }
    return SFSpeechRecognizer()
  }

  private func beginRecording(localeId: String) -> Bool {
    cleanupAudio()
    guard let recognizer = resolveRecognizer(for: localeId), recognizer.isAvailable else {
      return false
    }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playAndRecord,
        mode: .measurement,
        options: [.defaultToSpeaker, .allowBluetooth]
      )
      try session.setActive(true, options: .notifyOthersOnDeactivation)

      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true
      recognitionRequest = request

      let inputNode = audioEngine.inputNode
      let format = inputNode.outputFormat(forBus: 0)
      inputNode.removeTap(onBus: 0)
      inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
        self?.recognitionRequest?.append(buffer)
      }

      audioEngine.prepare()
      try audioEngine.start()

      recognitionTask = recognizer.recognitionTask(with: request) { [weak self] res, err in
        guard let self = self else { return }
        if let res = res {
          let text = res.bestTranscription.formattedString
          let isFinal = res.isFinal
          DispatchQueue.main.async {
            self.speechChannel?.invokeMethod(
              "onSpeechResult",
              arguments: ["text": text, "isFinal": isFinal]
            )
          }
          if isFinal {
            DispatchQueue.main.async { self.stopSpeech() }
          }
        } else if err != nil {
          DispatchQueue.main.async { self.stopSpeech() }
        }
      }
      return true
    } catch {
      stopSpeech()
      return false
    }
  }

  private func cleanupAudio() {
    if audioEngine.isRunning {
      audioEngine.stop()
      audioEngine.inputNode.removeTap(onBus: 0)
    }
    recognitionRequest?.endAudio()
    recognitionRequest = nil
    recognitionTask?.cancel()
    recognitionTask = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func stopSpeech() {
    cleanupAudio()
    speechChannel?.invokeMethod("onSpeechStopped", arguments: nil)
  }
}
