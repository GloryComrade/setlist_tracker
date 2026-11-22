import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/services.dart' show Uint8List;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crew/crew_controller.dart';
import '../../data/crew/crew_service.dart';
import '../../logic/avatar_photo.dart';
import '../../models/avatar_badge.dart';
import '../../models/crew.dart';
import '../../theme/app_theme.dart';
import '../crew/crew_widgets.dart';

/// Opens the photo library and returns the picked photo's bytes, or null
/// when the runner backs out. Swapped out in tests.
typedef PickPhoto = Future<Uint8List?> Function();

final pickPhotoProvider = Provider<PickPhoto>((ref) => _pickFromLibrary);

Future<Uint8List?> _pickFromLibrary() async {
  // The picker scales big photos down (and turns HEIC into JPEG) on the
  // device, so the square crop below has little to read. Without full
  // metadata, iOS needs no photo library permission.
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 92,
    requestFullMetadata: false,
  );
  return file?.readAsBytes();
}

/// The square JPEG for the server, made off the main thread on iPhone.
Future<Uint8List?> _square(Uint8List bytes) => kIsWeb
    ? Future.value(squareAvatarJpeg(bytes))
    : compute(squareAvatarJpegOf, bytes);

/// Your Crew picture: a row of drawn badges (or just your initial), and
/// your own photo, which shows instead when there is one.
class ProfilePicturePicker extends ConsumerStatefulWidget {
  const ProfilePicturePicker({super.key, required this.profile});
  final CrewProfile profile;

  @override
  ConsumerState<ProfilePicturePicker> createState() =>
      _ProfilePicturePickerState();
}

class _ProfilePicturePickerState extends ConsumerState<ProfilePicturePicker> {
  bool _busy = false;

  CrewController get _crew => ref.read(crewControllerProvider.notifier);

  Future<void> _run(Future<void> Function() job, String done) async {
    setState(() => _busy = true);
    try {
      await job();
      if (mounted) crewSnack(context, done);
    } catch (e) {
      if (mounted) {
        crewSnack(
          context,
          e is CrewException
              ? e.message
              : 'Couldn’t save. Check your connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickBadge(String? badge) async {
    final p = widget.profile;
    if (badge == p.avatarBadge && p.avatarUrl == null) return;
    if (p.avatarUrl != null) {
      final ok = await confirmCrew(
        context,
        title: badge == null
            ? 'Use your initial instead?'
            : 'Use the ${kAvatarBadges[badge]} badge instead?',
        body: 'Your photo comes off your profile.',
        action: 'Use it',
      );
      if (!ok) return;
    }
    await _run(() async {
      if (p.avatarUrl != null) await _crew.removeAvatar();
      await _crew.setAvatarBadge(badge);
    }, 'Picture saved.');
  }

  Future<void> _uploadPhoto() async {
    setState(() => _busy = true);
    Uint8List? jpeg;
    try {
      final picked = await ref.read(pickPhotoProvider)();
      if (picked == null) return;
      jpeg = await _square(picked);
      if (jpeg == null && mounted) {
        crewSnack(context, 'That photo couldn’t be read. Try another one.');
      }
    } catch (_) {
      if (mounted) crewSnack(context, 'Couldn’t open your photos.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (jpeg == null || !mounted) return;
    final ok = await _confirmPhoto(jpeg);
    if (!ok) return;
    final photo = jpeg;
    await _run(() => _crew.uploadAvatar(photo), 'Photo saved.');
  }

  Future<bool> _confirmPhoto(Uint8List jpeg) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use this photo?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              image: true,
              label: 'Your photo, cropped to a circle',
              child: ClipOval(
                child: Image.memory(jpeg, width: 120, height: 120),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Crew sees it next to your name and your Shows. Only '
              'your Crew can see it.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Use photo'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _removePhoto() async {
    final ok = await confirmCrew(
      context,
      title: 'Remove your photo?',
      body: widget.profile.avatarBadge == null
          ? 'Your Crew sees your initial instead.'
          : 'Your Crew sees your ${kAvatarBadges[widget.profile.avatarBadge]} '
                'badge instead.',
      action: 'Remove',
    );
    if (ok) await _run(_crew.removeAvatar, 'Photo removed.');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final hasPhoto = p.avatarUrl != null;
    // With a photo, none of the badges is the picture.
    final selected = hasPhoto ? '' : p.avatarBadge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _BadgeChoice(
              label: 'Your initial',
              selected: selected == null,
              onTap: _busy ? null : () => _pickBadge(null),
              child: CrewAvatar(name: p.stageName, color: p.color, size: 44),
            ),
            for (final MapEntry(key: id, value: name) in kAvatarBadges.entries)
              _BadgeChoice(
                label: '$name badge',
                selected: selected == id,
                onTap: _busy ? null : () => _pickBadge(id),
                child: CrewAvatar(
                  name: p.stageName,
                  color: p.color,
                  size: 44,
                  badge: id,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _busy ? null : _uploadPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(hasPhoto ? 'Change photo' : 'Upload a photo'),
            ),
            if (hasPhoto)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: StageColors.textMuted,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: _busy ? null : _removePhoto,
                child: const Text('Remove photo'),
              ),
            if (_busy)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          hasPhoto
              ? 'Your photo shows instead of a badge. Only your Crew sees it.'
              : 'A photo shows instead of a badge. Only your Crew sees it.',
          style: const TextStyle(color: StageColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}

class _BadgeChoice extends StatelessWidget {
  const _BadgeChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: onTap != null,
    label: label,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            width: 2,
            color: selected ? StageColors.text : Colors.transparent,
          ),
        ),
        child: child,
      ),
    ),
  );
}
