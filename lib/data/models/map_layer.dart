/// Toggleable groups of overlay content in Explore.
enum MapLayer {
  flags,
  government,
  physical;

  /// Layers that fill country areas; only one can be on at a time.
  static const areaFills = {MapLayer.flags, MapLayer.government};

  /// Returns the new active set after turning [layer] [on] or off,
  /// keeping area-fill layers mutually exclusive.
  static Set<MapLayer> toggle(Set<MapLayer> active, MapLayer layer, bool on) {
    final next = {...active};
    if (!on) return next..remove(layer);
    if (areaFills.contains(layer)) next.removeAll(areaFills);
    return next..add(layer);
  }
}
