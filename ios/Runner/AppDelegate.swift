import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// "setlist/push": Crew notifications (lib/data/push/push_service_native.dart).
  private var pushChannel: FlutterMethodChannel?
  /// A tapped notification waits here until Dart asks for it
  /// (`initialMessage`), so a cold start from a notification isn't lost.
  private var pendingOpen: [String: Any]?
  private var dartReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set before launch finishes so a tap that launched the app arrives.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Show page route maps (RouteMapView.swift).
    if let maps = engineBridge.pluginRegistry.registrar(forPlugin: "SetlistRouteMap") {
      maps.register(RouteMapFactory(), withId: "setlist/route-map")
    }
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SetlistPush") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "setlist/push",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handlePush(call, result: result)
    }
    pushChannel = channel
  }

  // MARK: Dart to Swift

  private func handlePush(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    switch call.method {
    case "requestPermission":
      center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        DispatchQueue.main.async {
          if granted { UIApplication.shared.registerForRemoteNotifications() }
          result(granted)
        }
      }
    case "register":
      center.getNotificationSettings { settings in
        DispatchQueue.main.async {
          let s = settings.authorizationStatus
          if s == .authorized || s == .provisional || s == .ephemeral {
            UIApplication.shared.registerForRemoteNotifications()
          }
          result(nil)
        }
      }
    case "status":
      center.getNotificationSettings { settings in
        let name: String
        switch settings.authorizationStatus {
        case .authorized, .ephemeral: name = "authorized"
        case .provisional: name = "provisional"
        case .denied: name = "denied"
        default: name = "notDetermined"
        }
        DispatchQueue.main.async { result(name) }
      }
    case "initialMessage":
      dartReady = true
      let open = pendingOpen
      pendingOpen = nil
      result(open)
    case "openSettings":
      if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Swift to Dart

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    #if DEBUG
      let environment = "sandbox"
    #else
      let environment = "production"
    #endif
    pushChannel?.invokeMethod("token", arguments: ["token": token, "environment": environment])
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("Push: registration failed: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  /// A Crew notification while the app is open still shows as a banner.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  /// The runner tapped a notification: Dart opens The Crew.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    var data: [String: Any] = [:]
    for (key, value) in response.notification.request.content.userInfo {
      if let k = key as? String, k != "aps" { data[k] = value }
    }
    if dartReady, let channel = pushChannel {
      channel.invokeMethod("opened", arguments: data)
    } else {
      pendingOpen = data
    }
    completionHandler()
  }
}
