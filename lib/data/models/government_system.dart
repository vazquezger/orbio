/// Form of government, used to colour countries in the Government layer.
enum GovernmentSystem {
  presidentialRepublic('presidential_republic'),
  parliamentaryRepublic('parliamentary_republic'),
  constitutionalMonarchy('constitutional_monarchy'),
  absoluteMonarchy('absolute_monarchy');

  const GovernmentSystem(this.key);

  /// Value used in the content JSON.
  final String key;

  bool get isMonarchy =>
      this == constitutionalMonarchy || this == absoluteMonarchy;

  static GovernmentSystem parse(String raw) => values.firstWhere(
        (g) => g.key == raw,
        orElse: () => throw FormatException('Unknown government_system: $raw'),
      );
}
