import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../data/crew/crew_service.dart';
import '../../data/crew/tour_invites_controller.dart';
import '../../models/crew.dart';
import '../../models/tour.dart';
import '../../theme/app_theme.dart';
import 'crew_sheets.dart';
import 'crew_widgets.dart';

final _raceDay = DateFormat('EEE, MMM d');

/// "Half Marathon · Sat, Feb 20".
String tourRaceLine(RaceDistance distance, DateTime raceDate) =>
    '${distance.label} · ${_raceDay.format(raceDate)}';

/// "Invite sent to Maya.", "Invites sent to Maya and Jordan."
String tourInvitesSentLine(List<String> names) {
  if (names.isEmpty) return 'No invites sent. They’re not in your Crew now.';
  if (names.length == 1) return 'Invite sent to ${names.first}.';
  if (names.length > 3) return 'Invites sent to ${names.length} Crew mates.';
  final last = names.last;
  return 'Invites sent to '
      '${names.take(names.length - 1).join(', ')} and $last.';
}

/// Crew mates who can't be invited onto [tour], and why: they're already
/// co-headlining it, or it was booked featuring them.
Map<String, String> tourInviteUnavailable(
  List<CrewMate> crew, {
  required DateTime raceDate,
  required RaceDistance raceDistance,
  String? featuringId,
}) => {
  for (final m in crew)
    if (m.userId == featuringId)
      m.userId: 'Featuring'
    else if (m.tour != null &&
        sameRace(
          m.tour!.raceDate,
          m.tour!.raceDistance,
          raceDate,
          raceDistance,
        ))
      m.userId: 'Co-headlining',
};

/// Invites [userIds] in the background (the screen may already be gone)
/// and says how it went on [messenger].
Future<void> sendTourInvites({
  required TourInvitesController controller,
  required ScaffoldMessengerState messenger,
  required String tourId,
  required List<CrewMate> mates,
}) async {
  if (mates.isEmpty) return;
  final names = {for (final m in mates) m.userId: m.stageName};
  try {
    final invited = await controller.send(tourId, names.keys.toList());
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          tourInvitesSentLine([for (final id in invited) ?names[id]]),
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e is TourNotSyncedException
              ? 'Couldn’t send the Tour invites yet. Try again from the '
                    'Tour tab once you’re online.'
              : e is CrewException
              ? e.message
              : 'Couldn’t send the Tour invites. Try again from the Tour tab.',
        ),
      ),
    );
  }
}

/// Crew mates to tick, one row each: avatar, name, and why they can't be
/// picked (already co-headlining) when that's so.
class CrewPickList extends StatelessWidget {
  const CrewPickList({
    super.key,
    required this.mates,
    required this.selected,
    required this.onChanged,
    this.unavailable = const {},
  });

  final List<CrewMate> mates;
  final Set<String> selected;
  final void Function(String userId, bool on) onChanged;

  /// User id → why they can't be invited.
  final Map<String, String> unavailable;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final m in mates)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: unavailable.containsKey(m.userId)
              ? false
              : selected.contains(m.userId),
          onChanged: unavailable.containsKey(m.userId)
              ? null
              : (v) => onChanged(m.userId, v ?? false),
          secondary: CrewAvatar(name: m.stageName, color: m.color),
          title: Text(
            m.stageName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: unavailable[m.userId] == null
              ? null
              : Text(
                  unavailable[m.userId]!,
                  style: const TextStyle(color: StageColors.textMuted),
                ),
        ),
    ],
  );
}

/// On Book The Tour's preview: tick Crew mates to invite once the Tour is
/// booked. Nothing for runners signed out or without a stage name.
class BringYourCrewSection extends ConsumerWidget {
  const BringYourCrewSection({
    super.key,
    required this.raceDate,
    required this.raceDistance,
    required this.selected,
    required this.onChanged,
    this.featuringId,
  });

  final DateTime raceDate;
  final RaceDistance raceDistance;
  final Set<String> selected;
  final void Function(String userId, bool on) onChanged;

  /// The Crew mate this Tour is booked featuring, who's already on it.
  final String? featuringId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(crewServiceProvider) == null) return const SizedBox.shrink();
    final state = ref.watch(crewControllerProvider);
    if (!state.available || state.profile == null) {
      return const SizedBox.shrink();
    }
    final crew = state.crew;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'BRING YOUR CREW',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              crew.isEmpty
                  ? 'Tour with a friend: invite them to your Crew, then ask '
                        'them onto this Tour.'
                  : 'Pick Crew mates to invite. Once the Tour is booked, they '
                        'can book their own for the same Opening Night.',
              style: const TextStyle(color: StageColors.textMuted, height: 1.4),
            ),
            if (crew.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showInviteSheet(context),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Invite a friend'),
                ),
              )
            else ...[
              const SizedBox(height: 4),
              CrewPickList(
                mates: crew,
                selected: selected,
                onChanged: onChanged,
                unavailable: tourInviteUnavailable(
                  crew,
                  raceDate: raceDate,
                  raceDistance: raceDistance,
                  featuringId: featuringId,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The Tour tab's "Invite to this Tour".
Future<void> showTourInviteSheet(BuildContext context, Tour tour) =>
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TourInviteSheet(tour: tour),
    );

class _TourInviteSheet extends ConsumerStatefulWidget {
  const _TourInviteSheet({required this.tour});
  final Tour tour;

  @override
  ConsumerState<_TourInviteSheet> createState() => _TourInviteSheetState();
}

class _TourInviteSheetState extends ConsumerState<_TourInviteSheet> {
  final _selected = <String>{};
  bool _sending = false;

  Future<void> _send(List<CrewMate> crew) async {
    final mates = [
      for (final m in crew)
        if (_selected.contains(m.userId)) m,
    ];
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await sendTourInvites(
      controller: ref.read(tourInvitesProvider.notifier),
      messenger: messenger,
      tourId: widget.tour.id,
      mates: mates,
    );
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tour = widget.tour;
    final crew = ref.watch(crewControllerProvider.select((s) => s.crew));
    final unavailable = tourInviteUnavailable(
      crew,
      raceDate: tour.setup.raceDate,
      raceDistance: tour.setup.raceDistance,
      featuringId: tour.featuring?.userId,
    );
    final n = _selected.length;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('INVITE TO THIS TOUR', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              '${tour.name} · '
              '${tourRaceLine(tour.setup.raceDistance, tour.setup.raceDate)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              crew.isEmpty
                  ? 'Your Crew is empty. Invite a running friend first, then '
                        'ask them onto this Tour.'
                  : 'They get an invite on The Crew tab to book their own Tour '
                        'for the same Opening Night.',
              style: const TextStyle(color: StageColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            if (crew.isEmpty)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  final root = Navigator.of(context);
                  final ctx = root.context;
                  root.pop();
                  showInviteSheet(ctx);
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invite a friend'),
              )
            else ...[
              CrewPickList(
                mates: crew,
                selected: _selected,
                unavailable: unavailable,
                onChanged: (id, on) => setState(
                  () => on ? _selected.add(id) : _selected.remove(id),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: n == 0 || _sending ? null : () => _send(crew),
                icon: const Icon(Icons.confirmation_number_outlined),
                label: Text(
                  _sending
                      ? 'Sending…'
                      : n > 1
                      ? 'Send $n invites'
                      : 'Send invite',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
