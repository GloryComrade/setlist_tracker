import '../remote/api_client.dart';

/// The server's list of this runner's phones (PUT/DELETE /api/push/device).
abstract class PushApi {
  Future<void> registerDevice(String token, {required bool sandbox});
  Future<void> forgetDevice(String token);
}

class CloudflarePushApi implements PushApi {
  CloudflarePushApi(this._api);
  final ApiClient _api;

  @override
  Future<void> registerDevice(String token, {required bool sandbox}) async {
    await _api.put(
      '/api/push/device',
      body: {'token': token, 'sandbox': sandbox},
    );
  }

  @override
  Future<void> forgetDevice(String token) async {
    await _api.delete('/api/push/device/${Uri.encodeComponent(token)}');
  }
}
