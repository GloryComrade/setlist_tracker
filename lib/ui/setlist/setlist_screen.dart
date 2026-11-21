import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../logic/show_math.dart';
import '../../models/enums.dart';
import '../../models/show.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';
import 'show_card.dart';

/// Which Shows the Setlist is showing.
enum SetlistFilter { all, studio, live }

final setlistFilterProvider =
    NotifierProvider<SetlistFilterNotifier, SetlistFilter>(
      SetlistFilterNotifier.new,
    );

class SetlistFilterNotifier extends Notifier<SetlistFilter> {
  @override
  SetlistFilter build() => SetlistFilter.all;
  void set(SetlistFilter f) => state = f;
}

/// Home screen: every Show, newest first, grouped by week.
class SetlistScreen extends ConsumerWidget {
  const SetlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showsAsync = ref.watch(showsProvider);
    final filter = ref.watch(setlistFilterProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/show/new'),
        icon: const Icon(Icons.add),
        label: const Text(
          'Book a Show',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: showsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Could not load the Setlist: $e')),
          data: (shows) {
            final visible = switch (filter) {
              SetlistFilter.all => shows,
              SetlistFilter.studio =>
                shows.where((s) => s.venue == Venue.studio).toList(),
              SetlistFilter.live =>
                shows.where((s) => s.venue == Venue.live).toList(),
            };
            return MaxWidth(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    sliver: SliverToBoxAdapter(child: _Header(shows: shows)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _FilterChips(
                        value: filter,
                        onChanged: (f) =>
                            ref.read(setlistFilterProvider.notifier).set(f),
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(filtered: shows.isNotEmpty),
                    )
                  else
                    ..._weekSlivers(visible),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _weekSlivers(List<Show> shows) {
    final weeks = <DateTime, List<Show>>{};
    for (final s in shows) {
      weeks.putIfAbsent(weekStart(s.date), () => []).add(s);
    }
    final fmt = DateFormat('MMM d');
    return [
      for (final entry in weeks.entries) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'WEEK OF ${fmt.format(entry.key).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: StageColors.textMuted,
                    ),
                  ),
                ),
                Text(
                  formatMiles(
                    entry.value.fold<double>(
                      0,
                      (sum, s) => sum + s.distanceMiles,
                    ),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: StageColors.amber,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: entry.value.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => ShowCard(show: entry.value[i]),
          ),
        ),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.shows});
  final List<Show> shows;

  @override
  Widget build(BuildContext context) {
    final thisWeek = weekStart(DateTime.now());
    final weekShows = shows.where((s) => !s.date.isBefore(thisWeek)).toList();
    final miles = weekShows.fold<double>(0, (sum, s) => sum + s.distanceMiles);
    final n = weekShows.length;
    return PosterHeader(
      title: 'THE SETLIST',
      children: [
        const SizedBox(height: 8),
        Text(
          shows.isEmpty
              ? 'Every run is a Show. Book your first one.'
              : '${formatMiles(miles)} this week across $n '
                    '${n == 1 ? 'Show' : 'Shows'}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFeatures: StageFonts.tabular,
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});
  final SetlistFilter value;
  final ValueChanged<SetlistFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      SetlistFilter.all: 'All Shows',
      SetlistFilter.studio: 'Studio Sessions',
      SetlistFilter.live: 'Live Shows',
    };
    // One row that scrolls sideways on narrow phones instead of wrapping.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in SetlistFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labels[f]!),
                selected: value == f,
                showCheckmark: false,
                onSelected: (_) => onChanged(f),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.queue_music, size: 64, color: StageColors.textMuted),
          const SizedBox(height: 12),
          Text(
            filtered ? 'NO SHOWS LIKE THAT YET' : 'NO SHOWS YET',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            filtered
                ? 'Try another filter.'
                : 'Book your first one and start the Setlist.',
            style: const TextStyle(color: StageColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
