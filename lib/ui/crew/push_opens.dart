import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/push/push_controller.dart';

/// Opens The Crew when a Crew notification is tapped (also the one that
/// launched the app). Sits above the router, so it is handed the router.
class PushOpens extends ConsumerWidget {
  const PushOpens({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(pushControllerProvider.select((s) => s.opens), (before, now) {
      if (now > (before ?? 0)) router.go('/crew');
    });
    return child;
  }
}
