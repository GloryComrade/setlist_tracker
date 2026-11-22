import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set before launch finishes, so tapping a notification that opened the
    // app is delivered too.
    UNUserNotificationCenter.current().delegate = CrewPush.shared
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CrewPush") {
      CrewPush.shared.attach(registrar.messenger())
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    CrewPush.shared.gotToken(deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("Push registration failed: \(error.localizedDescription)")
  }
}

/// "Maya played a Show" notifications: permission, the APNs device token and
/// taps, over the "setlisttracker/push" channel (lib/data/push/).
final class CrewPush: NSObject, UNUserNotificationCenterDelegate {
  static let shared = CrewPush()

  private var channel: FlutterMethodChannel?
  /// A tapped notification's app path, until Dart asks for it.
  private var pendingPath: String?

  func attach(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "setlisttracker/push", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let status: String
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: status = "authorized"
        case .denied: status = "denied"
        default: status = "notDetermined"
        }
        DispatchQueue.main.async { result(status) }
      }
    case "requestPermission":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
        granted, _ in
        DispatchQueue.main.async {
          if granted { UIApplication.shared.registerForRemoteNotifications() }
          result(granted)
        }
      }
    case "register":
      UIApplication.shared.registerForRemoteNotifications()
      result(nil)
    case "takePendingPath":
      result(pendingPath)
      pendingPath = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func gotToken(_ data: Data) {
    let token = data.map { String(format: "%02x", $0) }.joined()
    #if DEBUG
      let sandbox = true
    #else
      let sandbox = false
    #endif
    channel?.invokeMethod("token", arguments: ["token": token, "sandbox": sandbox])
  }

  // Show the banner even while the app is open.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let path = response.notification.request.content.userInfo["path"] as? String {
      // Kept until Dart takes it: on a cold start Dart may not be listening
      // yet, and asks with takePendingPath once it is.
      pendingPath = path
      channel?.invokeMethod("opened", arguments: nil)
    }
    completionHandler()
  }
}
