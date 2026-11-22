/// Push notifications on iPhone: a Crew mate logs a Show, or someone gives a
/// Shout-out on yours.
///
/// The app only sees [PushService] (iOS's side, through the "setlist/push"
/// channel in ios/Runner/AppDelegate.swift) and [PushDevices] (the Worker's
/// `/api/push/device` route). Web, other platforms and tests get
/// [NoPushService], which never asks and never sends anything.
library;

import 'push_service_stub.dart'
    if (dart.library.io) 'push_service_native.dart'
    as platform;

/// Where iOS stands on notifications for this app.
enum PushPermission {
  notDetermined,
  denied,
  authorized,
  provisional;

  static PushPermission fromName(Object? name) => PushPermission.values
      .firstWhere((v) => v.name == name, orElse: () => notDetermined);

  bool get allowed => this == authorized || this == provisional;
}

/// The device token iOS handed out, and which APNs it belongs to.
class PushToken {
  const PushToken(this.token, this.environment);

  /// Hex, as APNs wants it.
  final String token;

  /// "sandbox" (Xcode debug builds) or "production" (TestFlight, App Store).
  final String environment;

  @override
  bool operator ==(Object other) =>
      other is PushToken &&
      other.token == token &&
      other.environment == environment;

  @override
  int get hashCode => Object.hash(token, environment);
}

abstract interface class PushService {
  /// False on web and anywhere but iPhone: no switches, no asking.
  bool get available;

  Future<PushPermission> status();

  /// iOS's own prompt (iOS shows it only once). Registers for a token when
  /// granted.
  Future<bool> requestPermission();

  /// Asks iOS for a token again, if notifications are already allowed.
  Future<void> register();

  /// Each token iOS hands out (at every launch once registered).
  Stream<PushToken> get tokens;

  /// The custom data of a notification the runner tapped
  /// (`{type, postId}`).
  Stream<Map<String, Object?>> get opened;

  /// The notification that launched the app, if one did. Asked once.
  Future<Map<String, Object?>?> initialMessage();

  /// Opens Setlist Tracker's notification settings in the iOS Settings app.
  Future<void> openSettings();
}

/// The server half: which phones get the Crew's notifications.
abstract interface class PushDevices {
  /// Sends this phone's token, signed in. Moves it here if another account
  /// had it.
  Future<void> register(PushToken token);

  /// Stops notifications to this phone (yours only).
  Future<void> unregister(String token);
}

/// Web, tests and anything that isn't an iPhone.
class NoPushService implements PushService {
  const NoPushService();

  @override
  bool get available => false;

  @override
  Future<PushPermission> status() async => PushPermission.denied;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> register() async {}

  @override
  Stream<PushToken> get tokens => const Stream.empty();

  @override
  Stream<Map<String, Object?>> get opened => const Stream.empty();

  @override
  Future<Map<String, Object?>?> initialMessage() async => null;

  @override
  Future<void> openSettings() async {}
}

/// The iPhone channel on iOS, otherwise [NoPushService].
PushService createPushService() => platform.createPushService();
