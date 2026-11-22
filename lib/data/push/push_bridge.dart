import 'dart:async';

import 'package:flutter/services.dart';

/// Notification permission as iOS reports it.
enum PushPermission { unsupported, notDetermined, denied, authorized }

/// An APNs device token, and whether it belongs to the sandbox (debug builds).
class PushToken {
  const PushToken(this.token, {this.sandbox = false});
  final String token;
  final bool sandbox;
}

/// The phone's side of push notifications: permission, the device token and
/// taps on notifications.
abstract class PushBridge {
  bool get supported;
  Future<PushPermission> permission();

  /// Shows the iOS prompt (once; later it just answers). True when allowed.
  Future<bool> requestPermission();

  /// Asks iOS for the device token; it arrives on [tokens].
  Future<void> register();
  Stream<PushToken> get tokens;

  /// App paths ("/crew/mate/…") from tapped notifications, including the
  /// one that opened the app.
  Stream<String> get opens;
}

/// Web and tests: no notifications.
class NoPushBridge implements PushBridge {
  const NoPushBridge();
  @override
  bool get supported => false;
  @override
  Future<PushPermission> permission() async => PushPermission.unsupported;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> register() async {}
  @override
  Stream<PushToken> get tokens => const Stream.empty();
  @override
  Stream<String> get opens => const Stream.empty();
}

/// iOS, through CrewPush in ios/Runner/AppDelegate.swift.
class MethodChannelPushBridge implements PushBridge {
  MethodChannelPushBridge() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'token':
          final args = Map<String, Object?>.from(call.arguments as Map);
          final token = args['token'];
          if (token is String && token.isNotEmpty) {
            _tokens.add(PushToken(token, sandbox: args['sandbox'] == true));
          }
        case 'opened':
          await _takePending();
      }
    });
  }

  static const _channel = MethodChannel('setlisttracker/push');
  final _tokens = StreamController<PushToken>.broadcast();
  final _opens = StreamController<String>.broadcast(
    // The notification that launched the app waits for the first listener.
    onListen: () => unawaited(_instance?._takePending()),
  );
  static MethodChannelPushBridge? _instance;

  /// One per app: the native side has a single channel.
  static MethodChannelPushBridge get instance =>
      _instance ??= MethodChannelPushBridge();

  Future<void> _takePending() async {
    try {
      final path = await _channel.invokeMethod<String>('takePendingPath');
      if (path != null && path.startsWith('/')) _opens.add(path);
    } on PlatformException catch (_) {}
  }

  @override
  bool get supported => true;

  @override
  Future<PushPermission> permission() async {
    final s = await _channel.invokeMethod<String>('status');
    return switch (s) {
      'authorized' => PushPermission.authorized,
      'denied' => PushPermission.denied,
      _ => PushPermission.notDetermined,
    };
  }

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<void> register() => _channel.invokeMethod<void>('register');

  @override
  Stream<PushToken> get tokens => _tokens.stream;

  @override
  Stream<String> get opens => _opens.stream;
}
