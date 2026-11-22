import 'push_service.dart';

/// Web: no push notifications.
PushService createPushService() => const NoPushService();
