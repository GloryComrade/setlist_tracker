import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

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

Color crewColor(int i) => crewColors[i.clamp(0, crewColors.length - 1)];

/// A runner's initial on their color.
class CrewAvatar extends StatelessWidget {
  const CrewAvatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 40,
  });

  final String name;
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: crewColor(color),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: StageFonts.display,
          fontSize: size * 0.55,
          height: 1.05,
          color: Colors.white,
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
