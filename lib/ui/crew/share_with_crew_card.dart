import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../models/show.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';
import 'crew_widgets.dart';

/// On a Show: share it with the Crew, or stop. Hidden for guests and in
/// builds without the Backstage Pass.
class ShareWithCrewCard extends ConsumerStatefulWidget {
  const ShareWithCrewCard({super.key, required this.show});
  final Show show;

  @override
  ConsumerState<ShareWithCrewCard> createState() => _ShareWithCrewCardState();
}

class _ShareWithCrewCardState extends ConsumerState<ShareWithCrewCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) crewSnack(context, done);
    } catch (_) {
      if (mounted) crewSnack(context, 'Couldn’t reach the Crew. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(crewControllerProvider);
    if (!state.signedIn || !state.loaded) return const SizedBox.shrink();
    final show = widget.show;
    final c = ref.read(crewControllerProvider.notifier);

    if (state.profile == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SectionCard(
          title: 'The Crew',
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Pick a stage name to share Shows with running friends.',
                  style: TextStyle(color: StageColors.textMuted),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/crew'),
                child: const Text('Set up'),
              ),
            ],
          ),
        ),
      );
    }

    final info = state.shared[show.id];
    final shared = info != null;
    final post = state.posts
        .where((p) => p.mine && p.showId == show.id)
        .firstOrNull;
    final n = post?.encores ?? 0;
    final status = !shared
        ? 'Only you can see this Show.'
        : state.crew.isEmpty
        ? 'Shared. Your Crew will see it once they join.'
        : n == 0
        ? 'Your Crew can see this Show.'
        : 'Your Crew can see this Show · $n ${n == 1 ? 'Encore' : 'Encores'}';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SectionCard(
        title: 'The Crew',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: shared,
              onChanged: _busy
                  ? null
                  : (on) => _run(
                      on ? () => c.share(show) : () => c.unshare(show.id),
                      on ? 'Shared with your Crew.' : 'No longer shared.',
                    ),
              title: const Text(
                'Share with your Crew',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(status),
            ),
            if (shared && show.notes != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: info.includesNotes,
                onChanged: _busy
                    ? null
                    : (v) => _run(
                        () => c.share(show, includeNotes: v ?? false),
                        v == true
                            ? 'Notes shared.'
                            : 'Notes are private again.',
                      ),
                title: const Text('Include my notes'),
              ),
            const SizedBox(height: 4),
            const Text(
              'Your Crew sees the date, miles, pace, time, Song of the Show '
              'and any Gold Records. Effort, feel, Gear and Tracks stay '
              'private.',
              style: TextStyle(
                fontSize: 13,
                color: StageColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
