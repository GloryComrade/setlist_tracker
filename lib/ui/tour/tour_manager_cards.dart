import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../logic/tour_manager.dart';
import '../../models/tour.dart';
import '../../theme/app_theme.dart';

IconData _iconFor(SuggestionKind k) => switch (k) {
  SuggestionKind.missedShow => Icons.event_repeat,
  SuggestionKind.lighterWeek => Icons.battery_charging_full,
  SuggestionKind.fasterPaces => Icons.speed,
};

/// The Tour Manager's notes: suggestions (Apply / Not now) and the last few
/// changes the runner accepted. Renders nothing when there's nothing to say.
class TourManagerSection extends ConsumerWidget {
  const TourManagerSection({super.key, required this.tour, required this.now});

  final Tour tour;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shows = ref.watch(showsProvider).value ?? const [];
    final done = ref.watch(tourProgressProvider);
    final suggestions = tourSuggestions(
      tour,
      shows: shows,
      done: done,
      now: now,
    );
    final recent = tour.adjustments.reversed.take(3).toList();
    if (suggestions.isEmpty && recent.isEmpty) return const SizedBox.shrink();

    Future<void> save(Tour t) => ref.read(tourRepositoryProvider).save(t);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
          child: Text(
            'Tour Manager',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        for (final s in suggestions) ...[
          _SuggestionCard(
            suggestion: s,
            onApply: () async {
              await save(applySuggestion(tour, s, DateTime.now().toUtc()));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('The Tour is updated.')),
              );
            },
            onDismiss: () => save(dismissSuggestion(tour, s.key)),
          ),
          const SizedBox(height: 10),
        ],
        if (recent.isNotEmpty) _RecentChanges(adjustments: recent),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.onApply,
    required this.onDismiss,
  });

  final TourSuggestion suggestion;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
      decoration: BoxDecoration(
        color: StageColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StageColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _iconFor(suggestion.kind),
                size: 22,
                color: StageColors.magenta,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion.message,
                      style: const TextStyle(
                        color: StageColors.textMuted,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Lines the buttons up under the text, past the icon (the text
          // button's own padding makes up the rest).
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Wrap(
              spacing: 4,
              children: [
                TextButton(onPressed: onDismiss, child: const Text('Not now')),
                FilledButton(
                  onPressed: onApply,
                  child: Text(suggestion.applyLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentChanges extends StatelessWidget {
  const _RecentChanges({required this.adjustments});
  final List<TourAdjustment> adjustments;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECENT CHANGES',
            style: TextStyle(
              color: StageColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          for (final a in adjustments)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: StageColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a.note,
                      style: const TextStyle(
                        color: StageColors.textMuted,
                        fontSize: 13,
                      ),
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
