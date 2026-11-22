import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../data/sync/sync_controller.dart';
import '../../theme/app_theme.dart';
import '../crew/crew_widgets.dart';

/// The top-right corner of every tab's poster: your Crew picture (or the
/// Backstage Pass initial, or a person mark when signed out). Opens
/// Settings.
class SettingsAvatarButton extends ConsumerWidget {
  const SettingsAvatarButton({super.key});

  static const _size = 34.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(crewControllerProvider.select((s) => s.profile));
    final holder = ref.watch(syncControllerProvider.select((s) => s.holder));
    final Widget face;
    if (profile != null) {
      face = CrewAvatar(
        name: profile.stageName,
        color: profile.color,
        size: _size,
        badge: profile.avatarBadge,
        photoUrl: profile.avatarUrl,
      );
    } else if (holder != null) {
      face = CrewAvatar(name: holder.displayName, color: 0, size: _size);
    } else {
      face = const Icon(Icons.person_outline, color: Colors.white, size: 26);
    }
    // A white ring keeps the picture apart from the gradient behind it.
    final ringed = profile == null && holder == null
        ? face
        : DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Padding(padding: const EdgeInsets.all(2), child: face),
          );
    return IconButton(
      tooltip: 'Settings',
      // Stays put at large text sizes; the 48pt target is the button's.
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        overlayColor: StageColors.background,
      ),
      onPressed: () => context.push('/settings'),
      icon: ringed,
    );
  }
}
