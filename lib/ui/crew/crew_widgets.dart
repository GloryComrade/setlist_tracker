import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_photos.dart';
import '../../theme/app_theme.dart';
import 'avatar_badges.dart';

/// What the Crew sees, said once the same way everywhere.
const kCrewSeesEverything =
    'Your Crew sees every Show you log. Mark a Show “Keep off the Crew” to '
    'keep it to yourself.';

/// Avatar fills. All deep shades, so the white initial stays readable.
const crewColors = [
  StageColors.magentaDeep,
  StageColors.violetDeep,
  StageColors.tealDeep,
  StageColors.orangeDeep,
];

/// The same, for a runner who hasn't OK'd the Crew seeing every Show yet.
const kCrewSeesShared =
    'Your Crew sees the Shows you shared. OK the change on The Crew tab to '
    'let them see every Show you log.';

Color crewColor(int i) => crewColors[i.clamp(0, crewColors.length - 1)];

/// A runner's picture: their photo, else their tour-art badge, else their
/// initial, on their color.
class CrewAvatar extends ConsumerWidget {
  const CrewAvatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 40,
    this.badge,
    this.photoUrl,
  });

  final String name;
  final int color;
  final double size;

  /// A badge id from `kAvatarBadges`, or null.
  final String? badge;

  /// An `avatarUrl` from the server, or null.
  final String? photoUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = photoUrl;
    final photo = url == null ? null : ref.watch(crewPhotoProvider(url)).value;
    final badge = this.badge;
    final Widget mark;
    if (badge != null && hasBadgeArt(badge)) {
      mark = BadgeGlyph(badge, size: size * 0.58);
    } else {
      final initial = name.trim().isEmpty
          ? '?'
          : name.trim().characters.first.toUpperCase();
      mark = Text(
        initial,
        style: TextStyle(
          fontFamily: StageFonts.display,
          fontSize: size * 0.55,
          height: 1.05,
          color: Colors.white,
        ),
      );
    }
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    return SizedBox.square(
      dimension: size,
      // The name is always said next to the avatar; the picture is art.
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: crewColor(color),
                shape: BoxShape.circle,
              ),
              child: Center(child: mark),
            ),
            // The photo lands on top once it's here; until then (or if it
            // never comes) the badge or initial shows.
            if (photo != null)
              ClipOval(
                child: Image.memory(
                  photo,
                  key: ValueKey(url),
                  fit: BoxFit.cover,
                  cacheWidth: (size * dpr).ceil(),
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Just now", "12 min ago", "3 h ago", "Yesterday", "Nov 18".
String sharedAgo(DateTime at, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(at);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24 && n.day == at.day) return '${d.inHours} hr ago';
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(at.year, at.month, at.day);
  if (today.difference(day).inDays == 1) return 'Yesterday';
  if (at.year == n.year) return DateFormat('MMM d').format(at);
  return DateFormat('MMM d, y').format(at);
}

/// Days from today until [night]: 0 on the day, negative after it.
int daysUntil(DateTime night, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(night.year, night.month, night.day);
  return day.difference(today).inDays;
}

/// "34 days to Opening Night", "Opening Night is tomorrow", or null once it
/// has passed.
String? openingNightLine(DateTime? night, {DateTime? now}) {
  if (night == null) return null;
  final days = daysUntil(night, now: now);
  if (days < 0) return null;
  if (days == 0) return 'Opening Night is today';
  if (days == 1) return 'Opening Night is tomorrow';
  return '$days days to Opening Night';
}

/// Where invite links point. The website on the web; on the iPhone, the
/// public site (set with --dart-define=SITE_URL=...).
const _siteUrl = String.fromEnvironment(
  'SITE_URL',
  defaultValue: 'https://glorycomrade.github.io/setlist_tracker/',
);

String crewInviteLink(String code, {Uri? base}) {
  final Uri root;
  if (base != null || kIsWeb) {
    final here = base ?? Uri.base;
    root = Uri(
      scheme: here.scheme,
      host: here.host,
      port: here.hasPort ? here.port : null,
      path: here.path,
    );
  } else {
    root = Uri.parse(_siteUrl);
  }
  return '$root#/crew/join/$code';
}

/// Formats a code for reading aloud: "K7Q9 MX4P".
String spacedCode(String code) =>
    code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;

/// A confirm dialog in the app's usual shape. The destructive action uses
/// the error color.
Future<bool> confirmCrew(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: scheme.error)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result == true;
}

void crewSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Small uppercase tracked label, like the Setlist's week headers.
class CrewLabel extends StatelessWidget {
  const CrewLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: StageColors.textMuted,
    ),
  );
}
