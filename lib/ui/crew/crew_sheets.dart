import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/crew/crew_controller.dart';
import '../../data/crew/crew_service.dart';
import '../../data/sync/sync_controller.dart';
import '../../models/crew.dart';
import '../../theme/app_theme.dart';
import '../settings/settings_screen.dart' show sitePage;
import '../widgets/open_link.dart';
import '../widgets/stage_widgets.dart';
import 'crew_post_card.dart';
import 'crew_widgets.dart';
import 'mate_tour_card.dart';

// ---- Invite ----

Future<void> showInviteSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _InviteSheet(),
);

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet();
  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  late final Future<String> _code = ref
      .read(crewControllerProvider.notifier)
      .inviteCode();

  String _message(String code) {
    final name = ref.read(crewControllerProvider).profile?.stageName;
    final who = name == null ? 'my' : '$name’s';
    return 'Join $who Crew on Setlist Tracker and we can cheer each other’s '
        'Shows: ${crewInviteLink(code)} (code ${spacedCode(code)})';
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: crewInviteLink(code)));
    if (mounted) crewSnack(context, 'Invite link copied.');
  }

  Future<void> _share(String code) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: _message(code), subject: 'Join my Crew'),
      );
      if (result.status == ShareResultStatus.unavailable) await _copy(code);
    } catch (_) {
      // No share sheet here (most desktop browsers): copy instead.
      await _copy(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: FutureBuilder<String>(
          future: _code,
          builder: (context, snap) {
            final code = snap.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'INVITE TO THE CREW',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Send this to a running friend. Anyone with the link or code '
                  'can join your Crew for the next 7 days.',
                  style: TextStyle(color: StageColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: StageColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: StageColors.outline),
                  ),
                  child: snap.hasError
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            snap.error is CrewException
                                ? '${snap.error}'
                                : 'Couldn’t make an invite. Check your '
                                      'connection.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : code == null
                      ? const CircularProgressIndicator()
                      : SelectableText(
                          spacedCode(code),
                          semanticsLabel: code.split('').join(' '),
                          style: theme.textTheme.displayMedium?.copyWith(
                            letterSpacing: 6,
                            fontFeatures: StageFonts.tabular,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: code == null ? null : () => _share(code),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Send invite'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: code == null ? null : () => _copy(code),
                  icon: const Icon(Icons.link),
                  label: const Text('Copy link'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---- Enter a code ----

Future<void> showEnterCodeDialog(BuildContext context) async {
  final code = await showDialog<String>(
    context: context,
    builder: (_) => const _EnterCodeDialog(),
  );
  if (code != null && context.mounted) context.push('/crew/join/$code');
}

class _EnterCodeDialog extends StatefulWidget {
  const _EnterCodeDialog();
  @override
  State<_EnterCodeDialog> createState() => _EnterCodeDialogState();
}

class _EnterCodeDialogState extends State<_EnterCodeDialog> {
  final _field = TextEditingController();

  String get _clean =>
      _field.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _go() {
    if (_clean.length == 8) Navigator.of(context).pop(_clean);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter an invite code'),
      content: TextField(
        controller: _field,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: 9,
        decoration: const InputDecoration(
          labelText: 'Code',
          hintText: 'K7Q9 MX4P',
          counterText: '',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _go(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _clean.length == 8 ? _go : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

// ---- Stage name ----

/// Picking (or changing) a stage name and avatar color.
class StageNameForm extends ConsumerStatefulWidget {
  const StageNameForm({
    super.key,
    this.existing,
    this.onSaved,
    this.buttonLabel,
  });
  final CrewProfile? existing;
  final VoidCallback? onSaved;
  final String? buttonLabel;

  @override
  ConsumerState<StageNameForm> createState() => _StageNameFormState();
}

class _StageNameFormState extends ConsumerState<StageNameForm> {
  late final _name = TextEditingController(text: _suggested());
  late int _color = widget.existing?.color ?? 0;
  bool _saving = false;
  String? _error;

  /// Their first name from the sign-in, as a starting point.
  String _suggested() {
    final existing = widget.existing?.stageName;
    if (existing != null) return existing;
    final holder = ref.read(syncControllerProvider).holder;
    final first = holder?.name?.trim().split(RegExp(r'\s+')).first;
    return (first ?? '').length > 30 ? '' : (first ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Pick a stage name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final c = ref.read(crewControllerProvider.notifier);
    final holderId = ref.read(syncControllerProvider).holder?.id ?? '';
    final base =
        widget.existing ?? CrewProfile(userId: holderId, stageName: name);
    try {
      await c.saveProfile(base.copyWith(stageName: name, color: _color));
      widget.onSaved?.call();
    } catch (e) {
      setState(
        () => _error = e is CrewException
            ? e.message
            : 'Couldn’t save. Check your connection.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Stage name',
            helperText: 'What your Crew sees. Change it any time.',
            errorText: _error,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < kCrewColors; i++) ...[
              Semantics(
                button: true,
                selected: i == _color,
                label: 'Avatar color ${i + 1}',
                child: InkResponse(
                  onTap: () => setState(() => _color = i),
                  radius: 28,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 2,
                        color: i == _color
                            ? StageColors.text
                            : Colors.transparent,
                      ),
                    ),
                    child: CrewAvatar(
                      name: _name.text.isEmpty ? '?' : _name.text,
                      color: i,
                      badge: widget.existing?.avatarBadge,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 20),
        // Joining is agreeing to the Crew rules (App Review Guideline 1.2).
        if (widget.existing == null) ...[
          const CrewRulesNote(),
          const SizedBox(height: 12),
        ],
        Center(
          child: GradientButton(
            label: widget.buttonLabel ?? 'Save stage name',
            onPressed: _saving ? null : _save,
          ),
        ),
      ],
    );
  }
}

/// "By joining you agree to the Crew rules", above the first Join button.
class CrewRulesNote extends StatelessWidget {
  const CrewRulesNote({super.key});

  @override
  Widget build(BuildContext context) {
    final terms = sitePage('terms.html');
    const style = TextStyle(color: StageColors.textMuted, height: 1.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'By joining, you agree to the Crew rules: no harassment, hate, '
          'nudity or spam. Reports are read within 24 hours, and accounts '
          'that break the rules are removed.',
          style: style,
        ),
        if (terms != null)
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              alignment: Alignment.centerLeft,
            ),
            onPressed: () => openLink(context, terms),
            child: const Text('Read the Crew rules'),
          ),
      ],
    );
  }
}

// ---- A Crew member ----

Future<void> showMateSheet(BuildContext context, CrewMate mate) =>
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MateSheet(mate: mate),
    );

class _MateSheet extends ConsumerWidget {
  const _MateSheet({required this.mate});
  final CrewMate mate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final router = GoRouter.of(context);
    void close() => Navigator.of(context).pop();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CrewAvatar(
                  name: mate.stageName,
                  color: mate.color,
                  size: 56,
                  badge: mate.avatarBadge,
                  photoUrl: mate.avatarUrl,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mate.stageName,
                        style: theme.textTheme.headlineMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'In your Crew since ${formatShowDay(mate.since.toLocal())}',
                        style: const TextStyle(color: StageColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (mate.tour != null) ...[
              const SizedBox(height: 16),
              MateTourCard(
                mate: mate,
                onBook: () => bookTourFeaturing(context, mate, before: close),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                close();
                router.push('/crew/mate/${mate.userId}');
              },
              icon: const Icon(Icons.queue_music),
              label: Text('See ${mate.stageName}’s Setlist'),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: StageColors.textMuted,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () async {
                final ok = await confirmCrew(
                  context,
                  title: 'Remove ${mate.stageName} from your Crew?',
                  body:
                      'You’ll stop seeing each other’s Shows. You can join '
                      'again with a new invite.',
                  action: 'Remove',
                );
                if (!ok) return;
                try {
                  await ref.read(crewControllerProvider.notifier).leave(mate);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (_) {
                  if (context.mounted) {
                    crewSnack(context, 'Couldn’t reach the Crew. Try again.');
                  }
                }
              },
              child: const Text('Remove from Crew'),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () async {
                final done = await confirmBlock(
                  context,
                  ref,
                  mate.userId,
                  mate.stageName,
                );
                if (done && context.mounted) Navigator.of(context).pop();
              },
              child: Text('Block ${mate.stageName}'),
            ),
            if (mate.avatarUrl != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => showReportPhotoSheet(context, mate),
                child: const Text('Report photo'),
              ),
          ],
        ),
      ),
    );
  }
}
