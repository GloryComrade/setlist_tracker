/// Crew photos, fetched through [CrewService] (they need sign-in, so an
/// image URL alone won't load them) and kept in memory by address. A new
/// photo has a new address, so nothing here goes stale.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show Uint8List;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'crew_controller.dart';

/// The photo at an `avatarUrl`, or null when it can't be had (offline,
/// removed, blocked): the avatar then shows the badge or initial.
final crewPhotoProvider = FutureProvider.autoDispose.family<Uint8List?, String>(
  (ref, url) async {
    final service = ref.watch(crewServiceProvider);
    if (service == null) return null;
    try {
      final bytes = await service.avatarBytes(url);
      // Kept once it arrives; a failure is tried again next time it's shown.
      ref.keepAlive();
      return bytes;
    } catch (e) {
      debugPrint('Crew photo: $e');
      return null;
    }
  },
);
