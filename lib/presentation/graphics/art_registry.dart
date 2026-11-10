/// Central registry for every painted art asset shipped with the game.
///
/// The asset pipeline (`tools/build_aaa_assets.py`) guarantees 54 unique
/// painted portraits, 8 panoramic scenes and 6 VFX textures. Nothing in the UI
/// should hardcode an `assets/...` string; route it through here so
/// `tools/verify_assets.py` can validate the whole graph.
class ArtRegistry {
  const ArtRegistry._();

  static const String portraitDir = 'assets/portraits';
  static const String backgroundDir = 'assets/backgrounds';
  static const String vfxDir = 'assets/vfx';

  /// Painted portrait for any game entity (squad, minion, boss or titan).
  static String portrait(String entityId) => '$portraitDir/$entityId.webp';

  /// Soft-alpha variant used by the arena silhouette. Its edges melt into the
  /// rift so the boss never reads as a pasted square photo.
  static String spectralPortrait(String entityId) =>
      '$portraitDir/${entityId}_spectral.webp';

  /// Fallback portrait used when an entity has no curated art.
  static const String fallbackPortrait = '$portraitDir/boss_pyroth.webp';

  /// Resolves a portrait path coming from domain data (`portraits/x.webp`).
  static String resolvePortraitAsset(String relative) {
    if (relative.startsWith('assets/')) return relative;
    return 'assets/$relative';
  }

  // ── Scenic backgrounds ────────────────────────────────────────────────
  static const String chapter1 = '$backgroundDir/chapter_1.webp';
  static const String chapter2 = '$backgroundDir/chapter_2.webp';
  static const String chapter3 = '$backgroundDir/chapter_3.webp';
  static const String chapter4 = '$backgroundDir/chapter_4.webp';
  static const String chapter5 = '$backgroundDir/chapter_5.webp';
  static const String sanctuary = '$backgroundDir/sanctuary.webp';
  static const String portal = '$backgroundDir/portal.webp';
  static const String raid = '$backgroundDir/raid.webp';

  static const String sanctuaryBlur = '$backgroundDir/sanctuary_blur.webp';
  static const String portalBlur = '$backgroundDir/portal_blur.webp';
  static const String chapter1Blur = '$backgroundDir/chapter_1_blur.webp';

  static const List<String> chapterScenes = [
    chapter1,
    chapter2,
    chapter3,
    chapter4,
    chapter5,
  ];

  /// Chapter scene for a 1-based chapter number (clamped to the campaign).
  static String chapterBackground(int chapterNumber) =>
      chapterScenes[(chapterNumber - 1).clamp(0, chapterScenes.length - 1)];

  /// Scene used by a meta screen.
  static const Map<String, String> metaScenes = {
    'sanctuary': sanctuary,
    'portal': portal,
    'raid': raid,
    'altar': chapter5,
    'barracks': chapter3,
    'rift': chapter1,
  };

  // ── VFX textures (procedural, additive) ───────────────────────────────
  static const String vfxEmber = '$vfxDir/ember.webp';
  static const String vfxFrost = '$vfxDir/frost.webp';
  static const String vfxVoid = '$vfxDir/void.webp';
  static const String vfxSpark = '$vfxDir/spark.webp';
  static const String vfxShockwave = '$vfxDir/shockwave.webp';
  static const String vfxRuneRing = '$vfxDir/rune_ring.webp';
}
