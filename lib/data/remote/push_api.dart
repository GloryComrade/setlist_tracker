import '../push/push_service.dart';
import 'api_client.dart';

/// [PushDevices] backed by the Worker's `/api/push/device` route
/// (docs/cloudflare-api.md).
class CloudflarePushDevices implements PushDevices {
  CloudflarePushDevices(this._api);
  final ApiClient _api;

  @override
  Future<void> register(PushToken token) => _api.put(
    '/api/push/device',
    body: {'token': token.token, 'environment': token.environment},
  );

  @override
  Future<void> unregister(String token) =>
      _api.delete('/api/push/device/${Uri.encodeComponent(token)}');
}
