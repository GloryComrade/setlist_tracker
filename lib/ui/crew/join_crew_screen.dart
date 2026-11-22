import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../data/crew/crew_service.dart';
import '../../models/crew.dart';
import '../backstage/backstage_pass_card.dart';
import '../widgets/stage_widgets.dart';
import 'crew_sheets.dart';
import 'crew_widgets.dart';

/// Where an invite link lands: "Maya invites you to the Crew".
class JoinCrewScreen extends ConsumerStatefulWidget {
  const JoinCrewScreen({super.key, required this.code});
  final String code;

  @override
  ConsumerState<JoinCrewScreen> createState() => _JoinCrewScreenState();
}

class _JoinCrewScreenState extends ConsumerState<JoinCrewScreen> {
  Future<CrewInvitePreview?>? _preview;
  bool _joining = false;

  String get _code =>
      widget.code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  @override
  void initState() {
    super.initState();
    // Kept on the device until it's used, so it survives signing in.
    final c = ref.read(crewControllerProvider.notifier);
    if (ref.read(crewControllerProvider).available) c.savePendingInvite(_code);
  }

  Future<void> _join(CrewInvitePreview p) async {
    setState(() => _joining = true);
    try {
      await ref.read(crewControllerProvider.notifier).join(_code);
      if (!mounted) return;
      crewSnack(context, 'You’re in ${p.stageName}’s Crew.');
      context.go('/crew');
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      crewSnack(
        context,
        e is CrewException ? e.message : 'Couldn’t join. Try again.',
      );
    }
  }

  Future<void> _dismiss() async {
    await ref.read(crewControllerProvider.notifier).clearPendingInvite();
    if (mounted) context.go('/crew');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(crewControllerProvider);
    final Widget body;
    if (!state.available) {
      body = const EmptyStage(
        icon: Icons.groups_outlined,
        title: 'The Crew is coming',
        message:
            'This version of Setlist Tracker can’t join a Crew yet. Open '
            'the invite on the website.',
      );
    } else if (!state.signedIn) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InvitePoster(
            headline: 'YOU’RE ON THE LIST',
            body:
                'A friend invited you to their Crew. Get your Backstage Pass '
                'and you’ll come right back here.',
          ),
          const SizedBox(height: 16),
          const BackstagePassCard(),
        ],
      );
    } else if (!state.loaded) {
      body = const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (state.profile == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InvitePoster(
            headline: 'YOU’RE ON THE LIST',
            body: 'First, the name your Crew will see.',
          ),
          const SizedBox(height: 16),
          const SectionCard(
            title: 'Pick your stage name',
            child: StageNameForm(buttonLabel: 'Next'),
          ),
        ],
      );
    } else {
      _preview ??= ref
          .read(crewControllerProvider.notifier)
          .previewInvite(_code);
      body = FutureBuilder<CrewInvitePreview?>(
        future: _preview,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final p = snap.data;
          if (snap.hasError) {
            return EmptyStage(
              icon: Icons.cloud_off_outlined,
              title: 'Can’t reach the Crew',
              message: 'Check your connection and open the invite again.',
              actionLabel: 'Try again',
              actionIcon: Icons.refresh,
              onAction: () => setState(() => _preview = null),
            );
          }
          if (p == null) {
            return EmptyStage(
              icon: Icons.event_busy_outlined,
              title: 'This invite has expired',
              message:
                  'Invites last 7 days. Ask your friend to send a fresh '
                  'link or code.',
              actionLabel: 'Go to The Crew',
              actionIcon: Icons.groups_outlined,
              onAction: _dismiss,
            );
          }
          if (p.ownInvite || p.alreadyCrew) {
            return EmptyStage(
              icon: Icons.groups_outlined,
              title: p.ownInvite ? 'That’s your invite' : 'Already in the Crew',
              message: p.ownInvite
                  ? 'Send it to a running friend so they can join your Crew.'
                  : 'You and ${p.stageName} already see each other’s Shows.',
              actionLabel: 'Go to The Crew',
              actionIcon: Icons.groups_outlined,
              onAction: _dismiss,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InvitePoster(
                avatar: CrewAvatar(name: p.stageName, color: p.color, size: 64),
                headline:
                    '${p.stageName.toUpperCase()} INVITES YOU TO THE CREW',
                body:
                    'You’ll see ${p.stageName}’s Shows and Tour, and '
                    '${p.stageName} sees yours. $kCrewSeesEverything',
              ),
              const SizedBox(height: 24),
              Center(
                child: StageButton(
                  label: 'Join the Crew',
                  icon: Icons.groups,
                  onPressed: _joining ? null : () => _join(p),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _joining ? null : _dismiss,
                  child: const Text('Not now'),
                ),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: backButtonFor(context, fallback: '/crew'),
        title: const Text('JOIN THE CREW'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [MaxWidth(child: body)],
      ),
    );
  }
}

class _InvitePoster extends StatelessWidget {
  const _InvitePoster({
    required this.headline,
    required this.body,
    this.avatar,
  });
  final String headline;
  final String body;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    return PosterSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avatar != null) ...[
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: avatar,
            ),
            const SizedBox(height: 14),
          ],
          Text(
            headline.toUpperCase(),
            style: Theme.of(context).textTheme.displaySmall
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
