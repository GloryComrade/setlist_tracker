import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../logic/show_math.dart';
import '../../logic/spoken.dart';
import '../../models/crew.dart';
import '../../theme/app_theme.dart';
import '../widgets/album_art.dart';
import '../widgets/open_link.dart';
import '../widgets/stage_widgets.dart';
import 'crew_widgets.dart';

/// A shared Show on the Crew feed: the Setlist's ticket stub, signed by the
/// runner who shared it, with an Encore to cheer it.
class CrewPostCard extends ConsumerWidget {
  const CrewPostCard({super.key, required this.post, this.now});
  final CrewPost post;

  /// For tests; defaults to the clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = post.show;
    final song = s.song;
    final who = post.mine ? 'You' : post.stageName;

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
                      Row(
                        children: [
                          CrewAvatar(
                            name: post.stageName,
                            color: post.color,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              who,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sharedAgo(post.sharedAt, now: now),
                            style: const TextStyle(
                              fontSize: 13,
                              color: StageColors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          _PostMenu(post: post),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Spoken with the numbers below, as one line.
                      ExcludeSemantics(
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
                                  formatPace(
                                    paceSecondsPerMileFor(
                                      s.distanceMiles,
                                      s.durationSeconds,
                                    ),
                                  ),
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
                      if (song != null) ...[
                        const SizedBox(height: 8),
                        _SongLine(post: post),
                      ],
                      if (s.goldRecords.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final r in s.goldRecords) _GoldBadge(r),
                          ],
                        ),
                      ],
                      if (s.notes != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            s.notes!,
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
        AlbumArt(
          url: song.albumArtUrl,
          size: 36,
          radius: 6,
          title: song.title,
          artist: song.artist,
        ),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: StageColors.amber,
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
          case 'unshare':
            final ok = await confirmCrew(
              context,
              title: 'Stop sharing this Show?',
              body:
                  'It leaves your Crew’s feed, with its Encores. It stays on '
                  'your Setlist.',
              action: 'Stop sharing',
            );
            if (!ok) return;
            try {
              await c.unshare(post.showId);
            } catch (_) {
              if (context.mounted) {
                crewSnack(context, 'Couldn’t reach the Crew. Try again.');
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
          ? const [PopupMenuItem(value: 'unshare', child: Text('Stop sharing'))]
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

/// Report a shared Show: pick a reason, optionally block the runner too.
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
