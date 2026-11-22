import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../logic/gold_records.dart';
import '../../models/show.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';
import 'gold_disc.dart';

final _showDay = DateFormat('EEE, MMM d, y');
final _weekDay = DateFormat('MMM d, y');
final _month = DateFormat('MMMM y');

/// A record set in the last two weeks gets a "NEW" stamp.
const _freshFor = Duration(days: 14);

/// Gold Records: personal records from every logged Show.
class GoldRecordsScreen extends ConsumerStatefulWidget {
  const GoldRecordsScreen({super.key});

  @override
  ConsumerState<GoldRecordsScreen> createState() => _GoldRecordsScreenState();
}

class _GoldRecordsScreenState extends ConsumerState<GoldRecordsScreen> {
  RecordScope _scope = RecordScope.all;

  @override
  Widget build(BuildContext context) {
    final showsAsync = ref.watch(showsProvider);
    return Scaffold(
      appBar: AppBar(leading: backButtonFor(context, fallback: '/backstage')),
      body: showsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load your Shows: $e')),
        data: (shows) => _body(context, shows),
      ),
    );
  }

  Widget _body(BuildContext context, List<Show> shows) {
    final records = computeGoldRecords(shows, scope: _scope);
    final kinds = RecordKind.values.where((k) => k.appliesTo(_scope)).toList();
    final pressed = kinds.where(records.containsKey).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        MaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FoilHeader(pressed: pressed, total: kinds.length),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in RecordScope.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s.label),
                          selected: _scope == s,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _scope = s),
                        ),
                      ),
                  ],
                ),
              ),
              for (final group in RecordGroup.values) ...[
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    group.label.toUpperCase(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, kind)
                          in kinds.where((k) => k.group == group).indexed) ...[
                        if (i > 0) const Divider(height: 1, indent: 72),
                        _RecordRow(kind: kind, record: records[kind]),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Race times use a Show’s average pace, worked out to the race '
                  'distance. The app logs one distance and time per Show, so '
                  'these are estimates, not split times.',
                  style: TextStyle(
                    color: StageColors.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FoilHeader extends StatelessWidget {
  const _FoilHeader({required this.pressed, required this.total});
  final int pressed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = pressed == 0
        ? 'Every Show you log can press a record.'
        : pressed == total
        ? 'All $total records pressed.'
        : '$pressed of $total records pressed.';
    return PosterSurface.foil(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GOLD RECORDS',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: GoldColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  line,
                  style: const TextStyle(
                    color: GoldColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const GoldDisc(size: 64),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.kind, required this.record});
  final RecordKind kind;
  final GoldRecord? record;

  String _when(GoldRecord r) => switch (r.kind) {
    RecordKind.biggestWeek => 'Week of ${_weekDay.format(r.date)}',
    RecordKind.biggestMonth => _month.format(r.date),
    _ => _showDay.format(r.date),
  };

  @override
  Widget build(BuildContext context) {
    final r = record;
    final theme = Theme.of(context);
    final titleStyle = const TextStyle(
      fontWeight: FontWeight.w700,
      color: StageColors.text,
    );
    const muted = TextStyle(color: StageColors.textMuted, fontSize: 13);

    if (r == null) {
      return Semantics(
        label: '${kind.title}: not pressed yet. ${kind.howToSet}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              const GoldDisc(size: 40, pressed: false),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.title,
                      style: titleStyle.copyWith(color: StageColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text('Not pressed yet. ${kind.howToSet}', style: muted),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final fresh = DateTime.now().difference(r.date) < _freshFor;
    final show = r.show;
    return Semantics(
      button: show != null,
      label:
          '${kind.title}: ${r.value}. ${r.detail ?? ''} ${_when(r)}'
          '${fresh ? '. New' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: show == null ? null : () => context.push('/show/${show.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              const GoldDisc(size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(kind.title, style: titleStyle)),
                        if (fresh) ...[
                          const SizedBox(width: 8),
                          const _NewStamp(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.value,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: GoldColors.mid,
                        fontFeatures: StageFonts.tabular,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [r.detail, _when(r)].whereType<String>().join(' · '),
                      style: muted,
                    ),
                  ],
                ),
              ),
              if (show != null)
                const Icon(Icons.chevron_right, color: StageColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewStamp extends StatelessWidget {
  const _NewStamp();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: StageColors.amber,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      'NEW',
      style: TextStyle(
        color: StageColors.goldInk,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
  );
}
