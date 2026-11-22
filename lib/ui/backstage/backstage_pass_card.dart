import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../data/remote/backend_config.dart';
import '../../data/sync/sync_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';

/// The account card at the top of Backstage: sign in, see the sync, sign out.
class BackstagePassCard extends ConsumerWidget {
  const BackstagePassCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(authServiceProvider).available;
    final sync = ref.watch(syncControllerProvider);
    if (!available) {
      return const SectionCard(
        title: 'Backstage Pass',
        child: Text(
          'Sign-in isn’t set up on this version yet. Your Setlist is saved '
          'on this device.',
          style: TextStyle(color: StageColors.textMuted),
        ),
      );
    }
    return sync.signedIn ? _SignedIn(sync: sync) : const _SignedOut();
  }
}

class _SignedOut extends ConsumerWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(syncControllerProvider.notifier);

    Future<void> go(Future<void> Function() signIn) async {
      try {
        await signIn();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Couldn’t open sign-in. Check your connection and try again.',
            ),
          ),
        );
      }
    }

    return SectionCard(
      title: 'Backstage Pass',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Keep your Setlist safe and on every device. The Shows already '
            'on this one come with you.',
          ),
          const SizedBox(height: 16),
          if (appleSignInEnabled) ...[
            // Apple's own look: a white button with black text and logo.
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => go(controller.signInWithApple),
              icon: const Icon(Icons.apple),
              label: const Text(
                'Sign in with Apple',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => go(controller.signInWithGoogle),
            child: const Text('Continue with Google'),
          ),
        ],
      ),
    );
  }
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.sync});
  final SyncState sync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holder = sync.holder!;
    final controller = ref.read(syncControllerProvider.notifier);
    final initial = holder.displayName.characters.first.toUpperCase();

    return SectionCard(
      title: 'Backstage Pass',
      trailing: const _AllAccessBadge(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: StageColors.magentaDeep,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: StageFonts.display,
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holder.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (holder.email != null && holder.name != null)
                      Text(
                        holder.email!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: StageColors.textMuted),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Backstage Pass options',
                onSelected: (action) => switch (action) {
                  'signout' => _signOut(context, controller),
                  _ => _deleteAccount(context, controller),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'signout', child: Text('Sign out')),
                  PopupMenuItem(value: 'delete', child: Text('Delete account')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SyncLine(sync: sync, onSync: controller.syncNow),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, SyncController c) async {
    final ok = await _confirm(
      context,
      title: 'Sign out?',
      body:
          'Your Shows stay in your Backstage Pass and leave this device. '
          'Sign back in any time to get them back.',
      action: 'Sign out',
    );
    if (!ok || !context.mounted) return;
    if (await c.signOut()) return;
    if (!context.mounted) return;
    final n = c.pendingChanges;
    final force = await _confirm(
      context,
      title: 'Changes not saved yet',
      body:
          '$n ${n == 1 ? 'change hasn’t' : 'changes haven’t'} reached your '
          'Backstage Pass, probably because you’re offline. Signing out now '
          'loses ${n == 1 ? 'it' : 'them'}.',
      action: 'Sign out anyway',
      destructive: true,
    );
    if (force) await c.signOut(force: true);
  }

  Future<void> _deleteAccount(BuildContext context, SyncController c) async {
    final ok = await _confirm(
      context,
      title: 'Delete your Backstage Pass?',
      body:
          'This deletes your account and every Show, Tour, Gear and Saved '
          'Mix saved to it, on every device. It can’t be undone.',
      action: 'Delete account',
      destructive: true,
    );
    if (!ok) return;
    try {
      await c.deleteAccount();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Couldn’t delete the account. Check your connection and try '
            'again.',
          ),
        ),
      );
    }
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: destructive
              ? TextButton.styleFrom(foregroundColor: scheme.error)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _AllAccessBadge extends StatelessWidget {
  const _AllAccessBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      gradient: StageColors.headlineGradient,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'ALL ACCESS',
      style: TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _SyncLine extends StatelessWidget {
  const _SyncLine({required this.sync, required this.onSync});
  final SyncState sync;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final (Widget icon, String text) = switch (sync.phase) {
      SyncPhase.syncing => (
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        'Syncing…',
      ),
      SyncPhase.offline => (
        const Icon(
          Icons.cloud_off_outlined,
          size: 18,
          color: StageColors.amber,
        ),
        sync.pending > 0
            ? 'Offline. ${sync.pending} '
                  '${sync.pending == 1 ? 'change waits' : 'changes wait'} on '
                  'this device.'
            : 'Offline. Will sync when you’re back.',
      ),
      _ => (
        const Icon(
          Icons.cloud_done_outlined,
          size: 18,
          color: StageColors.textMuted,
        ),
        sync.lastSynced == null
            ? 'Synced'
            : 'Synced ${syncedAgo(sync.lastSynced!, DateTime.now())}',
      ),
    };
    return Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: StageColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: sync.phase == SyncPhase.syncing ? null : onSync,
          child: const Text('Sync now'),
        ),
      ],
    );
  }
}

/// "just now", "5 min ago", "3 hr ago", "2 days ago". Public for tests.
String syncedAgo(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} hr ago';
  return d.inDays == 1 ? 'yesterday' : '${d.inDays} days ago';
}
