import 'package:flutter/material.dart';

import '../../data/models/map_layer.dart';
import '../l10n_labels.dart';

class LayerToggleBar extends StatelessWidget {
  const LayerToggleBar({super.key, required this.active, required this.onChanged});

  final Set<MapLayer> active;
  final ValueChanged<Set<MapLayer>> onChanged;

  static IconData iconFor(MapLayer layer) => switch (layer) {
        MapLayer.flags => Icons.flag_outlined,
        MapLayer.government => Icons.account_balance_outlined,
        MapLayer.physical => Icons.terrain_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final layer in MapLayer.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(iconFor(layer), size: 18),
                label: Text(layer.label(context.l10n)),
                selected: active.contains(layer),
                showCheckmark: false,
                onSelected: (on) => onChanged(MapLayer.toggle(active, layer, on)),
              ),
            ),
        ],
      ),
    );
  }
}
