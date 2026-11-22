import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/json_utils.dart';
import 'push_service.dart';

/// Native builds. Only the iPhone app has push notifications.
PushService createPushService() =>
    Platform.isIOS ? NativePushService() : const NoPushService();

/// iOS through the "setlist/push" channel (ios/Runner/AppDelegate.swift).
///
/// Dart to Swift: `requestPermission`, `register`, `status`,
/// `initialMessage`, `openSettings`. Swift to Dart: `token`
/// (`{token, environment}`) and `opened` (the tapped notification's data).
class NativePushService implements PushService {
  NativePushService([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('setlist/push') {
    _channel.setMethodCallHandler(_onCall);
  }

  final MethodChannel _channel;
  final _tokens = StreamController<PushToken>.broadcast();
  final _opened = StreamController<Map<String, Object?>>.broadcast();

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'token':
        final args = asMap(call.arguments);
        final token = args?['token'];
        if (token is String && token.isNotEmpty) {
          _tokens.add(
            PushToken(
              token,
              args?['environment'] == 'sandbox' ? 'sandbox' : 'production',
            ),
          );
        }
      case 'opened':
        final data = asMap(call.arguments);
        if (data != null) _opened.add(data);
    }
    return null;
  }

  Future<T?> _invoke<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on PlatformException catch (e) {
      debugPrint('Push: $method failed: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  bool get available => true;

  @override
  Future<PushPermission> status() async =>
      PushPermission.fromName(await _invoke<String>('status'));

  @override
  Future<bool> requestPermission() async =>
      await _invoke<bool>('requestPermission') ?? false;

  @override
  Future<void> register() => _invoke<void>('register');

  @override
  Stream<PushToken> get tokens => _tokens.stream;

  @override
  Stream<Map<String, Object?>> get opened => _opened.stream;

  @override
  Future<Map<String, Object?>?> initialMessage() async =>
      asMap(await _invoke<Object?>('initialMessage'));

  @override
  Future<void> openSettings() => _invoke<void>('openSettings');
}
