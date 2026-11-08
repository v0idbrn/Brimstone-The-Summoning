import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;

import '../../domain/value_objects/element.dart';
import 'rpg_svg_catalog.dart';
import 'svg_path_parser.dart';

/// Procedural artwork system for creature portraits with 4 evolution stages.
/// Uses real game-icons SVG vector art (CC-BY) for professional illustrations.
class CreatureProceduralArt {
  // Card IDs and their elemental affinities
  static const Map<String, Element> _cardElements = {
    'ignis_hound': Element.igneous,
    'ignis_lord': Element.igneous,
    'ignis_drake': Element.igneous,
    'ignis_seraph': Element.igneous,
    'ignis_colossus': Element.igneous,
    'abyss_stalker': Element.abyssal,
    'abyss_leviathan': Element.abyssal,
    'abyss_siren': Element.abyssal,
    'abyss_kraken': Element.abyssal,
    'abyss_wraith': Element.abyssal,
    'terra_golem': Element.telluric,
    'terra_titan': Element.telluric,
    'terra_warden': Element.telluric,
    'terra_hydra': Element.telluric,
    'terra_behemoth': Element.telluric,
    'void_specter': Element.empty,
    'void_malakor': Element.empty,
    'void_reaper': Element.empty,
    'void_oracle': Element.empty,
    'void_archon': Element.empty,
  };

  // SVG path cache for performance
  static final Map<String, ui.Path> _svgPathCache = {};

  // Base colors per element
  static Color _elementColor(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  // Accent colors per element
  static Color _elementAccent(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFFD980),
        Element.abyssal => const Color(0xFF80E8FF),
        Element.telluric => const Color(0xFFF0D0A0),
        Element.empty => const Color(0xFFE5D4FF),
      };

  /// Draw a creature portrait at the given size and star level (1-4).
  static void drawPortrait(
    Canvas canvas,
    Rect bounds,
    String cardId, {
    int stars = 1,
    double time = 0.0,
  }) {
    final element = _cardElements[cardId] ?? Element.igneous;
    final baseColor = _elementColor(element);
    final accentColor = _elementAccent(element);

    canvas.save();
    canvas.translate(bounds.left, bounds.top);
    canvas.clipRect(Rect.fromLTWH(0, 0, bounds.width, bounds.height));

    final center = Offset(bounds.width / 2, bounds.height / 2);
    final radius = math.min(bounds.width, bounds.height) * 0.42;

    // Scenic elemental landscape background
    _drawScenicBackground(canvas, bounds, element, time);

    // ===== STAR LEVEL EFFECTS =====
    // 1★: Iron frame + base silhouette
    // 2★: Bronze runic frame + glowing eyes + floating particles
    // 3★: Silver abyssal frame + crown/wings + double power ring
    // 4★: Animated gold infernal frame + energy cracks + rotating runic seal

    // Background glow
    if (stars >= 2) {
      final glowPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.15 * stars / 4)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(center, radius * 1.3, glowPaint);
    }

    // Draw evolution frame
    _drawEvolutionFrame(
      canvas,
      center,
      radius,
      stars,
      baseColor,
      accentColor,
      time,
    );

    // Draw creature SVG artwork (replaces procedural silhouettes)
    _drawSvgCreature(
      canvas,
      center,
      radius,
      cardId,
      element,
      baseColor,
      accentColor,
      stars,
      time,
    );

    // Draw star-level specific effects
    if (stars >= 2) {
      _drawStarEffects(
        canvas,
        center,
        radius,
        element,
        baseColor,
        accentColor,
        stars,
        time,
      );
    }

    canvas.restore();
  }

  /// Draw the creature using real SVG vector art from game-icons.
  static void _drawSvgCreature(
    Canvas canvas,
    Offset center,
    double radius,
    String cardId,
    Element element,
    Color baseColor,
    Color accentColor,
    int stars,
    double time,
  ) {
    final paths = kRpgSvgPaths[cardId];
    if (paths == null || paths.isEmpty) {
      // Fallback to generic element symbol
      _drawGeneric(canvas, center, radius, baseColor, element);
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius * 1.1);

    // Outer glow for 2★+
    if (stars >= 2) {
      final glowPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.12 * stars)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(center, radius * 1.15, glowPaint);
    }

    // Draw each SVG path with metallic gradient fill
    for (int i = 0; i < paths.length; i++) {
      final pathData = paths[i];
      final cacheKey =
          '$cardId:$pathData:${rect.width.toInt()}x${rect.height.toInt()}';

      ui.Path path;
      if (_svgPathCache.containsKey(cacheKey)) {
        path = _svgPathCache[cacheKey]!;
      } else {
        path = SvgPathParser.parseAndScale(
            pathData, Size(rect.width, rect.height));
        _svgPathCache[cacheKey] = path;
      }

      // Create metallic gradient fill based on element and star level
      final fillPaint = Paint()..style = PaintingStyle.fill;

      // Rich metallic/elemental gradient
      final gradient = _createElementalGradient(
          element, baseColor, accentColor, stars, rect);
      fillPaint.shader = gradient;

      // Draw path with gradient
      canvas.drawPath(path, fillPaint);
    }

    // Rim light - thin illuminated border (1.5px) for professional look
    if (stars >= 1) {
      for (int i = 0; i < paths.length; i++) {
        final pathData = paths[i];
        final cacheKey =
            '$cardId:$pathData:${rect.width.toInt()}x${rect.height.toInt()}';
        final path = _svgPathCache[cacheKey]!;

        final rimPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = accentColor.withValues(alpha: stars >= 4 ? 0.9 : 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
        canvas.drawPath(path, rimPaint);
      }
    }

    // Star-level specific enhancements on the SVG
    if (stars >= 2) {
      // Subtle animated particles around the SVG
      for (int i = 0; i < 6; i++) {
        final angle = time * (0.5 + i * 0.1) + i * math.pi / 3;
        final r = radius * 1.15 * (0.9 + 0.2 * math.sin(time * 1.5 + i));
        final pos = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
        final size = 2 + math.sin(time * 3 + i) * 1.5;
        canvas.drawCircle(
          pos,
          size,
          Paint()
            ..color = accentColor.withValues(alpha: 0.7)
            ..style = PaintingStyle.fill,
        );
      }
    }

    if (stars >= 3) {
      // Double power ring
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (int ring = 0; ring < 2; ring++) {
        final phase = time * (1.0 + ring * 0.3) + ring * 3.14;
        ringPaint.color = baseColor.withValues(
          alpha: 0.4 + 0.2 * math.sin(phase),
        );
        canvas.drawCircle(center, radius * (1.1 + ring * 0.15), ringPaint);
      }
    }

    if (stars >= 4) {
      // Rotating runic seal particles
      for (int i = 0; i < 8; i++) {
        final angle = time * 1.2 + i * math.pi / 4;
        final r = radius * (0.2 + 0.15 * math.sin(time * 2 + i));
        final pos = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
        canvas.drawCircle(
          pos,
          3,
          Paint()
            ..color = const Color(0xFFFFC93C).withValues(alpha: 0.9)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  /// Create a rich elemental gradient for the SVG fill.
  static Shader _createElementalGradient(
    Element element,
    Color baseColor,
    Color accentColor,
    int stars,
    Rect bounds,
  ) {
    switch (element) {
      case Element.igneous:
        // Molten gold to deep crimson
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: stars >= 4
              ? [
                  const Color(0xFFFFD700),
                  const Color(0xFFFF9E2C),
                  const Color(0xFFFF5A26),
                  const Color(0xFF8B1A1A),
                ]
              : [
                  baseColor.withValues(alpha: 0.9),
                  baseColor,
                  Color.lerp(baseColor, const Color(0xFF4A0A0A), 0.6)!,
                ],
        ).createShader(bounds);
      case Element.abyssal:
        // Glacial cyan to deep abyssal blue
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: stars >= 4
              ? [
                  const Color(0xFF80E8FF),
                  const Color(0xFF3FD8FF),
                  const Color(0xFF0E5C8A),
                  const Color(0xFF041E3A),
                ]
              : [
                  baseColor.withValues(alpha: 0.9),
                  baseColor,
                  Color.lerp(baseColor, const Color(0xFF041E3A), 0.6)!,
                ],
        ).createShader(bounds);
      case Element.telluric:
        // Burnished bronze to deep earth
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: stars >= 4
              ? [
                  const Color(0xFFF0D0A0),
                  const Color(0xFFB0703B),
                  const Color(0xFF8A5A2B),
                  const Color(0xFF3B2411),
                ]
              : [
                  baseColor.withValues(alpha: 0.9),
                  baseColor,
                  Color.lerp(baseColor, const Color(0xFF3B2411), 0.6)!,
                ],
        ).createShader(bounds);
      case Element.empty:
        // Void purple to cosmic pink
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: stars >= 4
              ? [
                  const Color(0xFFE5D4FF),
                  const Color(0xFFB16EFF),
                  const Color(0xFF8B2AFF),
                  const Color(0xFF2E0854),
                ]
              : [
                  baseColor.withValues(alpha: 0.9),
                  baseColor,
                  Color.lerp(baseColor, const Color(0xFF2E0854), 0.6)!,
                ],
        ).createShader(bounds);
    }
  }

  /// Procedural scenic landscape per element:
  /// - Igneous: Magma volcano peaks, molten lava river, ash sky
  /// - Abyssal: Ice cavern stalactites, glacial crystals, frosted deeps
  /// - Telluric: Monolithic ancient ruins, cracked stone pillars, mossy earth
  /// - Empty/Void: Nebular vortex, celestial crescent eclipse, astral dust
  static void _drawScenicBackground(
    Canvas canvas,
    Rect bounds,
    Element element,
    double time,
  ) {
    final w = bounds.width;
    final h = bounds.height;
    final bgRect = Rect.fromLTWH(0, 0, w, h);

    switch (element) {
      case Element.igneous:
        // Sky / Magma chamber gradient
        final skyPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0507), Color(0xFF380E09), Color(0xFF6B1808)],
          ).createShader(bgRect);
        canvas.drawRect(bgRect, skyPaint);

        // Volcano peaks silhouette
        final volcanoPath = Path()
          ..moveTo(0, h * 0.72)
          ..lineTo(w * 0.28, h * 0.38)
          ..lineTo(w * 0.44, h * 0.46)
          ..lineTo(w * 0.68, h * 0.28)
          ..lineTo(w, h * 0.78)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(
          volcanoPath,
          Paint()..color = const Color(0xFF1F090B),
        );

        // Molten magma glow crater
        final craterGlow = Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.36, -0.44),
            radius: 0.4,
            colors: [
              const Color(0xFFFF9E2C),
              const Color(0xFFFF3D00).withValues(alpha: 0.6),
              Colors.transparent,
            ],
          ).createShader(bgRect);
        canvas.drawCircle(Offset(w * 0.68, h * 0.3), w * 0.25, craterGlow);

        // Molten lava pool at base
        final lavaPath = Path()
          ..moveTo(0, h * 0.82)
          ..cubicTo(w * 0.35, h * 0.75, w * 0.65, h * 0.90, w, h * 0.80)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(
          lavaPath,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF7A00), Color(0xFFD62828), Color(0xFF4A0A0A)],
            ).createShader(Rect.fromLTWH(0, h * 0.75, w, h * 0.25)),
        );
        break;

      case Element.abyssal:
        // Ice cavern ceiling & glacial depths
        final iceSky = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF040E1E), Color(0xFF0A233F), Color(0xFF0D3B5C)],
          ).createShader(bgRect);
        canvas.drawRect(bgRect, iceSky);

        // Hanging stalactites
        final stalactites = Path()
          ..moveTo(0, 0)
          ..lineTo(w * 0.12, h * 0.30)
          ..lineTo(w * 0.22, 0)
          ..lineTo(w * 0.40, h * 0.42)
          ..lineTo(w * 0.52, 0)
          ..lineTo(w * 0.75, h * 0.34)
          ..lineTo(w * 0.88, 0)
          ..lineTo(w, h * 0.22)
          ..lineTo(w, 0)
          ..close();
        canvas.drawPath(
          stalactites,
          Paint()..color = const Color(0xFF081C30),
        );

        // Crystal frost shimmer glow
        final frostGlow = Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.0, 0.2),
            radius: 0.6,
            colors: [
              const Color(0xFF3FD8FF).withValues(alpha: 0.35),
              const Color(0xFF0E5C8A).withValues(alpha: 0.15),
              Colors.transparent,
            ],
          ).createShader(bgRect);
        canvas.drawRect(bgRect, frostGlow);

        // Glacial floor spikes
        final iceFloor = Path()
          ..moveTo(0, h)
          ..lineTo(w * 0.18, h * 0.76)
          ..lineTo(w * 0.32, h * 0.88)
          ..lineTo(w * 0.55, h * 0.70)
          ..lineTo(w * 0.78, h * 0.84)
          ..lineTo(w, h * 0.72)
          ..lineTo(w, h)
          ..close();
        canvas.drawPath(
          iceFloor,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF5CE1E6), Color(0xFF144D66), Color(0xFF071926)],
            ).createShader(Rect.fromLTWH(0, h * 0.65, w, h * 0.35)),
        );
        break;

      case Element.telluric:
        // Monolithic ancient ruins & dusk
        final earthSky = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E140C), Color(0xFF332014), Color(0xFF4A301E)],
          ).createShader(bgRect);
        canvas.drawRect(bgRect, earthSky);

        // Monolith pillars in perspective
        final monoliths = Path()
          // Pillar 1
          ..addRect(Rect.fromLTWH(w * 0.10, h * 0.25, w * 0.14, h * 0.65))
          // Broken lintel
          ..addRect(Rect.fromLTWH(w * 0.06, h * 0.20, w * 0.40, h * 0.08))
          // Pillar 2
          ..addRect(Rect.fromLTWH(w * 0.32, h * 0.27, w * 0.12, h * 0.63))
          // Distant obelisk
          ..addRect(Rect.fromLTWH(w * 0.75, h * 0.35, w * 0.12, h * 0.55));
        canvas.drawPath(
          monoliths,
          Paint()..color = const Color(0xFF160E08),
        );

        // Runes on pillars
        final runePaint = Paint()
          ..color = const Color(0xFFD4AF37).withValues(alpha: 0.45)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(w * 0.17, h * 0.38),
          Offset(w * 0.17, h * 0.60),
          runePaint,
        );
        canvas.drawLine(
          Offset(w * 0.38, h * 0.42),
          Offset(w * 0.38, h * 0.65),
          runePaint,
        );

        // Overgrown craggy earth ground
        final groundPath = Path()
          ..moveTo(0, h * 0.80)
          ..cubicTo(w * 0.3, h * 0.72, w * 0.7, h * 0.86, w, h * 0.78)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(
          groundPath,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF8A5A2B), Color(0xFF3B2411), Color(0xFF140C06)],
            ).createShader(Rect.fromLTWH(0, h * 0.72, w, h * 0.28)),
        );
        break;

      case Element.empty:
        // Void nebular eclipse
        final voidSky = Paint()
          ..shader = const RadialGradient(
            center: Alignment.center,
            radius: 0.8,
            colors: [Color(0xFF280B45), Color(0xFF120320), Color(0xFF07000C)],
          ).createShader(bgRect);
        canvas.drawRect(bgRect, voidSky);

        // Nebular vortex swirls
        final vortexPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const Color(0xFFB16EFF).withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        for (var i = 1; i <= 3; i++) {
          final arcR = w * (0.22 * i);
          canvas.drawArc(
            Rect.fromCircle(center: Offset(w * 0.5, h * 0.45), radius: arcR),
            time * 0.5 + i * 1.2,
            math.pi * 1.1,
            false,
            vortexPaint,
          );
        }

        // Celestial Eclipse Crescent
        final eclipseCenter = Offset(w * 0.5, h * 0.38);
        final eclipseRadius = w * 0.22;
        // Corona glow
        canvas.drawCircle(
          eclipseCenter,
          eclipseRadius * 1.35,
          Paint()
            ..color = const Color(0xFFDA70D6).withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
        );
        // Dark moon body
        canvas.drawCircle(
          eclipseCenter,
          eclipseRadius,
          Paint()..color = const Color(0xFF090212),
        );
        // Glowing eclipse ring rim
        canvas.drawArc(
          Rect.fromCircle(center: eclipseCenter, radius: eclipseRadius),
          -math.pi * 0.65,
          math.pi * 1.25,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..color = const Color(0xFFE5D4FF),
        );

        // Astral rift void bottom
        final riftPath = Path()
          ..moveTo(0, h * 0.84)
          ..lineTo(w * 0.35, h * 0.78)
          ..lineTo(w * 0.50, h * 0.88)
          ..lineTo(w * 0.72, h * 0.76)
          ..lineTo(w, h * 0.85)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(
          riftPath,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6B21A8), Color(0xFF2E0854), Color(0xFF0B0114)],
            ).createShader(Rect.fromLTWH(0, h * 0.75, w, h * 0.25)),
        );
        break;
    }
  }

  /// Draw the evolution frame (1★ iron -> 4★ animated gold).
  static void _drawEvolutionFrame(
    Canvas canvas,
    Offset center,
    double radius,
    int stars,
    Color baseColor,
    Color accentColor,
    double time,
  ) {
    final framePaint = Paint()..style = PaintingStyle.stroke;

    switch (stars) {
      case 1:
        // Iron forged frame - dark, thick, riveted
        framePaint.color = const Color(0xFF5A4A3A);
        framePaint.strokeWidth = 4;
        canvas.drawCircle(center, radius + 6, framePaint);
        // Rivets
        framePaint.color = const Color(0xFF3A2A1A);
        framePaint.style = PaintingStyle.fill;
        for (int i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          canvas.drawCircle(
            center +
                Offset(
                  math.cos(angle) * (radius + 6),
                  math.sin(angle) * (radius + 6),
                ),
            3,
            framePaint,
          );
        }
        break;

      case 2:
        // Bronze runic frame - runes etched
        framePaint.color = const Color(0xFFCD7F32);
        framePaint.strokeWidth = 4;
        canvas.drawCircle(center, radius + 6, framePaint);
        // Runes
        framePaint.color = const Color(0xFF8B5A2B);
        framePaint.strokeWidth = 1.5;
        framePaint.style = PaintingStyle.stroke;
        for (int i = 0; i < 12; i++) {
          final angle = i * math.pi / 6 + time * 0.1;
          final r1 = radius + 2;
          final r2 = radius + 10;
          canvas.drawLine(
            center + Offset(math.cos(angle) * r1, math.sin(angle) * r1),
            center + Offset(math.cos(angle) * r2, math.sin(angle) * r2),
            framePaint,
          );
        }
        break;

      case 3:
        // Silver abyssal frame - double ring with power symbols
        framePaint.color = const Color(0xFFC0C0C0);
        framePaint.strokeWidth = 3;
        canvas.drawCircle(center, radius + 8, framePaint);
        canvas.drawCircle(center, radius + 4, framePaint);
        // Inner power runes
        framePaint.color = const Color(0xFF8B8B8B);
        framePaint.strokeWidth = 2;
        for (int i = 0; i < 16; i++) {
          final angle = i * math.pi / 8 - time * 0.08;
          final r = radius + 6 + math.sin(time * 3 + i) * 2;
          canvas.drawCircle(
            center + Offset(math.cos(angle) * r, math.sin(angle) * r),
            2.5,
            framePaint..style = PaintingStyle.fill,
          );
        }
        break;

      case 4:
        // Gold infernal frame - animated, energy cracks, rotating seal
        // Outer animated ring
        framePaint.strokeWidth = 3;
        framePaint.style = PaintingStyle.stroke;
        for (int layer = 0; layer < 3; layer++) {
          final phase = time * (1.5 + layer * 0.5) + layer * 2.1;
          framePaint.color = Color.lerp(
            const Color(0xFFFFC93C),
            const Color(0xFFFF5A26),
            (math.sin(phase) + 1) / 2,
          )!;
          canvas.drawCircle(center, radius + 10 + layer * 3, framePaint);
        }
        // Energy cracks radiating from center
        framePaint.strokeWidth = 1.5;
        framePaint.style = PaintingStyle.stroke;
        for (int i = 0; i < 12; i++) {
          final angle = i * math.pi / 6 + time * 0.2;
          final crackLength = radius * (0.8 + 0.4 * math.sin(time * 5 + i));
          framePaint.color = Color.lerp(
            const Color(0xFFFFC93C),
            const Color(0xFFFF5A26),
            (math.sin(time * 7 + i) + 1) / 2,
          )!;
          canvas.drawLine(
            center,
            center +
                Offset(
                  math.cos(angle) * crackLength,
                  math.sin(angle) * crackLength,
                ),
            framePaint,
          );
        }
        // Rotating runic seal at center
        framePaint.strokeWidth = 2;
        framePaint.style = PaintingStyle.stroke;
        final sealRadius = radius * 0.15;
        for (int i = 0; i < 6; i++) {
          final angle = time * 0.8 + i * math.pi / 3;
          canvas.drawLine(
            center +
                Offset(
                  math.cos(angle) * sealRadius,
                  math.sin(angle) * sealRadius,
                ),
            center +
                Offset(
                  math.cos(angle) * sealRadius * 2.5,
                  math.sin(angle) * sealRadius * 2.5,
                ),
            framePaint..color = const Color(0xFFFFC93C).withValues(alpha: 0.8),
          );
        }
        break;
    }
  }

  // --- Star-level visual effects ---

  static void _drawStarEffects(
    Canvas canvas,
    Offset center,
    double radius,
    Element element,
    Color baseColor,
    Color accentColor,
    int stars,
    double time,
  ) {
    if (stars >= 2) {
      // Floating particles
      for (int i = 0; i < 6; i++) {
        final angle = time * (0.5 + i * 0.1) + i * math.pi / 3;
        final r = radius * (0.9 + 0.3 * math.sin(time * 1.5 + i));
        final pos = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
        final size = 2 + math.sin(time * 3 + i) * 1.5;
        canvas.drawCircle(
          pos,
          size,
          Paint()
            ..color = accentColor.withValues(alpha: 0.6)
            ..style = PaintingStyle.fill,
        );
      }
    }

    if (stars >= 3) {
      // Double power ring
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (int ring = 0; ring < 2; ring++) {
        final phase = time * (1.0 + ring * 0.3) + ring * 3.14;
        ringPaint.color = baseColor.withValues(
          alpha: 0.4 + 0.2 * math.sin(phase),
        );
        canvas.drawCircle(center, radius * (1.1 + ring * 0.15), ringPaint);
      }
    }

    if (stars >= 4) {
      // Radiant energy cracks (already drawn in frame)
      // Additional: rotating runic seal particles
      for (int i = 0; i < 8; i++) {
        final angle = time * 1.2 + i * math.pi / 4;
        final r = radius * (0.2 + 0.15 * math.sin(time * 2 + i));
        final pos = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
        canvas.drawCircle(
          pos,
          3,
          Paint()
            ..color = const Color(0xFFFFC93C).withValues(alpha: 0.9)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  static void _drawGeneric(
    Canvas canvas,
    Offset center,
    double radius,
    Color baseColor,
    Element element,
  ) {
    // Element symbol fallback
    final symbolPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    switch (element) {
      case Element.igneous:
        // Flame
        final path = Path();
        path.moveTo(center.dx, center.dy + radius * 0.3);
        path.quadraticBezierTo(
          center.dx - radius * 0.2,
          center.dy,
          center.dx,
          center.dy - radius * 0.3,
        );
        path.quadraticBezierTo(
          center.dx + radius * 0.2,
          center.dy,
          center.dx,
          center.dy + radius * 0.3,
        );
        canvas.drawPath(path, symbolPaint);
        break;
      case Element.abyssal:
        // Water drop
        canvas.drawCircle(center, radius * 0.25, symbolPaint);
        break;
      case Element.telluric:
        // Mountain
        final path = Path();
        path.moveTo(center.dx, center.dy - radius * 0.3);
        path.lineTo(center.dx - radius * 0.3, center.dy + radius * 0.2);
        path.lineTo(center.dx + radius * 0.3, center.dy + radius * 0.2);
        path.close();
        canvas.drawPath(path, symbolPaint);
        break;
      case Element.empty:
        // Void circle
        canvas.drawCircle(
          center,
          radius * 0.25,
          symbolPaint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        break;
    }
  }
}

/// Widget for easy use in Flutter UI.
class CreaturePortrait extends StatelessWidget {
  final String cardId;
  final int stars;
  final double size;
  final double animationTime;

  const CreaturePortrait({
    super.key,
    required this.cardId,
    this.stars = 1,
    this.size = 120,
    this.animationTime = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CreaturePortraitPainter(
        cardId: cardId,
        stars: stars,
        time: animationTime,
      ),
    );
  }
}

class _CreaturePortraitPainter extends CustomPainter {
  final String cardId;
  final int stars;
  final double time;

  _CreaturePortraitPainter({
    required this.cardId,
    required this.stars,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    CreatureProceduralArt.drawPortrait(
      canvas,
      Rect.fromLTWH(0, 0, size.width, size.height),
      cardId,
      stars: stars,
      time: time,
    );
  }

  @override
  bool shouldRepaint(covariant _CreaturePortraitPainter oldDelegate) =>
      oldDelegate.cardId != cardId ||
      oldDelegate.stars != stars ||
      oldDelegate.time != time;
}
