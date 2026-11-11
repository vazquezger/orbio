import 'package:flutter/material.dart';

import '../../data/models/country.dart';
import '../../data/models/pin.dart';
import '../l10n_labels.dart';

/// Read-only bottom sheet with a country's political, physical and story
/// content.
class CountryDetailSheet extends StatelessWidget {
  const CountryDetailSheet({super.key, required this.country});

  final Country country;

  static Future<void> show(BuildContext context, {required Country country}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => CountryDetailSheet(country: country),
      );

  @override
  Widget build(BuildContext context) {
    final c = country;
    final theme = Theme.of(context);
    final l = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            children: [
              Text(c.flag, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: theme.textTheme.headlineSmall),
                    Text(c.code, style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(icon: Icons.flag_outlined, title: l.sheetPolitical),
          _InfoRow(l.sheetCapital, c.capitalName),
          _InfoRow(l.sheetGovernment, c.governmentType),
          _InfoRow(c.headOfState.title, c.headOfState.name),
          if (c.headOfGovernment != null)
            _InfoRow(c.headOfGovernment!.title, c.headOfGovernment!.name),
          const SizedBox(height: 12),
          _Section(icon: Icons.terrain_outlined, title: l.sheetPhysical),
          for (final pin in c.pins)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (pin.kind) {
                PinKind.volcano => Icons.local_fire_department_outlined,
                PinKind.peak => Icons.landscape_outlined,
                PinKind.depression => Icons.south_outlined,
              }),
              title: Text(pin.name),
              subtitle: Text('${pin.kind.label(l)} · ${l.elevationMeters(pin.elevationM)}'
                  '${pin.description.isEmpty ? '' : '\n${pin.description}'}'),
              isThreeLine: pin.description.isNotEmpty,
            ),
          if (c.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(icon: Icons.auto_stories_outlined, title: l.sheetStories),
            for (final note in c.notes)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Text(note.kind.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(note.text),
                  subtitle: Text(note.kind.label(l)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
