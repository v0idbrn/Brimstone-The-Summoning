/// Visual chassis of a card: the same creature can be summoned through three
/// different mythic skins once it reaches 5★.
enum CardSkin {
  classic('CLÁSICA'),
  abyssal('ABISAL CORRUPTA'),
  celestial('CELESTIAL RADIANTE');

  const CardSkin(this.label);

  /// Spanish label shown in the Barracks skin picker.
  final String label;

  bool get isClassic => this == CardSkin.classic;
}
