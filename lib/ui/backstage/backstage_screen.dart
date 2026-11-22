import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../logic/show_math.dart';
import '../../models/gear.dart';
import '../../models/saved_mix.dart';
import '../../theme/app_theme.dart';
import '../records/records_entry.dart';
import '../widgets/stage_widgets.dart';
import 'gear_dialog.dart';

/// Backstage: Gold Records, The Record Wall, your Gear and your Saved Mixes.
class BackstageScreen extends ConsumerWidget {
  const BackstageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gear = ref.watch(gearListProvider).value ?? const <Gear>[];
    final miles = ref.watch(gearMilesProvider);
    final mixes = ref.watch(savedMixesProvider).value ?? const <SavedMix>[];
    final active = gear.where((g) => !g.retired).toList();
    final retired = gear.where((g) => g.retired).toList();

    Future<void> addGear() async {
      final g = await showGearDialog(context);
      if (g != null) await ref.read(gearRepositoryProvider).save(g);
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PosterHeader(title: 'BACKSTAGE'),
                  const SizedBox(height: 16),
                  const RecordsEntry(),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Gear',
                    trailing: TextButton.icon(
                      onPressed: addGear,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                    child: gear.isEmpty
                        ? const Text(
                            'Add your shoes and every Show will add to their miles.',
                            style: TextStyle(color: StageColors.textMuted),
                          )
                        : Column(
                            children: [
                              for (final g in active)
                                _GearTile(gear: g, miles: miles[g.id] ?? 0),
                              if (retired.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(0, 12, 0, 4),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'RETIRED',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        fontSize: 12,
                                        color: StageColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                                for (final g in retired)
                                  _GearTile(gear: g, miles: miles[g.id] ?? 0),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Saved Mixes',
                    trailing: TextButton.icon(
                      onPressed: () => context.push('/backstage/mix/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                    child: mixes.isEmpty
                        ? const Text(
                            'A Saved Mix is a treadmill setup you can load into a '
                            'Studio Session in one tap.',
                            style: TextStyle(color: StageColors.textMuted),
                          )
                        : Column(
                            children: [for (final m in mixes) _MixTile(mix: m)],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GearTile extends ConsumerWidget {
  const _GearTile({required this.gear, required this.miles});
  final Gear gear;
  final double miles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(gearRepositoryProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: gear.retired ? StageColors.outline : StageColors.amber,
        child: Icon(
          Icons.directions_run,
          color: gear.retired ? StageColors.textMuted : Colors.black,
        ),
      ),
      title: Text(
        gear.displayName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(formatMiles(miles)),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          switch (action) {
            case 'edit':
              final g = await showGearDialog(context, existing: gear);
              if (g != null) await repo.save(g);
            case 'retire':
              await repo.save(gear.copyWith(retired: !gear.retired));
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(
            value: 'retire',
            child: Text(gear.retired ? 'Bring out of retirement' : 'Retire'),
          ),
        ],
      ),
    );
  }
}

class _MixTile extends StatelessWidget {
  const _MixTile({required this.mix});
  final SavedMix mix;

  @override
  Widget build(BuildContext context) {
    final t = mix.totals;
    final where = [
      mix.gymName,
      mix.treadmillName,
    ].whereType<String>().join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => context.push('/backstage/mix/${mix.id}'),
      leading: const CircleAvatar(
        backgroundColor: StageColors.violetDeep,
        child: Icon(Icons.album, color: Colors.white),
      ),
      title: Text(
        mix.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          '${mix.tracks.length} Tracks',
          formatDuration(t.durationSeconds),
          formatMiles(t.distanceMiles),
          if (where.isNotEmpty) where,
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
