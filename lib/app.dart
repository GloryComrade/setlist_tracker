import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'data/crew/crew_controller.dart';
import 'data/sync/sync_controller.dart';
import 'theme/app_theme.dart';
import 'ui/backstage/backstage_screen.dart';
import 'ui/backstage/saved_mix_screen.dart';
import 'ui/charts/charts_screen.dart';
import 'ui/crew/crew_screen.dart';
import 'ui/crew/join_crew_screen.dart';
import 'ui/records/gold_records_screen.dart';
import 'ui/records/record_wall_screen.dart';
import 'ui/setlist/setlist_screen.dart';
import 'ui/show_detail/show_detail_screen.dart';
import 'ui/show_form/show_form_screen.dart';
import 'ui/tour/book_tour_screen.dart';
import 'ui/tour/planned_show_screen.dart';
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
    GoRoute(
      path: '/show/new',
      builder: (_, state) =>
          ShowFormScreen(plannedShowId: state.uri.queryParameters['plan']),
    ),
    GoRoute(
      path: '/crew/join/:code',
      builder: (_, state) =>
          JoinCrewScreen(code: state.pathParameters['code']!),
    ),
    GoRoute(path: '/tour/book', builder: (_, _) => const BookTourScreen()),
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
  ],
);

class SetlistApp extends ConsumerWidget {
  const SetlistApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the Backstage Pass sync running whichever tab is open.
    ref.listen(syncControllerProvider, (_, _) {});
    // Keeps shared Shows in step with the Setlist.
    ref.listen(crewControllerProvider, (_, _) {});
    return MaterialApp.router(
      title: 'Setlist Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
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
                child: Icon(Icons.mic, color: StageColors.magenta, size: 32),
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
            Expanded(child: StageGlow(child: shell)),
          ],
        ),
      );
    }
    return Scaffold(
      floatingActionButton: fab,
      body: StageGlow(child: shell),
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
