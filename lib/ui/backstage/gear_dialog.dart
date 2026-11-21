import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../models/gear.dart';

/// Add or edit Gear. Returns the Gear to save, or null when cancelled.
Future<Gear?> showGearDialog(BuildContext context, {Gear? existing}) {
  return showDialog<Gear>(
    context: context,
    builder: (_) => _GearDialog(existing: existing),
  );
}

class _GearDialog extends StatefulWidget {
  const _GearDialog({this.existing});
  final Gear? existing;

  @override
  State<_GearDialog> createState() => _GearDialogState();
}

class _GearDialogState extends State<_GearDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _brand = TextEditingController(text: widget.existing?.brand ?? '');
  late final _miles = TextEditingController(
    text: widget.existing == null
        ? '0'
        : widget.existing!.startingMiles.toStringAsFixed(1),
  );

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _miles.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final e = widget.existing;
    final brand = _brand.text.trim();
    Navigator.of(context).pop(
      Gear(
        id: e?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        brand: brand.isEmpty ? null : brand,
        startingMiles: double.tryParse(_miles.text) ?? 0,
        retired: e?.retired ?? false,
        createdAt: e?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Gear' : 'Edit Gear'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _brand,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  hintText: 'e.g. Brooks',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Ghost 17',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Give it a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _miles,
                decoration: const InputDecoration(
                  labelText: 'Miles already on them',
                  suffixText: 'mi',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save Gear')),
      ],
    );
  }
}

/// Asks for a single line of text (used for naming a Saved Mix).
Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        textCapitalization: TextCapitalization.words,
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
