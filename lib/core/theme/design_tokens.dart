import 'package:flutter/material.dart' hide Element;
import '../../../domain/value_objects/element.dart';

/// Semantic surface colors (elevation by light, not Material gray).
class BrimstoneSurfaces {
  static const Color bgAbyss = Color(0xFF08060C); // Deepest background
  static const Color surfaceBase = Color(0xFF110E1A); // Base cards/containers
  static const Color surfaceElevated =
      Color(0xFF1A1528); // Elevated cards, modals
  static const Color surfaceInteractive =
      Color(0xFF241D36); // Interactive elements
  static const Color surfaceGlass = Color(0xCC161124); // Glass overlays
  static const Color surfaceOverlay = Color(0x8008060C); // Modal overlays
}

/// Metallic & semantic accents (Dark Fantasy tones, never saturated neon).
class BrimstoneAccents {
  static const Color goldPrimary = Color(0xFFC8A24B); // Primary gold
  static const Color goldMuted = Color(0xFF7A6028); // Muted gold borders
  static const Color goldBright =
      Color(0xFFF2D078); // Bright gold (hover/focus)
  static const Color crimsonPrimary = Color(0xFF9E1B24); // Primary crimson
  static const Color crimsonGlow = Color(0xFFD6323C); // Crimson glow
  static const Color voidPurple = Color(0xFF8B4FD9); // Void accent
  static const Color textPrimary =
      Color(0xFFF0EAE1); // Warm ivory (never pure white)
  static const Color textSecondary = Color(0xFFA69EB8); // Secondary text
  static const Color textMuted = Color(0xFF68607A); // Muted/disabled text
  static const Color textOnGold = Color(0xFF1A0E14); // Text on gold backgrounds
  static const Color danger = Color(0xFFD6323C); // Error/missing resources
  static const Color success = Color(0xFF4FFFA3); // Success/completed
  static const Color warning = Color(0xFFFFC93C); // Warning/pending
  static const Color info = Color(0xFF3FD8FF); // Info/mana
}

/// Elemental colors (harmonized, desaturated for dark backgrounds).
class BrimstoneElements {
  static const Color igneous = Color(0xFFE05A2B);
  static const Color abyssal = Color(0xFF2E95D3);
  static const Color telluric = Color(0xFF8C6D46);
  static const Color voidElem = Color(0xFF8B4FD9);

  static Color forElement(Element element) => switch (element) {
        Element.igneous => igneous,
        Element.abyssal => abyssal,
        Element.telluric => telluric,
        Element.empty => voidElem,
      };

  static Color forElementGlow(Element element) => switch (element) {
        Element.igneous => const Color(0xFFFF8A5A),
        Element.abyssal => const Color(0xFF6EC6FF),
        Element.telluric => const Color(0xFFD4A87A),
        Element.empty => const Color(0xFFC89AFF),
      };
}

/// Spacing scale (4px base unit).
class BrimstoneSpacing {
  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 12;
  static const double spaceLG = 16;
  static const double spaceXL = 24;
  static const double spaceXXL = 32;
}

/// Border radius scale.
class BrimstoneRadii {
  static const double radiusSM = 6;
  static const double radiusMD = 10;
  static const double radiusLG = 14;
  static const double radiusXL = 18;
  static const double radiusFull = 999;
}

/// Dark-fantasy type system.
///
/// * **Cinzel** — chapters, bosses, card names and primary buttons. Its
///   engraved Roman capitals are the signature of the setting.
/// * **Inter** — body copy, labels and every number (tabulated so HP, gold and
///   mana never jitter).
///
/// Both families ship inside `assets/fonts/`, so no runtime download happens and
/// widget tests stay offline-safe.
class BrimstoneFonts {
  const BrimstoneFonts._();

  static const String display = 'Cinzel';
  static const String body = 'Inter';

  static TextStyle cinzel({
    double size = 16,
    FontWeight weight = FontWeight.w800,
    Color color = BrimstoneAccents.textPrimary,
    double letterSpacing = 1.0,
    double height = 1.2,
    List<Shadow>? shadows,
  }) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        letterSpacing: letterSpacing,
        height: height,
        color: color,
        shadows: shadows,
      );

  static TextStyle sans({
    double size = 12,
    FontWeight weight = FontWeight.w500,
    Color color = BrimstoneAccents.textSecondary,
    double letterSpacing = 0.2,
    double height = 1.4,
    bool tabular = false,
  }) =>
      TextStyle(
        fontFamily: body,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      );
}

/// Typography with clear hierarchy and tabular figures for numbers.
class BrimstoneTypography {
  // Display / Headings — engraved Cinzel capitals.
  static const TextStyle headingXL = TextStyle(
    fontFamily: BrimstoneFonts.display,
    fontSize: 22,
    fontWeight: FontWeight.w900,
    fontVariations: [FontVariation('wght', 900)],
    letterSpacing: 1.4,
    height: 1.2,
    color: BrimstoneAccents.textPrimary,
  );

  static const TextStyle headingLG = TextStyle(
    fontFamily: BrimstoneFonts.display,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
    letterSpacing: 1.3,
    height: 1.25,
    color: BrimstoneAccents.textPrimary,
  );

  static const TextStyle headingMD = TextStyle(
    fontFamily: BrimstoneFonts.display,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    letterSpacing: 1.1,
    height: 1.3,
    color: BrimstoneAccents.textPrimary,
  );

  static const TextStyle headingSM = TextStyle(
    fontFamily: BrimstoneFonts.display,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
    letterSpacing: 1.2,
    height: 1.3,
    color: BrimstoneAccents.textPrimary,
  );

  /// Chapter banner title (Cinzel Black with a gilded glow).
  static const TextStyle chapterTitle = TextStyle(
    fontFamily: BrimstoneFonts.display,
    fontSize: 17,
    fontWeight: FontWeight.w900,
    fontVariations: [FontVariation('wght', 900)],
    letterSpacing: 1.8,
    height: 1.15,
    color: BrimstoneAccents.goldBright,
    shadows: [
      Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 2)),
      Shadow(color: Color(0x66C8A24B), blurRadius: 12),
    ],
  );

  /// Boss nameplate (Cinzel 900, crimson aura).
  static const TextStyle bossName = TextStyle(
    fontFamily: BrimstoneFonts.display,
    fontSize: 14,
    fontWeight: FontWeight.w900,
    fontVariations: [FontVariation('wght', 900)],
    letterSpacing: 1.2,
    height: 1.2,
    color: BrimstoneAccents.textPrimary,
    shadows: [
      Shadow(color: Color(0xAA9E1B24), blurRadius: 8),
      Shadow(color: Color(0xCC000000), blurRadius: 3),
    ],
  );

  /// Card name inside the foil frame.
  static const TextStyle cardName = TextStyle(
    fontFamily: BrimstoneFonts.display,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    letterSpacing: 0.5,
    height: 1.1,
    color: Colors.white,
    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
  );

  // Body text — Inter.
  static const TextStyle bodyLG = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.4,
    color: BrimstoneAccents.textPrimary,
  );

  static const TextStyle bodyMD = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.4,
    color: BrimstoneAccents.textSecondary,
  );

  static const TextStyle bodySM = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.35,
    color: BrimstoneAccents.textSecondary,
  );

  static const TextStyle bodyXS = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.3,
    color: BrimstoneAccents.textMuted,
  );

  // Numeric / tabular figures (CRITICAL for HP, Gold, Mana, DPS)
  static const TextStyle numericMono = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1.2,
    color: BrimstoneAccents.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numericMonoLG = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1.15,
    color: BrimstoneAccents.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numericMonoSM = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    height: 1.2,
    color: BrimstoneAccents.textSecondary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numericMonoXS = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    height: 1.2,
    color: BrimstoneAccents.textMuted,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Labels / Captions
  static const TextStyle labelLG = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
    height: 1.2,
    color: BrimstoneAccents.textPrimary,
  );

  static const TextStyle labelMD = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.2,
    color: BrimstoneAccents.textSecondary,
  );

  static const TextStyle labelSM = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    height: 1.2,
    color: BrimstoneAccents.textMuted,
  );

  static const TextStyle labelXS = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 8,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1.15,
    color: BrimstoneAccents.textMuted,
  );

  // Status badges
  static TextStyle badge(Color color) => TextStyle(
        fontFamily: BrimstoneFonts.body,
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        color: color,
      );

  // Button text — Cinzel engraved capitals.
  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: BrimstoneFonts.display,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
    letterSpacing: 1.2,
    color: BrimstoneAccents.textOnGold,
  );

  static const TextStyle buttonSecondary = TextStyle(
    fontFamily: BrimstoneFonts.display,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    letterSpacing: 1.0,
    color: BrimstoneAccents.goldPrimary,
  );

  static const TextStyle buttonGhost = TextStyle(
    fontFamily: BrimstoneFonts.body,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: BrimstoneAccents.textSecondary,
  );
}

/// Transition durations and curves.
class BrimstoneMotion {
  static const Duration fast = Duration(milliseconds: 80);
  static const Duration normal = Duration(milliseconds: 150);
  static const Duration slow = Duration(milliseconds: 240);
  static const Duration route = Duration(milliseconds: 240);
  static const Curve standard = Curves.easeOutCubic;
  static const Curve press = Curves.easeOutQuad;
  static const Curve spring = Curves.elasticOut;
}

/// Shadows for elevation.
class BrimstoneShadows {
  static List<BoxShadow> get level1 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get level2 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: BrimstoneAccents.goldPrimary.withValues(alpha: 0.1),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> get level3 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.6),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: BrimstoneAccents.goldPrimary.withValues(alpha: 0.15),
          blurRadius: 16,
          spreadRadius: 2,
        ),
      ];

  static List<BoxShadow> get glowGold => [
        BoxShadow(
          color: BrimstoneAccents.goldBright.withValues(alpha: 0.35),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> get glowCrimson => [
        BoxShadow(
          color: BrimstoneAccents.crimsonGlow.withValues(alpha: 0.35),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> glowElement(Element element) => [
        BoxShadow(
          color:
              BrimstoneElements.forElementGlow(element).withValues(alpha: 0.35),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ];
}

/// Border definitions.
class BrimstoneBorders {
  static Border get hairline => Border.all(
        color: BrimstoneAccents.goldMuted.withValues(alpha: 0.5),
        width: 1,
      );

  static Border get standard => Border.all(
        color: BrimstoneAccents.goldMuted,
        width: 1.5,
      );

  static Border get bold => Border.all(
        color: BrimstoneAccents.goldPrimary,
        width: 2,
      );

  static Border get selected => Border.all(
        color: BrimstoneAccents.goldBright,
        width: 2,
      );

  static Border get disabled => Border.all(
        color: const Color(0xFF332D42),
        width: 1,
      );

  static Border elemental(Element element) => Border.all(
        color: BrimstoneElements.forElement(element).withValues(alpha: 0.6),
        width: 1.5,
      );
}

/// Gradients.
class BrimstoneGradients {
  static const LinearGradient surfaceBase = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [BrimstoneSurfaces.surfaceBase, BrimstoneSurfaces.surfaceElevated],
  );

  static const LinearGradient surfaceElevated = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      BrimstoneSurfaces.surfaceElevated,
      BrimstoneSurfaces.surfaceInteractive
    ],
  );

  static const LinearGradient gold = LinearGradient(
    colors: [BrimstoneAccents.goldPrimary, BrimstoneAccents.goldBright],
  );

  static const LinearGradient goldMuted = LinearGradient(
    colors: [BrimstoneAccents.goldMuted, BrimstoneAccents.goldPrimary],
  );

  static const LinearGradient crimson = LinearGradient(
    colors: [BrimstoneAccents.crimsonPrimary, BrimstoneAccents.crimsonGlow],
  );

  static const LinearGradient voidPurple = LinearGradient(
    colors: [BrimstoneAccents.voidPurple, Color(0xFFC89AFF)],
  );

  static LinearGradient element(Element element) => LinearGradient(
        colors: [
          BrimstoneElements.forElement(element),
          BrimstoneElements.forElementGlow(element),
        ],
      );

  static const LinearGradient abyssBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF07050B),
      Color(0xFF150A12),
      Color(0xFF07050B),
    ],
  );

  static const LinearGradient cardBase = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A0E14),
      Color(0xFF0F060A),
    ],
  );

  static const LinearGradient cardSelected = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF32121D),
      Color(0xFF1E0A12),
    ],
  );
}

/// Convenience exports for common combinations.
class BrimstoneTokens {
  static const Color bgAbyss = BrimstoneSurfaces.bgAbyss;
  static const Color surfaceBase = BrimstoneSurfaces.surfaceBase;
  static const Color surfaceElevated = BrimstoneSurfaces.surfaceElevated;
  static const Color surfaceInteractive = BrimstoneSurfaces.surfaceInteractive;
  static const Color surfaceGlass = BrimstoneSurfaces.surfaceGlass;

  static const Color goldPrimary = BrimstoneAccents.goldPrimary;
  static const Color goldMuted = BrimstoneAccents.goldMuted;
  static const Color goldBright = BrimstoneAccents.goldBright;
  static const Color crimsonPrimary = BrimstoneAccents.crimsonPrimary;
  static const Color textPrimary = BrimstoneAccents.textPrimary;
  static const Color textSecondary = BrimstoneAccents.textSecondary;
  static const Color textMuted = BrimstoneAccents.textMuted;
  static const Color textOnGold = BrimstoneAccents.textOnGold;
  static const Color danger = BrimstoneAccents.danger;
  static const Color success = BrimstoneAccents.success;
  static const Color warning = BrimstoneAccents.warning;

  static const double spaceXS = BrimstoneSpacing.spaceXS;
  static const double spaceSM = BrimstoneSpacing.spaceSM;
  static const double spaceMD = BrimstoneSpacing.spaceMD;
  static const double spaceLG = BrimstoneSpacing.spaceLG;
  static const double spaceXL = BrimstoneSpacing.spaceXL;

  static const double radiusSM = BrimstoneRadii.radiusSM;
  static const double radiusMD = BrimstoneRadii.radiusMD;
  static const double radiusLG = BrimstoneRadii.radiusLG;

  static const TextStyle headingXL = BrimstoneTypography.headingXL;
  static const TextStyle headingLG = BrimstoneTypography.headingLG;
  static const TextStyle headingMD = BrimstoneTypography.headingMD;
  static const TextStyle headingSM = BrimstoneTypography.headingSM;
  static const TextStyle chapterTitle = BrimstoneTypography.chapterTitle;
  static const TextStyle bossName = BrimstoneTypography.bossName;
  static const TextStyle cardName = BrimstoneTypography.cardName;
  static const TextStyle bodyLG = BrimstoneTypography.bodyLG;
  static const TextStyle bodyMD = BrimstoneTypography.bodyMD;
  static const TextStyle bodySM = BrimstoneTypography.bodySM;
  static const TextStyle bodyXS = BrimstoneTypography.bodyXS;
  static const TextStyle numericMono = BrimstoneTypography.numericMono;
  static const TextStyle numericMonoLG = BrimstoneTypography.numericMonoLG;
  static const TextStyle numericMonoSM = BrimstoneTypography.numericMonoSM;
  static const TextStyle labelLG = BrimstoneTypography.labelLG;
  static const TextStyle labelMD = BrimstoneTypography.labelMD;
  static const TextStyle labelSM = BrimstoneTypography.labelSM;
  static const TextStyle buttonPrimary = BrimstoneTypography.buttonPrimary;
  static const TextStyle buttonSecondary = BrimstoneTypography.buttonSecondary;

  static const Duration fast = BrimstoneMotion.fast;
  static const Duration normal = BrimstoneMotion.normal;
  static const Duration slow = BrimstoneMotion.slow;
  static const Duration route = BrimstoneMotion.route;
  static const Curve standard = BrimstoneMotion.standard;
  static const Curve press = BrimstoneMotion.press;

  static Color element(Element e) => BrimstoneElements.forElement(e);
  static Color elementGlow(Element e) => BrimstoneElements.forElementGlow(e);
}
