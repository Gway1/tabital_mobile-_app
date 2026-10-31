import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    FlutterMethodChannel(name: "com.tabitalpay/permissions", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "camera" else { result(FlutterMethodNotImplemented); return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: result(true)
        case .notDetermined:
          AVCaptureDevice.requestAccess(for: .video) { allowed in
            DispatchQueue.main.async { result(allowed) }
          }
        default: result(false)
        }
      }
    FlutterMethodChannel(name: "com.tabitalpay/device", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "flags" else { result(FlutterMethodNotImplemented); return }
        #if targetEnvironment(simulator)
        result("emulator")
        #else
        result("")
        #endif
      }
    FlutterMethodChannel(name: "com.tabitalpay/secure", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "set" else { result(FlutterMethodNotImplemented); return }
        // iOS does not offer Android's FLAG_SECURE equivalent. The Dart side handles
        // an unsuccessful request without interrupting payment or identity flows.
        result(false)
      }
  }
}
