import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../data/crew/crew_service.dart';
import '../../models/crew.dart';
import '../../theme/app_theme.dart';
import '../widgets/stage_widgets.dart';
import 'crew_widgets.dart';

/// Which list the audience sheet opens on.
enum AudienceTab { encores, seenBy }

/// Who gave [post] an Encore and, on your own Show, who saw it.
Future<void> showAudienceSheet(
  BuildContext context,
  CrewPost post, {
  AudienceTab initial = AudienceTab.encores,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => AudienceSheet(post: post, initial: initial),
);

/// "Seen by Maya, Sam +2": the names first, then how many more.
String seenByText(CrewSeenSummary s) {
  final names = s.names.take(s.count).toList();
  if (names.isEmpty) return 'Seen by ${s.count} of your Crew';
  final more = s.count - names.length;
  return 'Seen by ${names.join(', ')}${more > 0 ? ' +$more' : ''}';
}

String _spokenSeenBy(CrewSeenSummary s) {
  final names = s.names.take(s.count).toList();
  if (names.isEmpty) return 'Seen by ${s.count} of your Crew';
  final more = s.count - names.length;
  if (more > 0) return 'Seen by ${names.join(', ')} and $more more';
  if (names.length == 1) return 'Seen by ${names.single}';
  return 'Seen by ${names.sublist(0, names.length - 1).join(', ')} '
      'and ${names.last}';
}

/// The quiet "Seen by Maya, Sam +2" line under your own Show's Encores.
/// Opens the audience sheet on Seen by. Nothing when nobody has seen it.
class SeenByLine extends StatelessWidget {
  const SeenByLine({super.key, required this.post});
  final CrewPost post;

  @override
  Widget build(BuildContext context) {
    final s = post.seenBy;
    if (s == null || s.count <= 0) return const SizedBox.shrink();
    return Semantics(
      container: true,
      button: true,
      label: '${_spokenSeenBy(s)}. See who.',
      excludeSemantics: true,
      onTap: () =>
          showAudienceSheet(context, post, initial: AudienceTab.seenBy),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () =>
            showAudienceSheet(context, post, initial: AudienceTab.seenBy),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: StageColors.textMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    seenByText(s),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: StageColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AudienceSheet extends ConsumerStatefulWidget {
  const AudienceSheet({
    super.key,
    required this.post,
    this.initial = AudienceTab.encores,
  });
  final CrewPost post;
  final AudienceTab initial;

  @override
  ConsumerState<AudienceSheet> createState() => _AudienceSheetState();
}

class _AudienceSheetState extends ConsumerState<AudienceSheet>
    with SingleTickerProviderStateMixin {
  late Future<CrewAudience> _audience = _load();
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.post.mine && widget.initial == AudienceTab.seenBy
        ? 1
        : 0,
  )..addListener(() => setState(() {}));

  Future<CrewAudience> _load() =>
      ref.read(crewControllerProvider.notifier).audience(widget.post);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _open(CrewPerson p) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/crew/mate/${p.userId}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = widget.post.mine;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: FutureBuilder<CrewAudience>(
          future: _audience,
          builder: (context, snap) {
            final a = snap.data;
            final Widget body;
            if (snap.hasError) {
              body = _Error(
                message: snap.error is CrewException
                    ? '${snap.error}'
                    : 'Couldn’t reach the Crew. Check your connection.',
                onRetry: () => setState(() => _audience = _load()),
              );
            } else if (a == null) {
              body = const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading the audience',
                  ),
                ),
              );
            } else if (mine && _tabs.index == 1) {
              body = _SeenByList(
                people: a.seenBy ?? const [],
                encored: {for (final p in a.encores) p.userId},
                onOpen: _open,
              );
            } else {
              body = _EncoreList(audience: a, mine: mine, onOpen: _open);
            }
            final seen = a?.seenBy?.length ?? widget.post.seenBy?.count;
            final cheers = a == null
                ? widget.post.encores
                : a.encores.length + a.otherEncores;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      mine ? 'THE AUDIENCE' : 'ENCORES',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ),
                if (mine)
                  TabBar(
                    controller: _tabs,
                    indicatorColor: StageColors.amber,
                    labelColor: StageColors.text,
                    unselectedLabelColor: StageColors.textMuted,
                    tabs: [
                      Tab(text: 'Encores · $cheers'),
                      Tab(text: seen == null ? 'Seen by' : 'Seen by · $seen'),
                    ],
                  ),
                Flexible(child: body),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: StageColors.textMuted, height: 1.4),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class _EncoreList extends StatelessWidget {
  const _EncoreList({
    required this.audience,
    required this.mine,
    required this.onOpen,
  });
  final CrewAudience audience;
  final bool mine;
  final void Function(CrewPerson) onOpen;

  @override
  Widget build(BuildContext context) {
    final people = audience.encores;
    final others = audience.otherEncores;
    if (people.isEmpty && others == 0) {
      return SingleChildScrollView(
        child: EmptyStage(
          icon: Icons.celebration_outlined,
          title: 'No Encores yet',
          message: mine
              ? 'When your Crew cheers this Show, they show up here.'
              : 'Be the first to give this Show an Encore.',
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final p in people) _PersonRow(person: p, onOpen: onOpen),
        if (others > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              people.isEmpty
                  ? '$others ${others == 1 ? 'Encore' : 'Encores'} from '
                        'outside your Crew'
                  : 'and $others more outside your Crew',
              style: const TextStyle(color: StageColors.textMuted),
            ),
          ),
      ],
    );
  }
}

class _SeenByList extends StatelessWidget {
  const _SeenByList({
    required this.people,
    required this.encored,
    required this.onOpen,
  });
  final List<CrewPerson> people;
  final Set<String> encored;
  final void Function(CrewPerson) onOpen;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyStage(
          icon: Icons.visibility_outlined,
          title: 'No one yet',
          message:
              'Crew mates who catch this Show show up here. Only you see '
              'this list.',
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final p in people)
          _PersonRow(
            person: p,
            onOpen: onOpen,
            encore: encored.contains(p.userId),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            'Only you see who saw your Show.',
            style: TextStyle(color: StageColors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// One runner: avatar, stage name, when. A Crew mate opens their page.
class _PersonRow extends ConsumerWidget {
  const _PersonRow({
    required this.person,
    required this.onOpen,
    this.encore = false,
  });
  final CrewPerson person;
  final void Function(CrewPerson) onOpen;

  /// They gave an Encore too (on the Seen by list).
  final bool encore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(crewControllerProvider);
    final isMe = person.userId == state.profile?.userId;
    final inCrew = !isMe && state.crew.any((m) => m.userId == person.userId);
    final name = isMe ? 'You' : person.stageName;
    final ago = sharedAgo(person.at);
    return Semantics(
      container: true,
      button: inCrew,
      label:
          '$name, $ago${encore ? ', gave an Encore' : ''}'
          '${inCrew ? '. Opens their page.' : ''}',
      excludeSemantics: true,
      onTap: inCrew ? () => onOpen(person) : null,
      child: InkWell(
        onTap: inCrew ? () => onOpen(person) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                CrewAvatar(
                  name: person.stageName,
                  color: person.color,
                  badge: person.avatarBadge,
                  photoUrl: person.avatarUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        ago,
                        style: const TextStyle(
                          fontSize: 13,
                          color: StageColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (encore)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.celebration,
                      size: 20,
                      color: StageColors.amber,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks a Crew mate's Show seen once at least half of it has been on
/// screen for [dwell]. Checks on scroll and layout, never on a loop, and
/// stops for good once it has fired.
class CrewSeenWatch extends ConsumerStatefulWidget {
  const CrewSeenWatch({
    super.key,
    required this.post,
    required this.child,
    this.dwell = const Duration(seconds: 1),
  });
  final CrewPost post;
  final Widget child;
  final Duration dwell;

  @override
  ConsumerState<CrewSeenWatch> createState() => _CrewSeenWatchState();
}

class _CrewSeenWatchState extends ConsumerState<CrewSeenWatch> {
  ScrollPosition? _position;
  Timer? _timer;
  bool _done = false;
  bool _active = true;
  Size _screen = Size.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = Scrollable.maybeOf(context)?.position;
    if (!identical(p, _position)) {
      _position?.removeListener(_check);
      _position = p?..addListener(_check);
    }
  }

  @override
  void didUpdateWidget(CrewSeenWatch old) {
    super.didUpdateWidget(old);
    if (old.post.id != widget.post.id) {
      _done = false;
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _position?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (_done || !mounted) return;
    if (_visible()) {
      _timer ??= Timer(widget.dwell, _fire);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _fire() {
    _timer = null;
    if (_done || !mounted || !_visible()) return;
    _done = true;
    _position?.removeListener(_check);
    _position = null;
    ref.read(crewControllerProvider.notifier).markSeen(widget.post);
  }

  bool _visible() {
    if (!_active) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    var bounds = Offset.zero & _screen;
    final vp = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (vp is RenderBox && vp.attached && vp.hasSize) {
      bounds = bounds.intersect(vp.localToGlobal(Offset.zero) & vp.size);
    }
    final shown = rect.intersect(bounds);
    if (shown.width <= 0 || shown.height <= 0) return false;
    final need = math.min(rect.height, bounds.height) / 2;
    return shown.height + 0.5 >= need;
  }

  @override
  Widget build(BuildContext context) {
    // A Show under another screen (or on a hidden tab) isn't on stage.
    _active = TickerMode.valuesOf(context).enabled;
    _screen = MediaQuery.sizeOf(context);
    if (!_done && !widget.post.mine) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
    return widget.child;
  }
}
