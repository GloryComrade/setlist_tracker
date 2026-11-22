import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../logic/gold_records.dart';
import '../../models/crew.dart';
import '../../models/show.dart';
import '../../theme/app_theme.dart';
import '../tour/tour_widgets.dart' show today;
import '../widgets/stage_widgets.dart';
import 'crew_post_card.dart';
import 'crew_widgets.dart';
import 'mate_tour_card.dart';

/// A Crew mate's page (`/crew/mate/:userId`): who they are, their Tour and
/// current week, their Gold Records and their whole Setlist. Read-only.
class CrewMateScreen extends ConsumerWidget {
  const CrewMateScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crew = ref.watch(crewControllerProvider);
    final async = ref.watch(crewMateProvider(userId));
    final Widget body;
    if (!crew.signedIn || (crew.loaded && crew.profile == null)) {
      body = const _Message(
        child: EmptyStage(
          icon: Icons.groups_outlined,
          title: 'Join the Crew',
          message: 'Sign in and pick a stage name to see your Crew’s Shows.',
        ),
      );
    } else {
      body = async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          child: EmptyStage(
            icon: Icons.cloud_off_outlined,
            title: 'Can’t reach the Crew',
            message: '$e',
            actionLabel: 'Try again',
            actionIcon: Icons.refresh,
            onAction: () => ref.invalidate(crewMateProvider(userId)),
          ),
        ),
        data: (detail) => detail == null
            ? const _Message(
                child: EmptyStage(
                  icon: Icons.groups_outlined,
                  title: 'Not in your Crew',
                  message:
                      'Only runners in your Crew can see each other’s Shows.',
                ),
              )
            : _MatePage(detail: detail, crew: crew),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: backButtonFor(context, fallback: '/crew'),
        title: const Text('THE CREW'),
      ),
      body: body,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(child: MaxWidth(child: child)),
  );
}

class _MatePage extends ConsumerWidget {
  const _MatePage({required this.detail, required this.crew});
  final CrewMateDetail detail;
  final CrewState crew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The mates list carries the Tour summary; the page carries the Tour.
    final listed = crew.mates
        .where((m) => m.userId == detail.mate.userId)
        .firstOrNull;
    final tour = detail.tour;
    final mate = CrewMate(
      userId: detail.mate.userId,
      stageName: detail.mate.stageName,
      color: detail.mate.color,
      since: listed?.since ?? detail.mate.since,
      tour: tour == null ? listed?.tour : CrewTourSummary.fromTour(tour),
    );
    final isMe = mate.userId == crew.profile?.userId;
    final posts = detail.shows;
    final shows = [for (final p in posts) p.show];
    final records = computeGoldRecords(shows);
    final byShow = <String, List<String>>{};
    for (final r in records.values) {
      final id = r.show?.id;
      if (id != null) byShow.putIfAbsent(id, () => []).add(r.kind.title);
    }
    final progress = tour == null
        ? null
        : CrewWeekProgress.of(tour, shows, today());

    final header = <Widget>[
      _Poster(mate: mate, shows: shows, isMe: isMe),
      if (mate.tour != null) ...[
        const SizedBox(height: 12),
        SectionCard(
          title: 'The Tour',
          child: isMe
              ? _OwnTour(progress: progress, mate: mate)
              : MateTourCard(mate: mate, progress: progress),
        ),
      ],
      if (records.isNotEmpty) ...[
        const SizedBox(height: 12),
        SectionCard(
          title: 'Gold Records',
          child: _RecordList(records: records),
        ),
      ],
      const SizedBox(height: 24),
      if (posts.isEmpty)
        EmptyStage(
          icon: Icons.queue_music_outlined,
          title: 'No Shows yet',
          message: isMe
              ? 'Shows you log land here for your Crew.'
              : 'When ${mate.stageName} logs a Show, it lands here.',
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: CrewLabel(isMe ? 'Your Setlist' : 'The Setlist'),
        ),
    ];

    return RefreshIndicator(
      onRefresh: () => ref.refresh(crewMateProvider(mate.userId).future),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: header.length + posts.length,
        itemBuilder: (context, i) => MaxWidth(
          child: i < header.length
              ? header[i]
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CrewPostCard(
                    post: posts[i - header.length],
                    showOwner: false,
                    goldRecords:
                        byShow[posts[i - header.length].showId] ?? const [],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.mate, required this.shows, required this.isMe});
  final CrewMate mate;
  final List<Show> shows;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final miles = shows.fold<double>(0, (t, s) => t + s.distanceMiles);
    final white = theme.textTheme.headlineSmall?.copyWith(
      color: Colors.white,
      fontFeatures: StageFonts.tabular,
    );
    const label = TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    );
    return PosterSurface(
      gradient: StageColors.headlineGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CrewAvatar(
              name: mate.stageName,
              color: mate.color,
              size: 56,
            ),
          ),
          const SizedBox(height: 12),
          WholeWordsText(
            mate.stageName.toUpperCase(),
            style: theme.textTheme.displayMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            isMe
                ? 'What your Crew sees'
                : 'In your Crew since ${formatShowDay(mate.since.toLocal())}',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 10,
            children: [
              Semantics(
                container: true,
                label: '${shows.length} Shows',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SHOWS', style: label),
                      Text('${shows.length}', style: white),
                    ],
                  ),
                ),
              ),
              Semantics(
                container: true,
                label: '${miles.toStringAsFixed(1)} miles',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MILES', style: label),
                      Text('${miles.toStringAsFixed(1)} mi', style: white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Your own page: your Tour, without a button to feature yourself.
class _OwnTour extends StatelessWidget {
  const _OwnTour({required this.progress, required this.mate});
  final CrewWeekProgress? progress;
  final CrewMate mate;

  @override
  Widget build(BuildContext context) {
    final tour = mate.tour!;
    final p = progress;
    return Text(
      [
        tour.name,
        if (p != null) 'Week ${p.week.number}: ${weekProgressLine(p)}',
      ].join('\n'),
      style: const TextStyle(height: 1.4),
    );
  }
}

/// Records they hold, as small gold-edged rows: title, then the number.
class _RecordList extends StatelessWidget {
  const _RecordList({required this.records});
  final Map<RecordKind, GoldRecord> records;

  @override
  Widget build(BuildContext context) {
    final list = [for (final k in RecordKind.values) ?records[k]];
    return Column(
      children: [
        for (final r in list)
          Semantics(
            container: true,
            label: 'Gold Record: ${r.kind.title}, ${r.value}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.album, size: 18, color: StageColors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.kind.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            formatShowDay(r.date),
                            style: const TextStyle(
                              fontSize: 13,
                              color: StageColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      r.value,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: StageColors.amber,
                            fontFeatures: StageFonts.tabular,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
