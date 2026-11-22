import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../models/crew.dart';
import '../../theme/app_theme.dart';
import 'crew_post_card.dart';
import 'crew_widgets.dart';

/// "3 Shout-outs", "1 Shout-out", or just "Shout-out" when there are none.
String shoutoutsLabel(int n) => switch (n) {
  0 => 'Shout-out',
  1 => '1 Shout-out',
  _ => '$n Shout-outs',
};

/// The foot of a Crew post: the Encore, then the Shout-outs. They sit side
/// by side and the Shout-outs drop to their own line when both don't fit
/// (large text, narrow cards), so neither label is cut.
class ShowReactionsRow extends StatelessWidget {
  const ShowReactionsRow({super.key, required this.encore, required this.post});

  /// The post's Encore button or count. Measured at its natural width, so
  /// it must not hold a LayoutBuilder.
  final Widget encore;
  final CrewPost post;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IntrinsicWidth(child: encore),
        ShoutoutsButton(post: post),
      ],
    );
  }
}

/// Opens a Show's Shout-outs, with the count on it.
class ShoutoutsButton extends StatefulWidget {
  const ShoutoutsButton({super.key, required this.post});
  final CrewPost post;

  @override
  State<ShoutoutsButton> createState() => _ShoutoutsButtonState();
}

class _ShoutoutsButtonState extends State<ShoutoutsButton> {
  /// The count the sheet last saw, for pages whose posts aren't the feed's
  /// (a Crew mate's page), until the post itself changes.
  int? _seen;

  @override
  void didUpdateWidget(ShoutoutsButton old) {
    super.didUpdateWidget(old);
    if (old.post.shoutouts != widget.post.shoutouts ||
        old.post.id != widget.post.id) {
      _seen = null;
    }
  }

  Future<void> _open() async {
    final n = await showShoutoutsSheet(context, widget.post);
    if (mounted && n != null) setState(() => _seen = n);
  }

  @override
  Widget build(BuildContext context) {
    final n = _seen ?? widget.post.shoutouts;
    final label = shoutoutsLabel(n);
    return Semantics(
      container: true,
      button: true,
      label: 'Shout-outs',
      value: n == 0 ? 'none yet' : label,
      hint: 'Opens the Shout-outs',
      excludeSemantics: true,
      onTap: _open,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(48, 44),
          foregroundColor: StageColors.text,
        ),
        onPressed: _open,
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// The Shout-outs on [post], oldest first, with a box to give one. Returns
/// how many there were when it closed, or null if they never loaded.
Future<int?> showShoutoutsSheet(BuildContext context, CrewPost post) {
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ShoutoutsSheet(post: post),
  );
}

class _ShoutoutsSheet extends ConsumerStatefulWidget {
  const _ShoutoutsSheet({required this.post});
  final CrewPost post;

  @override
  ConsumerState<_ShoutoutsSheet> createState() => _ShoutoutsSheetState();
}

class _ShoutoutsSheetState extends ConsumerState<_ShoutoutsSheet> {
  final _field = TextEditingController();
  final _scroll = ScrollController();
  List<CrewShoutout>? _items;
  bool _failed = false;
  bool _sending = false;

  CrewPost get post => widget.post;
  CrewController get _crew => ref.read(crewControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _field.addListener(() => setState(() {}));
    _load();
    // Opening a Crew mate's Show counts as seeing it.
    _crew.markSeen(post);
  }

  @override
  void dispose() {
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final list = await _crew.shoutouts(post);
      if (mounted) setState(() => _items = list);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  int get _length => _field.text.trim().runes.length;

  Future<void> _send() async {
    final body = _field.text.trim();
    if (body.isEmpty || _length > kMaxShoutoutChars || _sending) return;
    setState(() => _sending = true);
    try {
      final added = await _crew.addShoutout(post, body);
      if (!mounted) return;
      setState(() {
        _items = [...?_items, added];
        _sending = false;
      });
      _field.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      crewSnack(context, 'Couldn’t send the Shout-out. Try again.');
    }
  }

  Future<void> _delete(CrewShoutout s) async {
    final ok = await confirmCrew(
      context,
      title: 'Delete this Shout-out?',
      body: 'It comes off the Show for everyone.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _crew.deleteShoutout(post, s);
      if (!mounted) return;
      setState(() => _items = [...?_items]..removeWhere((x) => x.id == s.id));
      crewSnack(context, 'Shout-out deleted.');
    } catch (_) {
      if (mounted) {
        crewSnack(context, 'Couldn’t delete the Shout-out. Try again.');
      }
    }
  }

  Future<void> _report(CrewShoutout s) async {
    final sent = await showReportShoutoutSheet(context, post, s);
    if (sent && mounted) {
      setState(() => _items = [...?_items]..removeWhere((x) => x.id == s.id));
    }
  }

  void _act(String action, CrewShoutout s) {
    switch (action) {
      case 'delete':
        _delete(s);
      case 'report':
        _report(s);
    }
  }

  List<PopupMenuEntry<String>> _menu(CrewShoutout s) => [
    if (s.canDelete)
      PopupMenuItem(
        value: 'delete',
        child: Text(
          'Delete Shout-out',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    if (!s.mine)
      PopupMenuItem(
        value: 'report',
        child: Text(
          'Report Shout-out',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
  ];

  Future<void> _menuAt(Offset at, CrewShoutout s) async {
    final items = _menu(s);
    if (items.isEmpty) return;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        at & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: items,
    );
    if (action != null) _act(action, s);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final who = post.mine ? 'you' : post.stageName;
    return Padding(
      // Rides up over the keyboard.
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Semantics(
                  header: true,
                  child: Text(
                    'SHOUT-OUTS',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  post.mine
                      ? 'Only you and your Crew see these.'
                      : 'Only $who and their Crew see these.',
                  style: const TextStyle(color: StageColors.textMuted),
                ),
              ),
              Flexible(child: _body()),
              const Divider(height: 1, color: StageColors.outline),
              _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final items = _items;
    if (items == null && _failed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Couldn’t reach the Crew.',
              textAlign: TextAlign.center,
              style: TextStyle(color: StageColors.textMuted),
            ),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (items == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Semantics(
            label: 'Loading Shout-outs',
            child: const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Text(
          'No Shout-outs yet. Be the first.',
          textAlign: TextAlign.center,
          style: TextStyle(color: StageColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
      itemCount: items.length,
      itemBuilder: (_, i) => _row(items[i]),
    );
  }

  Widget _row(CrewShoutout s) {
    final name = s.mine ? 'You' : s.stageName;
    final ago = sharedAgo(s.createdAt);
    final hasMenu = s.canDelete || !s.mine;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: hasMenu ? (d) => _menuAt(d.globalPosition, s) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CrewAvatar(
              name: s.stageName,
              color: s.color,
              size: 40,
              badge: s.avatarBadge,
              photoUrl: s.avatarUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                container: true,
                label: '$name, $ago: ${s.body}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
                    const SizedBox(height: 2),
                    Text(s.body, style: const TextStyle(height: 1.35)),
                  ],
                ),
              ),
            ),
            if (hasMenu)
              PopupMenuButton<String>(
                tooltip: 'Shout-out options',
                icon: const Icon(
                  Icons.more_horiz,
                  color: StageColors.textMuted,
                ),
                onSelected: (a) => _act(a, s),
                itemBuilder: (_) => _menu(s),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    final left = kMaxShoutoutChars - _length;
    final over = left < 0;
    final canSend = _length > 0 && !over && !_sending;
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _field,
              enabled: !_sending,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              // A paste can't run far past the limit; the counter covers
              // the rest (the server counts characters as code points).
              inputFormatters: [
                LengthLimitingTextInputFormatter(kMaxShoutoutChars + 20),
              ],
              decoration: InputDecoration(
                hintText: 'Give a Shout-out…',
                // Shown only near the limit.
                counterText: left <= 40 ? '$left' : null,
                counterStyle: TextStyle(
                  color: over ? error : StageColors.textMuted,
                  fontFeatures: StageFonts.tabular,
                ),
                semanticCounterText: left <= 40
                    ? over
                          ? '${-left} characters over the limit'
                          : '$left characters left'
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: EdgeInsets.only(bottom: left <= 40 ? 22 : 4),
            child: _sending
                ? Semantics(
                    label: 'Sending Shout-out',
                    child: const SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Send Shout-out',
                    color: StageColors.amber,
                    disabledColor: StageColors.textMuted.withValues(alpha: 0.5),
                    onPressed: canSend ? _send : null,
                    icon: const Icon(Icons.send),
                  ),
          ),
        ],
      ),
    );
  }
}
