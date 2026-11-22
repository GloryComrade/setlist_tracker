import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/tour_invites_controller.dart';
import '../../models/crew.dart';
import '../../theme/app_theme.dart';
import 'crew_widgets.dart';
import 'tour_invite_picker.dart';

/// At the top of The Crew tab: one card per Tour invite you received.
/// Nothing when there are none.
class TourInviteCards extends ConsumerWidget {
  const TourInviteCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(visibleTourInvitesProvider);
    if (invites.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: CrewLabel('Tour invites'),
          ),
          for (var i = 0; i < invites.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            TourInviteCard(invite: invites[i]),
          ],
        ],
      ),
    );
  }
}

/// "Ryan invited you on the Spring 2027 Half Tour · Half Marathon · Sat,
/// Feb 20", with "Join the Tour" and "Not this time".
class TourInviteCard extends ConsumerStatefulWidget {
  const TourInviteCard({super.key, required this.invite});
  final CrewTourInvite invite;

  @override
  ConsumerState<TourInviteCard> createState() => _TourInviteCardState();
}

class _TourInviteCardState extends ConsumerState<TourInviteCard> {
  bool _busy = false;

  Future<void> _dismiss() async {
    setState(() => _busy = true);
    try {
      await ref.read(tourInvitesProvider.notifier).dismiss(widget.invite);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        crewSnack(context, 'Couldn’t reach the Crew. Try again.');
      }
    }
  }

  void _join() => context.push('/tour/book', extra: widget.invite.featuring);

  @override
  Widget build(BuildContext context) {
    final i = widget.invite;
    final race = tourRaceLine(i.raceDistance, i.raceDate);
    final countdown = openingNightLine(i.raceDate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CrewAvatar(name: i.fromStageName, color: i.fromColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: i.fromStageName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: ' invited you on the '),
                              TextSpan(
                                text: i.tourName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 16, height: 1.35),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          race,
                          style: const TextStyle(
                            color: StageColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (countdown != null)
                          Text(
                            countdown,
                            style: const TextStyle(
                              color: StageColors.amber,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              fontFeatures: StageFonts.tabular,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: _busy ? null : _dismiss,
                  child: const Text('Not this time'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _join,
                  icon: const Icon(Icons.confirmation_number_outlined),
                  label: const Text('Join the Tour'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
