import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../data/providers.dart';
import '../../models/saved_mix.dart';
import '../../models/track.dart';
import '../widgets/stage_widgets.dart';
import '../widgets/track_editor.dart';

/// Create or edit a Saved Mix.
class SavedMixScreen extends ConsumerStatefulWidget {
  const SavedMixScreen({super.key, this.mixId});

  /// Null for a new Mix.
  final String? mixId;

  @override
  ConsumerState<SavedMixScreen> createState() => _SavedMixScreenState();
}

class _SavedMixScreenState extends ConsumerState<SavedMixScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _gym = TextEditingController();
  final _treadmill = TextEditingController();
  List<Track> _tracks = [];
  SavedMix? _existing;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.mixId;
    if (id != null) {
      final mix = await ref.read(savedMixRepositoryProvider).getById(id);
      if (mix != null) {
        _existing = mix;
        _name.text = mix.name;
        _gym.text = mix.gymName ?? '';
        _treadmill.text = mix.treadmillName ?? '';
        _tracks = [...mix.tracks];
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _gym.dispose();
    _treadmill.dispose();
    super.dispose();
  }

  String? _blankToNull(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one Track.')));
      return;
    }
    final now = DateTime.now();
    await ref.read(savedMixRepositoryProvider).save(SavedMix(
          id: _existing?.id ?? const Uuid().v4(),
          name: _name.text.trim(),
          gymName: _blankToNull(_gym.text),
          treadmillName: _blankToNull(_treadmill.text),
          tracks: _tracks,
          createdAt: _existing?.createdAt ?? now,
          updatedAt: now,
        ));
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final id = _existing?.id;
    if (id == null) return;
    await ref.read(savedMixRepositoryProvider).delete(id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'NEW SAVED MIX' : 'EDIT SAVED MIX'),
        actions: [
          if (_existing != null)
            IconButton(
              tooltip: 'Delete Mix',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          TextButton(
            onPressed: _save,
            child: const Text('SAVE',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MaxWidth(
              child: SectionCard(
                title: 'The Mix',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: 'Name', hintText: 'e.g. Hill Pyramid'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Name the Mix' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _gym,
                            decoration: const InputDecoration(labelText: 'Gym'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _treadmill,
                            decoration:
                                const InputDecoration(labelText: 'Treadmill'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TrackEditor(
                      tracks: _tracks,
                      onChanged: (t) => setState(() => _tracks = t),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
