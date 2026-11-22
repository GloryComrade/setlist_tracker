import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_version.dart';
import '../../data/crew/crew_controller.dart';
import '../../data/providers.dart';
import '../../data/remote/backend_config.dart';
import '../../data/settings/app_settings.dart';
import '../../models/crew.dart';
import '../../models/tour.dart';
import '../../theme/app_theme.dart';
import '../backstage/backstage_pass_card.dart';
import '../crew/crew_sheets.dart';
import '../crew/crew_widgets.dart';
import '../tour/tour_widgets.dart';
import '../widgets/open_link.dart';
import '../widgets/stage_widgets.dart';
import 'profile_picture.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Settings (`/settings`), opened from the picture at the top-right of
/// every tab. Your profile and Crew live on the server; everything else
/// stays on this device ([appSettingsProvider]).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crew = ref.watch(crewControllerProvider);
    final health = ref.watch(healthSourceProvider).available;
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(
        leading: backButtonFor(context),
        title: const Text('SETTINGS'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileSection(crew: crew),
                  if (crew.profile != null) ...[gap, _CrewSection(crew: crew)],
                  gap,
                  const _TourSection(),
                  gap,
                  const _SongSection(),
                  if (health) ...[gap, const _HealthSection()],
                  gap,
                  const BackstagePassCard(),
                  gap,
                  const _AboutSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Your profile ----

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection({required this.crew});
  final CrewState crew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = crew.profile;
    if (!crew.available) {
      return const SectionCard(
        title: 'Your profile',
        child: _Muted(
          'Your stage name and picture come with the Backstage Pass, which '
          'isn’t on this version yet.',
        ),
      );
    }
    if (!crew.signedIn) {
      return const SectionCard(
        title: 'Your profile',
        child: _Muted(
          'Sign in with your Backstage Pass below to pick a stage name and a '
          'picture for your Crew.',
        ),
      );
    }
    if (p == null) {
      if (!crew.loaded) {
        return const SectionCard(
          title: 'Your profile',
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return const SectionCard(
        title: 'Your profile',
        child: StageNameForm(buttonLabel: 'Save stage name'),
      );
    }
    return SectionCard(
      title: 'Your profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CrewAvatar(
                name: p.stageName,
                color: p.color,
                size: 64,
                badge: p.avatarBadge,
                photoUrl: p.avatarUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.stageName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Text(
                      'How your Crew sees you.',
                      style: TextStyle(color: StageColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SubHead('Picture'),
          const SizedBox(height: 10),
          ProfilePicturePicker(profile: p),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          StageNameForm(
            existing: p,
            buttonLabel: 'Save name and color',
            onSaved: () => crewSnack(context, 'Stage name saved.'),
          ),
        ],
      ),
    );
  }
}

// ---- The Crew ----

class _CrewSection extends ConsumerWidget {
  const _CrewSection({required this.crew});
  final CrewState crew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final c = ref.read(crewControllerProvider.notifier);
    return SectionCard(
      title: 'The Crew',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Switch(
            value: settings.newShowsOffCrew,
            title: 'Keep new Shows off the Crew',
            subtitle: settings.newShowsOffCrew
                ? 'New Shows start kept to yourself. Turn it off on any Show '
                      'to share it.'
                : crew.allActivityPending
                ? kCrewSeesShared
                : kCrewSeesEverything,
            onChanged: (v) => ref
                .read(appSettingsProvider.notifier)
                .update((s) => s.copyWith(newShowsOffCrew: v)),
          ),
          if (crew.allActivityPending) ...[
            const Divider(height: 24),
            const _Muted(
              'Your Crew sees only the Shows you shared. Let them see every '
              'Show you log from now on? Shows from before stay hidden.',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () async {
                  try {
                    await c.acceptAllActivity();
                    if (context.mounted) {
                      crewSnack(context, 'Your Crew sees every Show now.');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      crewSnack(context, 'Couldn’t reach the Crew.');
                    }
                  }
                },
                child: const Text('Let them see every Show'),
              ),
            ),
          ],
          const Divider(height: 24),
          _SubHead('Blocked runners'),
          const SizedBox(height: 4),
          if (crew.blocked.isEmpty)
            const _Muted('Nobody. Block someone from their Crew card.')
          else
            for (final m in crew.blocked)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CrewAvatar(name: m.stageName, color: m.color),
                title: Text(m.stageName),
                trailing: TextButton(
                  onPressed: () => _unblock(context, c, m),
                  child: const Text('Unblock'),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _unblock(
    BuildContext context,
    CrewController c,
    CrewMate m,
  ) async {
    try {
      await c.unblock(m);
      if (context.mounted) {
        crewSnack(
          context,
          '${m.stageName} is unblocked. Send a new invite to be Crew again.',
        );
      }
    } catch (_) {
      if (context.mounted) crewSnack(context, 'Couldn’t reach the Crew.');
    }
  }
}

// ---- The Tour ----

class _TourSection extends ConsumerWidget {
  const _TourSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider);
    final c = ref.read(appSettingsProvider.notifier);
    return SectionCard(
      title: 'The Tour',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Muted('Book The Tour starts with these answers.'),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: s.headlinerWeekday,
            decoration: const InputDecoration(labelText: 'Headliner day'),
            items: [
              for (var i = 0; i < 7; i++)
                DropdownMenuItem(value: i + 1, child: Text(_weekdays[i])),
            ],
            onChanged: (v) {
              if (v != null) c.update((s) => s.copyWith(headlinerWeekday: v));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<VenuePreference?>(
            initialValue: s.tourVenue,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Studio or Live'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Ask me')),
              for (final v in VenuePreference.values)
                DropdownMenuItem(value: v, child: Text(v.label)),
            ],
            onChanged: (v) => c.update(
              (s) => v == null
                  ? s.copyWith(clearTourVenue: true)
                  : s.copyWith(tourVenue: v),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Song of the Show ----

class _SongSection extends ConsumerWidget {
  const _SongSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appSettingsProvider.select((s) => s.musicApp));
    return SectionCard(
      title: 'Song of the Show',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Muted('Open songs in'),
          const SizedBox(height: 10),
          SegmentedButton<MusicApp>(
            showSelectedIcon: false,
            segments: [
              for (final a in MusicApp.values)
                ButtonSegment(value: a, label: Text(a.label)),
            ],
            selected: {app},
            onSelectionChanged: (v) => ref
                .read(appSettingsProvider.notifier)
                .update((s) => s.copyWith(musicApp: v.first)),
          ),
        ],
      ),
    );
  }
}

// ---- Apple Health (iPhone only) ----

class _HealthSection extends ConsumerWidget {
  const _HealthSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(appSettingsProvider.select((s) => s.healthImport));
    return SectionCard(
      title: 'Apple Health',
      child: _Switch(
        value: on,
        title: 'Import runs from Apple Health',
        subtitle: on
            ? 'The Import runs button is in Backstage.'
            : 'Off. Backstage won’t offer the import.',
        onChanged: (v) => ref
            .read(appSettingsProvider.notifier)
            .update((s) => s.copyWith(healthImport: v)),
      ),
    );
  }
}

// ---- About ----

/// A page on the website, or null in a local-only iPhone build.
Uri? sitePage(String name) {
  final base = apiBaseUrl;
  if (base != null) return Uri.parse('$base/$name');
  if (kIsWeb) return Uri.base.resolve(name);
  return null;
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final privacy = sitePage('privacy.html');
    final support = sitePage('support.html');
    return SectionCard(
      title: 'About',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (privacy != null)
            _LinkRow(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy policy',
              onTap: () => openLink(context, privacy),
            ),
          if (support != null)
            _LinkRow(
              icon: Icons.help_outline,
              label: 'Support',
              onTap: () => openLink(context, support),
            ),
          if (privacy != null || support != null) const SizedBox(height: 12),
          const TourDisclaimer(),
          const SizedBox(height: 12),
          const Text(
            'Setlist Tracker $kAppVersion',
            style: TextStyle(
              color: StageColors.textMuted,
              fontFeatures: StageFonts.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Pieces ----

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: StageColors.textMuted),
    title: Text(label),
    trailing: const Icon(Icons.open_in_new, size: 18),
    onTap: onTap,
  );
}

class _SubHead extends StatelessWidget {
  const _SubHead(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: StageColors.textMuted, height: 1.4),
  );
}

/// A switch row that reads at rest on a card (grey outline and thumb when
/// off), like the Book a Show form's.
class _Switch extends StatelessWidget {
  const _Switch({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    value: value,
    onChanged: onChanged,
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.selected) ? null : StageColors.textMuted,
    ),
    thumbColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.selected) ? null : StageColors.textMuted,
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
  );
}
