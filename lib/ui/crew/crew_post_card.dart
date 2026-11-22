import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../logic/show_math.dart';
import '../../logic/spoken.dart';
import '../../models/crew.dart';
import '../../models/enums.dart';
import '../../models/show.dart';
import '../../theme/app_theme.dart';
import '../widgets/album_art.dart';
import '../widgets/open_link.dart';
import '../widgets/stage_widgets.dart';
import 'crew_widgets.dart';

/// A Show on the Crew feed: the Setlist's ticket stub, signed by the runner
/// who logged it, with everything about the run and an Encore to cheer it.
class CrewPostCard extends ConsumerWidget {
  const CrewPostCard({
    super.key,
    required this.post,
    this.now,
    this.showOwner = true,
    this.goldRecords = const [],
  });
  final CrewPost post;

  /// For tests; defaults to the clock.
  final DateTime? now;

  /// False on a Crew mate's own page, where every Show is theirs.
  final bool showOwner;

  /// Titles of the Gold Records this Show holds, e.g. "Fastest 5K".
  final List<String> goldRecords;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = post.show;
    final song = s.song;
    final notes = s.notes;
    final facts = crewShowFacts(s, gearName: post.gearName);

    return Card(
      shape: const TicketBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Your own posts open the Show on your Setlist.
        onTap: post.mine ? () => context.push('/show/${post.showId}') : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The stub's day is spoken with the workout line below.
              ExcludeSemantics(child: _Stub(post: post)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 4, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Signature(post: post, now: now, showOwner: showOwner),
                      const SizedBox(height: 2),
                      // Spoken with the numbers below, as one line.
                      ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${s.workoutType.label.toUpperCase()} · '
                                  '${s.venue.label.toUpperCase()}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                    color: StageColors.textMuted,
                                  ),
                                ),
                              ),
                              FeelFace(s.feel),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Semantics(
                        container: true,
                        label:
                            '${spokenShowHeading(s.date, s.workoutType, s.venue)} '
                            '${spokenShowNumbers(s.distanceMiles, s.durationSeconds)}',
                        child: ExcludeSemantics(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  formatMiles(s.distanceMiles),
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontFeatures: StageFonts.tabular,
                                      ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  formatPace(s.paceSecondsPerMile),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: StageColors.amber,
                                        fontFeatures: StageFonts.tabular,
                                      ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  formatDuration(s.durationSeconds),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: StageColors.textMuted,
                                        fontFeatures: StageFonts.tabular,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Semantics(
                        container: true,
                        label:
                            'Effort ${s.effort} of 10, felt ${s.feel.label}.',
                        child: ExcludeSemantics(
                          child: Text(
                            'Effort ${s.effort}/10 · ${s.feel.label}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: StageColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [for (final f in facts) _FactChip(f)],
                          ),
                        ),
                      ],
                      if (song != null) ...[
                        const SizedBox(height: 10),
                        _SongLine(post: post),
                      ],
                      if (goldRecords.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final r in goldRecords) _GoldBadge(r),
                          ],
                        ),
                      ],
                      if (notes != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            notes,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(height: 1.35),
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      _EncoreButton(post: post),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One small fact about a Show: where, on what, in what weather.
typedef CrewShowFact = ({IconData icon, String text, String spoken});

/// The venue details worth a glance on a Crew post, in reading order: the
/// route, surface, climb and weather of a Live Show, or the Tracks of a
/// Studio Session; then the Gear.
List<CrewShowFact> crewShowFacts(Show s, {String? gearName}) {
  String n(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
  final out = <CrewShowFact>[];
  final live = s.venue == Venue.live ? s.live : null;
  final studio = s.venue == Venue.studio ? s.studio : null;
  if (live != null) {
    final route = live.routeName;
    out.add((
      icon: Icons.route,
      text: route == null
          ? live.surface.label
          : '$route · ${live.surface.label}',
      spoken: route == null
          ? 'Surface: ${live.surface.label}.'
          : 'Route: $route, ${live.surface.label}.',
    ));
    final gain = live.elevationGainFt;
    if (gain != null && gain > 0) {
      out.add((
        icon: Icons.terrain,
        text: '${n(gain)} ft',
        spoken: '${n(gain)} feet of climbing.',
      ));
    }
    final w = live.weather;
    if (w != null && !w.isEmpty) {
      final parts = [
        if (w.tempF != null) '${n(w.tempF!)}°F',
        if (w.conditions != null) w.conditions!.label,
        if (w.windMph != null) '${n(w.windMph!)} mph wind',
      ];
      out.add((
        icon: w.conditions == null
            ? Icons.thermostat
            : iconForConditions(w.conditions!),
        text: parts.join(' · '),
        spoken:
            'Weather: ${[if (w.tempF != null) '${n(w.tempF!)} degrees', if (w.conditions != null) w.conditions!.label, if (w.windMph != null) '${n(w.windMph!)} miles per hour wind'].join(', ')}.',
      ));
    }
  }
  if (studio != null && studio.tracks.isNotEmpty) {
    final tracks = studio.tracks;
    final top = tracks.map((t) => t.speedMph).reduce((a, b) => a > b ? a : b);
    final incline = studio.totals.averageInclinePercent;
    final count = '${tracks.length} ${tracks.length == 1 ? 'Track' : 'Tracks'}';
    out.add((
      icon: Icons.graphic_eq,
      text:
          '$count · up to ${top.toStringAsFixed(1)} mph · '
          '${incline.toStringAsFixed(1)}% incline',
      spoken:
          '$count, up to ${top.toStringAsFixed(1)} miles per hour, '
          '${incline.toStringAsFixed(1)} percent average incline.',
    ));
  }
  if (gearName != null && gearName.trim().isNotEmpty) {
    out.add((
      icon: Icons.directions_run,
      text: gearName,
      spoken: 'Gear: $gearName.',
    ));
  }
  return out;
}

class _FactChip extends StatelessWidget {
  const _FactChip(this.fact);
  final CrewShowFact fact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: fact.spoken,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(fact.icon, size: 16, color: StageColors.textMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                fact.text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: StageColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who logged it and when. A Crew mate's name opens their page.
class _Signature extends StatelessWidget {
  const _Signature({
    required this.post,
    required this.now,
    required this.showOwner,
  });
  final CrewPost post;
  final DateTime? now;
  final bool showOwner;

  @override
  Widget build(BuildContext context) {
    final who = post.mine ? 'You' : post.stageName;
    final ago = Text(
      sharedAgo(post.sharedAt, now: now),
      style: const TextStyle(fontSize: 13, color: StageColors.textMuted),
    );
    final Widget owner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CrewAvatar(name: post.stageName, color: post.color, size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            who,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    return Row(
      children: [
        if (showOwner) ...[
          Flexible(
            child: post.mine
                ? owner
                : Semantics(
                    button: true,
                    hint: 'Opens ${post.stageName}’s page',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push('/crew/mate/${post.ownerId}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: owner,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 6),
        ],
        ago,
        const Spacer(),
        _PostMenu(post: post),
      ],
    );
  }
}

class _Stub extends StatelessWidget {
  const _Stub({required this.post});
  final CrewPost post;

  @override
  Widget build(BuildContext context) {
    final s = post.show;
    return Container(
      width: 64,
      decoration: BoxDecoration(gradient: gradientFor(s.venue)),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            formatShowDay(s.date).split(',').first.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${s.date.day}',
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(color: Colors.white),
            ),
          ),
          Icon(iconFor(s.venue), color: Colors.white, size: 18),
        ],
      ),
    );
  }
}

class _SongLine extends StatelessWidget {
  const _SongLine({required this.post});
  final CrewPost post;

  @override
  Widget build(BuildContext context) {
    final song = post.show.song!;
    final link = song.spotifyUrl ?? song.appleMusicUrl;
    final note = song.note;
    final line = Row(
      children: [
        AlbumArt(url: song.albumArtUrl, size: 36, radius: 6),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                note == null ? song.artist : '${song.artist} · “$note”',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: StageColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final spoken = [spokenSong(song), if (note != null) '“$note”'].join(' ');
    if (link == null) {
      return Semantics(
        container: true,
        label: spoken,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: line,
          ),
        ),
      );
    }
    final where = song.spotifyUrl != null ? 'Spotify' : 'Apple Music';
    return Semantics(
      container: true,
      link: true,
      label: spoken,
      hint: 'Opens in $where',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openLink(context, Uri.parse(link)),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(right: 10, top: 2, bottom: 2),
            child: line,
          ),
        ),
      ),
    );
  }
}

/// "Fastest 5K" on a dark pill with a gold disc, so it reads as an award,
/// not a button.
class _GoldBadge extends StatelessWidget {
  const _GoldBadge(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Gold Record: $title',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
          decoration: BoxDecoration(
            color: StageColors.surfaceHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: StageColors.amber.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.album, size: 14, color: StageColors.amber),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: StageColors.amber,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EncoreButton extends ConsumerWidget {
  const _EncoreButton({required this.post});
  final CrewPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = post.encores;
    final count = n == 0 ? '' : ' · $n';
    if (post.mine) {
      // You can't cheer your own Show; just see who did.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.celebration_outlined,
              size: 18,
              color: StageColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              n == 0 ? 'No Encores yet' : '$n ${n == 1 ? 'Encore' : 'Encores'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: StageColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    final on = post.encoredByMe;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: on ? StageColors.magenta : StageColors.text,
        ),
        onPressed: () async {
          try {
            await ref.read(crewControllerProvider.notifier).toggleEncore(post);
          } catch (_) {
            if (context.mounted) {
              crewSnack(context, 'Couldn’t send the Encore. Try again.');
            }
          }
        },
        icon: Icon(on ? Icons.celebration : Icons.celebration_outlined),
        label: Text(
          'Encore$count',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _PostMenu extends ConsumerWidget {
  const _PostMenu({required this.post});
  final CrewPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(crewControllerProvider.notifier);
    return PopupMenuButton<String>(
      tooltip: 'Show options',
      icon: const Icon(Icons.more_horiz, color: StageColors.textMuted),
      onSelected: (action) async {
        switch (action) {
          case 'edit':
            await context.push('/show/${post.showId}/edit');
          case 'private':
            try {
              await c.keepOffCrew(post);
              if (context.mounted) {
                crewSnack(
                  context,
                  'Kept off the Crew. It stays on your Setlist.',
                );
              }
            } catch (_) {
              if (context.mounted) {
                crewSnack(context, 'Couldn’t save the Show. Try again.');
              }
            }
          case 'report':
            if (context.mounted) await showReportSheet(context, post);
          case 'block':
            if (context.mounted) {
              await confirmBlock(context, ref, post.ownerId, post.stageName);
            }
        }
      },
      itemBuilder: (_) => post.mine
          ? const [
              PopupMenuItem(value: 'edit', child: Text('Edit Show')),
              PopupMenuItem(value: 'private', child: Text('Keep off the Crew')),
            ]
          : [
              const PopupMenuItem(
                value: 'report',
                child: Text('Report this Show'),
              ),
              PopupMenuItem(
                value: 'block',
                child: Text('Block ${post.stageName}'),
              ),
            ],
    );
  }
}

/// Blocks a runner after asking. True when they were blocked.
Future<bool> confirmBlock(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String name,
) async {
  final ok = await confirmCrew(
    context,
    title: 'Block $name?',
    body:
        '$name leaves your Crew. You won’t see each other’s Shows, and their '
        'invites won’t work for you. They aren’t told.',
    action: 'Block',
    destructive: true,
  );
  if (!ok) return false;
  try {
    await ref.read(crewControllerProvider.notifier).block(userId);
    if (context.mounted) crewSnack(context, '$name is blocked.');
    return true;
  } catch (_) {
    if (context.mounted) {
      crewSnack(context, 'Couldn’t reach the Crew. Try again.');
    }
    return false;
  }
}

const _reasons = [
  'Spam or fake',
  'Rude or hurtful',
  'Something unsafe',
  'Something else',
];

/// Report a Crew mate's Show: pick a reason, optionally block the runner too.
Future<void> showReportSheet(BuildContext context, CrewPost post) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ReportSheet(post: post),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.post});
  final CrewPost post;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String? _reason;
  bool _block = false;
  bool _sending = false;

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(crewControllerProvider.notifier)
          .report(widget.post, reason, block: _block);
      if (!mounted) return;
      Navigator.of(context).pop();
      crewSnack(context, 'Thanks. The Show is hidden from your feed.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      crewSnack(context, 'Couldn’t send the report. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.post.stageName;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'REPORT THIS SHOW',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'The app’s owner reads every report. The Show disappears from '
              'your feed right away.',
              style: TextStyle(color: StageColors.textMuted),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final r in _reasons)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: r,
                      title: Text(r),
                    ),
                ],
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _block,
              onChanged: (v) => setState(() => _block = v ?? false),
              title: Text('Also block $name'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _reason == null || _sending ? null : _send,
              child: Text(_sending ? 'Sending…' : 'Send report'),
            ),
          ],
        ),
      ),
    );
  }
}
