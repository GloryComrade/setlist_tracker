import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:material_ui/material_ui.dart';

import 'data/crew/crew_controller.dart';
import 'data/push/push_controller.dart';
import 'data/settings/app_settings.dart';
import 'data/sync/sync_controller.dart';
import 'models/tour.dart';
import 'theme/app_theme.dart';
import 'theme/stage_art.dart';
import 'ui/backstage/backstage_screen.dart';
import 'ui/backstage/saved_mix_screen.dart';
import 'ui/calendar/calendar_screen.dart';
import 'ui/charts/charts_screen.dart';
import 'ui/crew/crew_mate_screen.dart';
import 'ui/crew/crew_screen.dart';
import 'ui/crew/join_crew_screen.dart';
import 'ui/live_show/on_stage_screen.dart';
import 'ui/records/gold_records_screen.dart';
import 'ui/records/record_wall_screen.dart';
import 'ui/setlist/setlist_screen.dart';
import 'ui/show_detail/show_detail_screen.dart';
import 'ui/show_form/show_form_screen.dart';
import 'ui/tour/book_tour_screen.dart';
import 'ui/tour/planned_show_screen.dart';
import 'ui/settings/settings_button.dart';
import 'ui/settings/settings_screen.dart';
import 'ui/tour/tour_screen.dart';
import 'ui/widgets/stage_widgets.dart';

/// Every screen has a URL, so links work on web and deep links on iOS later.
final appRouter = GoRouter(
  initialLocation: '/setlist',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _TabShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/setlist', builder: (_, _) => const SetlistScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/tour', builder: (_, _) => const TourScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/charts', builder: (_, _) => const ChartsScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/crew', builder: (_, _) => const CrewScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/backstage',
              builder: (_, _) => const BackstageScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(
      path: '/show/new',
      builder: (_, state) => ShowFormScreen(
        plannedShowId: state.uri.queryParameters['plan'],
        fromRecording: state.uri.queryParameters['live'] == '1',
      ),
    ),
    GoRoute(path: '/live', builder: (_, _) => const OnStageScreen()),
    GoRoute(
      path: '/crew/join/:code',
      builder: (_, state) =>
          JoinCrewScreen(code: state.pathParameters['code']!),
    ),
    GoRoute(
      path: '/crew/mate/:userId',
      builder: (_, state) =>
          CrewMateScreen(userId: state.pathParameters['userId']!),
    ),
    GoRoute(
      path: '/tour/book',
      builder: (_, state) =>
          BookTourScreen(featuring: state.extra as TourFeaturing?),
    ),
    GoRoute(
      path: '/tour/show/:id',
      builder: (_, state) =>
          PlannedShowScreen(plannedShowId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/show/:id',
      builder: (_, state) =>
          ShowDetailScreen(showId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/show/:id/edit',
      builder: (_, state) =>
          ShowFormScreen(showId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/backstage/gold-records',
      builder: (_, _) => const GoldRecordsScreen(),
    ),
    GoRoute(
      path: '/backstage/record-wall',
      builder: (_, _) => const RecordWallScreen(),
    ),
    GoRoute(
      path: '/backstage/mix/new',
      builder: (_, _) => const SavedMixScreen(),
    ),
    GoRoute(
      path: '/backstage/mix/:id',
      builder: (_, state) => SavedMixScreen(mixId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/calendar',
      builder: (_, state) => CalendarScreen(
        initialMonth: CalendarScreen.parseMonth(
          state.uri.queryParameters['month'],
        ),
      ),
    ),
  ],
);

class SetlistApp extends ConsumerStatefulWidget {
  const SetlistApp({super.key});

  @override
  ConsumerState<SetlistApp> createState() => _SetlistAppState();
}

class _SetlistAppState extends ConsumerState<SetlistApp> {
  StreamSubscription<String>? _opens;

  @override
  void initState() {
    super.initState();
    // A tapped notification ("Maya played a Show") opens that runner's page.
    _opens = ref.read(pushBridgeProvider).opens.listen(appRouter.push);
  }

  @override
  void dispose() {
    _opens?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the Backstage Pass sync running whichever tab is open.
    ref.listen(syncControllerProvider, (_, _) {});
    // Keeps the Crew feed in step with the Setlist and each sync.
    ref.listen(crewControllerProvider, (_, _) {});
    // Reads the saved Settings at start, so every screen gets them.
    ref.listen(appSettingsProvider, (_, _) {});
    // Registers this phone for the Crew's notifications once allowed.
    ref.listen(pushControllerProvider, (_, _) {});
    return MaterialApp.router(
      title: 'Setlist Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      builder: (context, child) => _PrecacheArt(child: child!),
    );
  }
}

/// Decodes the venue prints once at start, so a Show poster opened later
/// paints with its print in the first frame.
class _PrecacheArt extends StatefulWidget {
  const _PrecacheArt({required this.child});
  final Widget child;

  @override
  State<_PrecacheArt> createState() => _PrecacheArtState();
}

class _PrecacheArtState extends State<_PrecacheArt> {
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    StageArt.precache(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Bottom bar on phones, side rail on wide screens.
class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});
  final StatefulNavigationShell shell;

  static const _tabs = [
    (
      icon: Icons.queue_music_outlined,
      active: Icons.queue_music,
      label: 'Setlist',
    ),
    (
      icon: Icons.confirmation_number_outlined,
      active: Icons.confirmation_number,
      label: 'Tour',
    ),
    (
      icon: Icons.leaderboard_outlined,
      active: Icons.leaderboard,
      label: 'The Charts',
    ),
    (icon: Icons.groups_outlined, active: Icons.groups, label: 'The Crew'),
    (
      icon: Icons.inventory_2_outlined,
      active: Icons.inventory_2,
      label: 'Backstage',
    ),
  ];

  /// Every tab's poster gets the Settings button at its top-right.
  static Widget _withSettings(Widget tab) =>
      PosterCornerAction(action: const SettingsAvatarButton(), child: tab);

  void _go(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final fab = shell.currentIndex == 0 ? const BookShowButton() : null;
    if (wide) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.mic, color: StageColors.amber, size: 32),
              ),
              destinations: [
                for (final t in _tabs)
                  NavigationRailDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.active),
                    label: Text(t.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: StageGrain(child: _withSettings(shell))),
          ],
        ),
      );
    }
    return Scaffold(
      floatingActionButton: fab,
      body: StageGrain(child: _withSettings(shell)),
      // Five tabs share a phone's width, so the labels keep their 100% size
      // at large text sizes (like iOS tab bars) instead of breaking mid-word.
      bottomNavigationBar: MediaQuery.withNoTextScaling(
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final t in _tabs)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.active),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}
