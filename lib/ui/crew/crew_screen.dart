import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../data/crew/tour_invites_controller.dart';
import '../../data/push/push_controller.dart';
import '../../models/crew.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';
import 'crew_post_card.dart';
import 'crew_sheets.dart';
import 'crew_widgets.dart';
import 'tour_invite_cards.dart';

/// The Crew tab: your running friends and the Shows they share.
class CrewScreen extends ConsumerStatefulWidget {
  const CrewScreen({super.key});

  @override
  ConsumerState<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends ConsumerState<CrewScreen> {
  bool _checkedPending = false;
  bool _checkedPush = false;

  /// An invite link opened before sign-in waits on the device; pick it up
  /// once there's a stage name.
  Future<void> _openPendingInvite() async {
    _checkedPending = true;
    final code = await ref
        .read(crewControllerProvider.notifier)
        .pendingInvite();
    if (code != null && mounted) context.push('/crew/join/$code');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(crewControllerProvider);
    if (!_checkedPending && state.profile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingInvite());
    }
    if (!_checkedPush && state.profile != null) {
      // The first visit with a stage name: iOS's own notification prompt,
      // once per device (nothing on web).
      _checkedPush = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(pushControllerProvider.notifier).askOnce(),
      );
    }

    final Widget body;
    if (!state.available) {
      body = const _Centered(
        child: EmptyStage(
          icon: Icons.groups_outlined,
          title: 'The Crew is coming',
          message:
              'Training with friends turns on with the Backstage Pass. '
              'Your Setlist is saved on this device.',
        ),
      );
    } else if (!state.signedIn) {
      body = _Centered(
        child: EmptyStage(
          icon: Icons.groups_outlined,
          title: 'Join the Crew',
          message:
              'Sign in with your Backstage Pass to see your running friends’ '
              'Shows and cheer them on.',
          actionLabel: 'Go Backstage',
          actionIcon: Icons.badge_outlined,
          onAction: () => context.go('/backstage'),
        ),
      );
    } else if (!state.loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.profile == null && state.error != null) {
      body = _Centered(
        child: EmptyStage(
          icon: Icons.cloud_off_outlined,
          title: 'Can’t reach the Crew',
          message: state.error!,
          actionLabel: 'Try again',
          actionIcon: Icons.refresh,
          onAction: ref.read(crewControllerProvider.notifier).refresh,
        ),
      );
    } else if (state.profile == null) {
      body = const _FirstRun();
    } else {
      body = _CrewHome(state: state);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(child: body),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(child: MaxWidth(child: child)),
  );
}

/// Signed in, no stage name yet.
class _FirstRun extends StatelessWidget {
  const _FirstRun();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PosterHeader(
                title: 'THE CREW',
                children: [
                  SizedBox(height: 6),
                  Text(
                    'See your running friends’ Shows and cheer them on.',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SectionCard(
                title: 'Pick your stage name',
                child: StageNameForm(buttonLabel: 'Join the Crew'),
              ),
              const SizedBox(height: 16),
              const _HowItWorks(),
            ],
          ),
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const rows = [
      (
        Icons.link,
        'Invite only',
        'Friends join with your link or code. Nobody can search for you.',
      ),
      (
        Icons.confirmation_number_outlined,
        'Every Show, unless you say so',
        kCrewSeesEverything,
      ),
      (
        Icons.event_outlined,
        'Tour together',
        'See your Crew’s Tours, and book one featuring a friend for the same '
            'Opening Night.',
      ),
      (
        Icons.celebration_outlined,
        'Encores',
        'Cheer a friend’s Show with one tap.',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          for (final (icon, title, body) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: StageColors.amber, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: const TextStyle(
                            color: StageColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CrewHome extends ConsumerWidget {
  const _CrewHome({required this.state});
  final CrewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crew = state.crew;
    final posts = state.posts;
    final c = ref.read(crewControllerProvider.notifier);
    final n = crew.length;

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        c.refresh(),
        ref.read(tourInvitesProvider.notifier).refresh(),
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PosterSurface(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WholeWordsText(
                              'THE CREW',
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              n == 0
                                  ? 'Only people you invite see your Shows.'
                                  : '$n ${n == 1 ? 'runner' : 'runners'} in '
                                        'your Crew. ${state.allActivityPending ? 'They see the Shows you shared.' : 'They see every Show you log.'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Settings (stage name, picture, blocked runners).
                      ?PosterCornerAction.maybeOf(context),
                    ],
                  ),
                ),
                if (state.allActivityPending &&
                    !state.allActivityNoticeHidden) ...[
                  const SizedBox(height: 12),
                  const AllActivityNotice(),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 18,
                        color: StageColors.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: const TextStyle(color: StageColors.textMuted),
                        ),
                      ),
                      TextButton(
                        onPressed: c.refresh,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ],
                const TourInviteCards(),
                const SizedBox(height: 16),
                _CrewCard(crew: crew),
                const SizedBox(height: 24),
                if (posts.isEmpty)
                  EmptyStage(
                    icon: Icons.confirmation_number_outlined,
                    title: crew.isEmpty ? 'No Shows yet' : 'Quiet night',
                    message: crew.isEmpty
                        ? 'Your Crew’s Shows land here once you’re together. '
                              'Invite a running friend to start.'
                        : 'When your Crew logs a Show, it lands here. So do '
                              'yours.',
                  )
                else ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: CrewLabel('Latest Shows'),
                  ),
                  for (final p in posts) ...[
                    CrewPostCard(post: p),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One time, for runners who were in The Crew before it saw every Show.
class AllActivityNotice extends ConsumerStatefulWidget {
  const AllActivityNotice({super.key});

  @override
  ConsumerState<AllActivityNotice> createState() => _AllActivityNoticeState();
}

class _AllActivityNoticeState extends ConsumerState<AllActivityNotice> {
  bool _sending = false;

  Future<void> _accept() async {
    setState(() => _sending = true);
    try {
      await ref.read(crewControllerProvider.notifier).acceptAllActivity();
      if (mounted) {
        crewSnack(context, 'Your Crew sees every Show you log from now on.');
      }
    } catch (_) {
      if (mounted) crewSnack(context, 'Couldn’t reach the Crew. Try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.read(crewControllerProvider.notifier);
    return SectionCard(
      title: 'Your Crew sees more now',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'From now on, your Crew sees every Show you log: effort, feel, '
            'notes, route and Gear. Shows you logged before today stay '
            'hidden unless you shared them. Mark any Show “Keep off the '
            'Crew” to keep it to yourself.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _sending ? null : c.hideAllActivityNotice,
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: _sending ? null : _accept,
                child: const Text('Sounds good'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Who's in the Crew, and the way to add someone.
class _CrewCard extends StatelessWidget {
  const _CrewCard({required this.crew});
  final List<CrewMate> crew;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Your Crew',
      trailing: TextButton(
        onPressed: () => showEnterCodeDialog(context),
        child: const Text('Enter a code'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (crew.isEmpty)
            const Text(
              'Invite a running friend. When they join, you’ll see each '
              'other’s Shows and Tours.',
              style: TextStyle(color: StageColors.textMuted, height: 1.4),
            )
          else
            // Sized by its chips, so the strip grows with the text size.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < crew.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _MateChip(mate: crew[i]),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          Center(
            child: StageButton(
              label: 'Invite a friend',
              icon: Icons.person_add_alt_1,
              onPressed: () => showInviteSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _MateChip extends StatelessWidget {
  const _MateChip({required this.mate});
  final CrewMate mate;

  @override
  Widget build(BuildContext context) {
    final night = mate.tour?.raceDate;
    final days = night == null ? null : daysUntil(night);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showMateSheet(context, mate),
      // 76px wide at 100% text, growing with the text size; a long name
      // ends in an ellipsis instead of running into the next chip.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 76,
          maxWidth: MediaQuery.textScalerOf(context).scale(76),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              CrewAvatar(
                name: mate.stageName,
                color: mate.color,
                size: 48,
                badge: mate.avatarBadge,
                photoUrl: mate.avatarUrl,
              ),
              const SizedBox(height: 6),
              Text(
                mate.stageName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (days != null && days >= 0)
                Text(
                  days == 0 ? 'Race day' : '$days days',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: StageColors.amber,
                    fontFeatures: StageFonts.tabular,
                  ),
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
