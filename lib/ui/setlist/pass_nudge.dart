import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast.dart';

import '../../data/providers.dart';
import '../../data/sync/sync_controller.dart';
import '../../theme/app_theme.dart';

final _prefs = StoreRef<String, Object?>('app_prefs');
const _dismissedKey = 'passNudgeDismissed';

final _nudgeDismissedProvider = StreamProvider<bool>(
  (ref) => _prefs
      .record(_dismissedKey)
      .onSnapshot(ref.watch(databaseProvider))
      .map((s) => s?.value == true),
);

/// A one-line suggestion on the Setlist, shown to a guest once they have
/// three Shows worth keeping. Dismissed for good with the close button.
class PassNudge extends ConsumerWidget {
  const PassNudge({super.key, required this.showCount});
  final int showCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(authServiceProvider).available;
    final signedIn = ref.watch(syncControllerProvider).signedIn;
    final dismissed = ref.watch(_nudgeDismissedProvider).value ?? true;
    if (!available || signedIn || dismissed || showCount < 3) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: [
              const Icon(Icons.badge_outlined, color: StageColors.amber),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Get your Backstage Pass so these Shows are safe on '
                  'every device.',
                ),
              ),
              TextButton(
                onPressed: () => context.go('/backstage'),
                child: const Text('Get it'),
              ),
              IconButton(
                tooltip: 'Not now',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => _prefs
                    .record(_dismissedKey)
                    .put(ref.read(databaseProvider), true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
