import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../domain/value_objects/element.dart';

/// Procedural artwork system for creature portraits with 4 evolution stages.
/// Generates detailed geometric silhouettes with lighting layers instead of generic icons.
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

    // Draw creature silhouette (varies by card ID)
    _drawCreatureSilhouette(
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

  /// Draw the creature's unique geometric silhouette.
  static void _drawCreatureSilhouette(
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
    final silhouettePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final highlightPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final eyePaint = Paint()..style = PaintingStyle.fill;

    // Each card has a unique silhouette
    switch (cardId) {
      case 'ignis_hound':
        _drawIgnisHound(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'ignis_lord':
        _drawIgnisLord(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'abyss_stalker':
        _drawAbyssStalker(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'abyss_leviathan':
        _drawAbyssLeviathan(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'terra_golem':
        _drawTerraGolem(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'terra_titan':
        _drawTerraTitan(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'void_specter':
        _drawVoidSpecter(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'void_malakor':
        _drawVoidMalakor(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'ignis_drake':
        _drawIgnisDrake(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'ignis_seraph':
        _drawIgnisSeraph(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'ignis_colossus':
        _drawIgnisColossus(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'abyss_siren':
        _drawAbyssSiren(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'abyss_kraken':
        _drawAbyssKraken(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'abyss_wraith':
        _drawAbyssWraith(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'terra_warden':
        _drawTerraWarden(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'terra_hydra':
        _drawTerraHydra(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'terra_behemoth':
        _drawTerraBehemoth(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'void_reaper':
        _drawVoidReaper(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'void_oracle':
        _drawVoidOracle(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      case 'void_archon':
        _drawVoidArchon(
          canvas,
          center,
          radius,
          silhouettePaint,
          highlightPaint,
          eyePaint,
          stars,
          time,
        );
        break;
      default:
        _drawGeneric(canvas, center, radius, silhouettePaint, element);
    }

    // Eyes glow more at higher stars
    if (stars >= 2) {
      eyePaint.color = accentColor;
      eyePaint.maskFilter = MaskFilter.blur(BlurStyle.normal, stars * 2.0);
    } else {
      eyePaint.color = accentColor.withValues(alpha: 0.8);
    }
  }

  // --- Individual creature silhouettes ---

  static void _drawIgnisHound(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Wolf-like: elongated snout, pointed ears, hunched posture
    final path = Path();
    final r = radius;
    // Main body
    path.moveTo(center.dx, center.dy - r * 0.6);
    path.quadraticBezierTo(
      center.dx + r * 0.5,
      center.dy - r * 0.9,
      center.dx + r * 0.7,
      center.dy - r * 0.3,
    );
    path.quadraticBezierTo(
      center.dx + r * 0.9,
      center.dy + r * 0.1,
      center.dx + r * 0.5,
      center.dy + r * 0.4,
    );
    path.quadraticBezierTo(
      center.dx,
      center.dy + r * 0.7,
      center.dx - r * 0.5,
      center.dy + r * 0.4,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.9,
      center.dy + r * 0.1,
      center.dx - r * 0.7,
      center.dy - r * 0.3,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.5,
      center.dy - r * 0.9,
      center.dx,
      center.dy - r * 0.6,
    );
    canvas.drawPath(path, silhouette);

    // Ears
    final earPath = Path();
    earPath.moveTo(center.dx - r * 0.4, center.dy - r * 0.7);
    earPath.lineTo(center.dx - r * 0.6, center.dy - r * 1.1);
    earPath.lineTo(center.dx - r * 0.2, center.dy - r * 0.5);
    earPath.close();
    earPath.moveTo(center.dx + r * 0.4, center.dy - r * 0.7);
    earPath.lineTo(center.dx + r * 0.6, center.dy - r * 1.1);
    earPath.lineTo(center.dx + r * 0.2, center.dy - r * 0.5);
    earPath.close();
    canvas.drawPath(earPath, silhouette);

    // Eyes
    canvas.drawCircle(
      center + Offset(-r * 0.2, center.dy - r * 0.3),
      r * 0.07,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.2, center.dy - r * 0.3),
      r * 0.07,
      eye,
    );

    // Ember particles at 2★+
    if (stars >= 2) {
      for (int i = 0; i < 4; i++) {
        final angle = time * 2 + i * math.pi / 2;
        final p = center +
            Offset(math.cos(angle) * r * 0.8, math.sin(angle) * r * 0.8);
        canvas.drawCircle(p, 2 + math.sin(time * 5 + i) * 1, highlight);
      }
    }
  }

  static void _drawIgnisLord(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Majestic demon: horns, broad shoulders, wings suggested
    final r = radius;
    // Main body - broader
    final path = Path();
    path.moveTo(center.dx, center.dy - r * 0.5);
    path.quadraticBezierTo(
      center.dx + r * 0.6,
      center.dy - r * 0.8,
      center.dx + r * 0.8,
      center.dy - r * 0.2,
    );
    path.quadraticBezierTo(
      center.dx + r * 1.0,
      center.dy + r * 0.3,
      center.dx + r * 0.5,
      center.dy + r * 0.5,
    );
    path.quadraticBezierTo(
      center.dx,
      center.dy + r * 0.8,
      center.dx - r * 0.5,
      center.dy + r * 0.5,
    );
    path.quadraticBezierTo(
      center.dx - r * 1.0,
      center.dy + r * 0.3,
      center.dx - r * 0.8,
      center.dy - r * 0.2,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.6,
      center.dy - r * 0.8,
      center.dx,
      center.dy - r * 0.5,
    );
    canvas.drawPath(path, silhouette);

    // Horns
    final hornPath = Path();
    hornPath.moveTo(center.dx - r * 0.35, center.dy - r * 0.6);
    hornPath.quadraticBezierTo(
      center.dx - r * 0.5,
      center.dy - r * 1.0,
      center.dx - r * 0.7,
      center.dy - r * 1.2,
    );
    hornPath.lineTo(center.dx - r * 0.6, center.dy - r * 1.0);
    hornPath.quadraticBezierTo(
      center.dx - r * 0.4,
      center.dy - r * 0.8,
      center.dx - r * 0.35,
      center.dy - r * 0.6,
    );
    canvas.drawPath(hornPath, silhouette);

    hornPath.reset();
    hornPath.moveTo(center.dx + r * 0.35, center.dy - r * 0.6);
    hornPath.quadraticBezierTo(
      center.dx + r * 0.5,
      center.dy - r * 1.0,
      center.dx + r * 0.7,
      center.dy - r * 1.2,
    );
    hornPath.lineTo(center.dx + r * 0.6, center.dy - r * 1.0);
    hornPath.quadraticBezierTo(
      center.dx + r * 0.4,
      center.dy - r * 0.8,
      center.dx + r * 0.35,
      center.dy - r * 0.6,
    );
    canvas.drawPath(hornPath, silhouette);

    // Wings suggested
    final wingPath = Path();
    wingPath.moveTo(center.dx + r * 0.5, center.dy - r * 0.2);
    wingPath.quadraticBezierTo(
      center.dx + r * 1.1,
      center.dy - r * 0.4,
      center.dx + r * 0.9,
      center.dy + r * 0.4,
    );
    wingPath.lineTo(center.dx + r * 0.6, center.dy + r * 0.2);
    wingPath.quadraticBezierTo(
      center.dx + r * 0.7,
      center.dy,
      center.dx + r * 0.5,
      center.dy - r * 0.2,
    );
    canvas.drawPath(
      wingPath,
      silhouette..color = silhouette.color.withValues(alpha: 0.6),
    );

    wingPath.reset();
    wingPath.moveTo(center.dx - r * 0.5, center.dy - r * 0.2);
    wingPath.quadraticBezierTo(
      center.dx - r * 1.1,
      center.dy - r * 0.4,
      center.dx - r * 0.9,
      center.dy + r * 0.4,
    );
    wingPath.lineTo(center.dx - r * 0.6, center.dy + r * 0.2);
    wingPath.quadraticBezierTo(
      center.dx - r * 0.7,
      center.dy,
      center.dx - r * 0.5,
      center.dy - r * 0.2,
    );
    canvas.drawPath(
      wingPath,
      silhouette..color = silhouette.color.withValues(alpha: 0.6),
    );

    // Eyes
    canvas.drawCircle(
      center + Offset(-r * 0.2, center.dy - r * 0.2),
      r * 0.09,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.2, center.dy - r * 0.2),
      r * 0.09,
      eye,
    );

    // Crown at 3★+
    if (stars >= 3) {
      final crownPath = Path();
      for (int i = 0; i < 5; i++) {
        final x = center.dx - r * 0.4 + i * r * 0.2;
        final h = r * (0.15 + (i % 2) * 0.1);
        crownPath.moveTo(x, center.dy - r * 0.55);
        crownPath.lineTo(x, center.dy - r * 0.55 - h);
        crownPath.lineTo(x + r * 0.1, center.dy - r * 0.55);
      }
      canvas.drawPath(crownPath, highlight);
    }
  }

  static void _drawAbyssStalker(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Lurking predator: low profile, elongated, tendrils
    final r = radius;
    final path = Path();
    path.moveTo(center.dx, center.dy - r * 0.4);
    path.quadraticBezierTo(
      center.dx + r * 0.7,
      center.dy - r * 0.5,
      center.dx + r * 0.8,
      center.dy + r * 0.1,
    );
    path.quadraticBezierTo(
      center.dx + r * 0.6,
      center.dy + r * 0.5,
      center.dx,
      center.dy + r * 0.6,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.6,
      center.dy + r * 0.5,
      center.dx - r * 0.8,
      center.dy + r * 0.1,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.7,
      center.dy - r * 0.5,
      center.dx,
      center.dy - r * 0.4,
    );
    canvas.drawPath(path, silhouette);

    // Tendrils
    for (int i = 0; i < 3; i++) {
      final tendrilPath = Path();
      final startX = center.dx - r * 0.4 + i * r * 0.4;
      tendrilPath.moveTo(startX, center.dy + r * 0.3);
      tendrilPath.quadraticBezierTo(
        startX + math.sin(time * 3 + i) * r * 0.3,
        center.dy + r * 0.8,
        startX + math.sin(time * 3 + i + 1) * r * 0.2,
        center.dy + r * 1.2,
      );
      canvas.drawPath(
        tendrilPath,
        Paint()
          ..color = silhouette.color.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // Single glowing eye (stalker)
    canvas.drawCircle(center + Offset(0, center.dy - r * 0.15), r * 0.12, eye);
  }

  static void _drawAbyssLeviathan(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Massive sea serpent / leviathan: coiled, scaled, ancient
    final r = radius;
    // Coiled body
    for (int coil = 0; coil < 3; coil++) {
      final cx = center.dx + math.sin(time * 0.5 + coil) * r * 0.2;
      final cy = center.dy - r * 0.5 + coil * r * 0.5;
      final coilR = r * (0.45 - coil * 0.1);
      canvas.drawCircle(
        Offset(cx, cy),
        coilR,
        Paint()..color = silhouette.color.withValues(alpha: 0.9 - coil * 0.1),
      );
    }
    // Head
    final headPath = Path();
    headPath.moveTo(center.dx + r * 0.3, center.dy - r * 0.5);
    headPath.quadraticBezierTo(
      center.dx + r * 0.6,
      center.dy - r * 0.7,
      center.dx + r * 0.8,
      center.dy - r * 0.3,
    );
    headPath.quadraticBezierTo(
      center.dx + r * 0.7,
      center.dy,
      center.dx + r * 0.6,
      center.dy + r * 0.3,
    );
    headPath.lineTo(center.dx + r * 0.3, center.dy + r * 0.1);
    canvas.drawPath(headPath, silhouette);

    // Eyes
    canvas.drawCircle(
      center + Offset(r * 0.5, center.dy - r * 0.35),
      r * 0.08,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.7, center.dy - r * 0.35),
      r * 0.08,
      eye,
    );

    // Fins at 3★+
    if (stars >= 3) {
      final finPath = Path();
      finPath.moveTo(center.dx + r * 0.5, center.dy - r * 0.5);
      finPath.lineTo(center.dx + r * 0.8, center.dy - r * 0.9);
      finPath.lineTo(center.dx + r * 0.7, center.dy - r * 0.4);
      canvas.drawPath(finPath, highlight);
    }
  }

  static void _drawTerraGolem(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Rock construct: blocky, geometric, runes etched
    final r = radius;
    // Main rectangular body with beveled edges
    final bodyPath = Path();
    bodyPath.addRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: center, width: r * 1.3, height: r * 1.1),
        topLeft: Radius.circular(r * 0.15),
        topRight: Radius.circular(r * 0.15),
        bottomLeft: Radius.circular(r * 0.1),
        bottomRight: Radius.circular(r * 0.1),
      ),
    );
    canvas.drawPath(bodyPath, silhouette);

    // Shoulders
    final shoulderPath = Path();
    shoulderPath.addRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(
          center: center + Offset(-r * 0.7, center.dy - r * 0.2),
          width: r * 0.5,
          height: r * 0.4,
        ),
        topLeft: Radius.circular(r * 0.1),
        topRight: Radius.circular(r * 0.05),
      ),
    );
    canvas.drawPath(shoulderPath, silhouette);
    shoulderPath.reset();
    shoulderPath.addRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(
          center: center + Offset(r * 0.7, center.dy - r * 0.2),
          width: r * 0.5,
          height: r * 0.4,
        ),
        topLeft: Radius.circular(r * 0.05),
        topRight: Radius.circular(r * 0.1),
      ),
    );
    canvas.drawPath(shoulderPath, silhouette);

    // Runes etched on body
    if (stars >= 2) {
      final runePaint = Paint()
        ..color = highlight.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (int i = 0; i < 4; i++) {
        final x = center.dx - r * 0.3 + i * r * 0.2;
        final y = center.dy - r * 0.1 + math.sin(time + i) * r * 0.05;
        canvas.drawLine(Offset(x, y), Offset(x, y + r * 0.3), runePaint);
        canvas.drawLine(
          Offset(x - r * 0.1, y + r * 0.15),
          Offset(x + r * 0.1, y + r * 0.15),
          runePaint,
        );
      }
    }

    // Eyes
    canvas.drawCircle(
      center + Offset(-r * 0.2, center.dy - r * 0.2),
      r * 0.08,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.2, center.dy - r * 0.2),
      r * 0.08,
      eye,
    );
  }

  static void _drawTerraTitan(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Mountain titan: massive, layered stone, crown of peaks
    final r = radius;
    // Base body
    final bodyPath = Path();
    bodyPath.moveTo(center.dx, center.dy - r * 0.7);
    bodyPath.lineTo(center.dx + r * 0.8, center.dy + r * 0.1);
    bodyPath.lineTo(center.dx + r * 0.5, center.dy + r * 0.6);
    bodyPath.lineTo(center.dx - r * 0.5, center.dy + r * 0.6);
    bodyPath.lineTo(center.dx - r * 0.8, center.dy + r * 0.1);
    bodyPath.close();
    canvas.drawPath(bodyPath, silhouette);

    // Layered stone strata
    final strataPaint = Paint()
      ..color = highlight.color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 0; i < 5; i++) {
      final y = center.dy - r * 0.6 + i * r * 0.25;
      final offsetFromCenter = (y - center.dy).abs();
      canvas.drawLine(
        Offset(center.dx - r * 0.5 + offsetFromCenter * 0.5, y),
        Offset(center.dx + r * 0.5 - offsetFromCenter * 0.5, y),
        strataPaint,
      );
    }

    // Crown of peaks
    if (stars >= 3) {
      final peakPaint = Paint()..color = highlight.color;
      for (int i = 0; i < 7; i++) {
        final x = center.dx - r * 0.5 + i * r * 0.16;
        final h = r * (0.1 + math.sin(time * 2 + i) * 0.05 + i % 3 * 0.05);
        final peakPath = Path();
        peakPath.moveTo(x, center.dy - r * 0.7);
        peakPath.lineTo(x - r * 0.08, center.dy - r * 0.7 - h);
        peakPath.lineTo(x + r * 0.08, center.dy - r * 0.7);
        canvas.drawPath(peakPath, peakPaint);
      }
    }

    // Eyes
    canvas.drawCircle(
      center + Offset(-r * 0.25, center.dy - r * 0.3),
      r * 0.1,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.25, center.dy - r * 0.3),
      r * 0.1,
      eye,
    );
  }

  static void _drawVoidSpecter(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Ethereal specter: wispy, translucent, mask-like face
    final r = radius;
    // Main wisp body
    final path = Path();
    path.moveTo(center.dx, center.dy - r * 0.5);
    path.quadraticBezierTo(
      center.dx + r * 0.6,
      center.dy - r * 0.7,
      center.dx + r * 0.7,
      center.dy - r * 0.1,
    );
    path.quadraticBezierTo(
      center.dx + r * 0.8,
      center.dy + r * 0.4,
      center.dx + r * 0.4,
      center.dy + r * 0.7,
    );
    path.quadraticBezierTo(
      center.dx,
      center.dy + r * 0.9,
      center.dx - r * 0.4,
      center.dy + r * 0.7,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.8,
      center.dy + r * 0.4,
      center.dx - r * 0.7,
      center.dy - r * 0.1,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.6,
      center.dy - r * 0.7,
      center.dx,
      center.dy - r * 0.5,
    );
    canvas.drawPath(
      path,
      silhouette..color = silhouette.color.withValues(alpha: 0.6),
    );

    // Mask-like face
    final facePath = Path();
    facePath.addOval(
      Rect.fromCenter(
        center: center + Offset(0, center.dy - r * 0.1),
        width: r * 0.6,
        height: r * 0.5,
      ),
    );
    canvas.drawPath(
      facePath,
      Paint()
        ..color = const Color(0xFF1A0A1A)
        ..style = PaintingStyle.fill,
    );

    // Hollow eyes
    canvas.drawCircle(
      center + Offset(-r * 0.15, center.dy - r * 0.15),
      r * 0.1,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.15, center.dy - r * 0.15),
      r * 0.1,
      eye,
    );

    // Wisps at 2★+
    if (stars >= 2) {
      for (int i = 0; i < 6; i++) {
        final angle = time * 0.8 + i * math.pi / 3;
        final wispPath = Path();
        wispPath.moveTo(center.dx, center.dy);
        wispPath.quadraticBezierTo(
          center.dx + math.cos(angle) * r * 0.8,
          center.dy + math.sin(angle) * r * 0.8,
          center.dx + math.cos(angle) * r * 1.3,
          center.dy + math.sin(angle) * r * 1.3,
        );
        canvas.drawPath(
          wispPath,
          Paint()
            ..color = highlight.color.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  static void _drawVoidMalakor(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Abyssal herald: regal, multi-limbed, crown of void, reality tears
    final r = radius;
    // Main form
    final path = Path();
    path.moveTo(center.dx, center.dy - r * 0.6);
    path.quadraticBezierTo(
      center.dx + r * 0.5,
      center.dy - r * 0.8,
      center.dx + r * 0.7,
      center.dy - r * 0.2,
    );
    path.quadraticBezierTo(
      center.dx + r * 0.9,
      center.dy + r * 0.3,
      center.dx + r * 0.4,
      center.dy + r * 0.5,
    );
    path.quadraticBezierTo(
      center.dx,
      center.dy + r * 0.8,
      center.dx - r * 0.4,
      center.dy + r * 0.5,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.9,
      center.dy + r * 0.3,
      center.dx - r * 0.7,
      center.dy - r * 0.2,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.5,
      center.dy - r * 0.8,
      center.dx,
      center.dy - r * 0.6,
    );
    canvas.drawPath(path, silhouette);

    // Four arms
    for (int arm = 0; arm < 4; arm++) {
      final angle =
          -math.pi / 2 + arm * math.pi / 2 + math.sin(time + arm) * 0.1;
      final armPath = Path();
      armPath.moveTo(
        center.dx + math.cos(angle) * r * 0.5,
        center.dy + math.sin(angle) * r * 0.5,
      );
      armPath.quadraticBezierTo(
        center.dx + math.cos(angle) * r * 0.9,
        center.dy + math.sin(angle) * r * 0.9,
        center.dx + math.cos(angle) * r * 1.2,
        center.dy + math.sin(angle) * r * 1.2,
      );
      canvas.drawPath(
        armPath,
        Paint()
          ..color = silhouette.color.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }

    // Crown of void (reality tears)
    if (stars >= 3) {
      for (int i = 0; i < 8; i++) {
        final angle = time * 0.3 + i * math.pi / 4;
        final tearPath = Path();
        tearPath.moveTo(
          center.dx + math.cos(angle) * r * 0.7,
          center.dy + math.sin(angle) * r * 0.7,
        );
        tearPath.quadraticBezierTo(
          center.dx + math.cos(angle) * r * 1.0,
          center.dy + math.sin(angle) * r * 1.0,
          center.dx + math.cos(angle) * r * 1.3,
          center.dy + math.sin(angle) * r * 1.3,
        );
        canvas.drawPath(
          tearPath,
          Paint()
            ..color = highlight.color.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Third eye + normal eyes
    canvas.drawCircle(center + Offset(0, center.dy - r * 0.35), r * 0.1, eye);
    canvas.drawCircle(
      center + Offset(-r * 0.2, center.dy - r * 0.1),
      r * 0.08,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.2, center.dy - r * 0.1),
      r * 0.08,
      eye,
    );
  }

  // --- New creature silhouettes (Phase 13 catalog expansion) ---

  static void _drawIgnisDrake(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Drake: winged serpent, low swoop, tail curled
    final r = radius;
    final path = Path();
    path.moveTo(center.dx, center.dy - r * 0.5);
    path.quadraticBezierTo(
      center.dx + r * 0.7,
      center.dy - r * 0.8,
      center.dx + r * 0.6,
      center.dy - r * 0.1,
    );
    path.quadraticBezierTo(
      center.dx + r * 0.8,
      center.dy + r * 0.3,
      center.dx + r * 0.3,
      center.dy + r * 0.5,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.3,
      center.dy + r * 0.6,
      center.dx - r * 0.6,
      center.dy + r * 0.1,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.7,
      center.dy - r * 0.3,
      center.dx - r * 0.5,
      center.dy - r * 0.6,
    );
    path.close();
    canvas.drawPath(path, silhouette);
    final wingPath = Path();
    wingPath.moveTo(center.dx - r * 0.4, center.dy - r * 0.4);
    wingPath.lineTo(center.dx - r * 1.0, center.dy - r * 0.9);
    wingPath.lineTo(center.dx - r * 0.6, center.dy - r * 0.2);
    canvas.drawPath(wingPath, highlight);
    canvas.drawCircle(
      center + Offset(-r * 0.15, center.dy - r * 0.2),
      r * 0.09,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.15, center.dy - r * 0.2),
      r * 0.09,
      eye,
    );
  }

  static void _drawIgnisSeraph(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Seraph: humanoid with large wings, halo
    final r = radius;
    final path = Path();
    path.moveTo(center.dx, center.dy - r * 0.55);
    path.quadraticBezierTo(
      center.dx + r * 0.45,
      center.dy - r * 0.75,
      center.dx + r * 0.5,
      center.dy - r * 0.2,
    );
    path.quadraticBezierTo(
      center.dx + r * 0.55,
      center.dy + r * 0.2,
      center.dx + r * 0.35,
      center.dy + r * 0.5,
    );
    path.quadraticBezierTo(
      center.dx,
      center.dy + r * 0.8,
      center.dx - r * 0.35,
      center.dy + r * 0.5,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.55,
      center.dy + r * 0.2,
      center.dx - r * 0.5,
      center.dy - r * 0.2,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.45,
      center.dy - r * 0.75,
      center.dx,
      center.dy - r * 0.55,
    );
    canvas.drawPath(path, silhouette);
    final haloPaint = Paint()
      ..color = const Color(0xFFFFC93C).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      Offset(center.dx, center.dy - r * 0.75),
      r * 0.18,
      haloPaint,
    );
    canvas.drawCircle(
      center + Offset(-r * 0.18, center.dy - r * 0.3),
      r * 0.08,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.18, center.dy - r * 0.3),
      r * 0.08,
      eye,
    );
  }

  static void _drawIgnisColossus(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Colossus: massive, blocky, broad shoulders, crown of magma
    final r = radius;
    final bodyPath = Path();
    bodyPath.addRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: center, width: r * 1.5, height: r * 1.2),
        topLeft: Radius.circular(r * 0.1),
        topRight: Radius.circular(r * 0.1),
        bottomLeft: Radius.circular(r * 0.05),
        bottomRight: Radius.circular(r * 0.05),
      ),
    );
    canvas.drawPath(bodyPath, silhouette);
    final crackPaint = Paint()
      ..color = const Color(0xFFFFC93C).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < 5; i++) {
      final x = center.dx - r * 0.4 + i * r * 0.2;
      final y = center.dy - r * 0.4 + math.sin(time + i) * r * 0.05;
      canvas.drawLine(Offset(x, y), Offset(x, y + r * 0.5), crackPaint);
    }
    canvas.drawCircle(
      center + Offset(-r * 0.25, center.dy - r * 0.25),
      r * 0.1,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.25, center.dy - r * 0.25),
      r * 0.1,
      eye,
    );
  }

  static void _drawAbyssSiren(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Siren: slender, fish-tail lower body, long hair flowing
    final r = radius;
    final path = Path();
    path.moveTo(center.dx, center.dy - r * 0.5);
    path.quadraticBezierTo(
      center.dx + r * 0.4,
      center.dy - r * 0.7,
      center.dx + r * 0.45,
      center.dy - r * 0.2,
    );
    path.quadraticBezierTo(
      center.dx + r * 0.5,
      center.dy + r * 0.1,
      center.dx + r * 0.3,
      center.dy + r * 0.4,
    );
    path.quadraticBezierTo(
      center.dx + r * 0.2,
      center.dy + r * 0.7,
      center.dx,
      center.dy + r * 0.9,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.2,
      center.dy + r * 0.7,
      center.dx - r * 0.3,
      center.dy + r * 0.4,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.5,
      center.dy + r * 0.1,
      center.dx - r * 0.45,
      center.dy - r * 0.2,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.4,
      center.dy - r * 0.7,
      center.dx,
      center.dy - r * 0.5,
    );
    canvas.drawPath(path, silhouette);
    for (int i = 0; i < 4; i++) {
      final strandPath = Path();
      strandPath.moveTo(
        center.dx - r * 0.3 + i * r * 0.2,
        center.dy - r * 0.4,
      );
      strandPath.quadraticBezierTo(
        center.dx - r * 0.5 + i * r * 0.25,
        center.dy + math.cos(time + i) * r * 0.4,
        center.dx - r * 0.4 + i * r * 0.2,
        center.dy + r * 0.8,
      );
      canvas.drawPath(
        strandPath,
        Paint()
          ..color = highlight.color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(
      center + Offset(0, center.dy - r * 0.2),
      r * 0.11,
      eye,
    );
  }

  static void _drawAbyssKraken(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Kraken: massive, coiled tentacles, central mass
    final r = radius;
    for (int t = 0; t < 5; t++) {
      final angle = time * 0.4 + t * math.pi * 2 / 5;
      final tentaclePath = Path();
      tentaclePath.moveTo(center.dx, center.dy);
      tentaclePath.quadraticBezierTo(
        center.dx + math.cos(angle) * r * 0.6,
        center.dy + math.sin(angle) * r * 0.6,
        center.dx + math.cos(angle) * r * 1.1,
        center.dy + math.sin(angle) * r * 1.1,
      );
      canvas.drawPath(
        tentaclePath,
        Paint()
          ..color = silhouette.color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(center, r * 0.5, silhouette);
    canvas.drawCircle(
      center + Offset(-r * 0.15, center.dy - r * 0.1),
      r * 0.1,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.15, center.dy - r * 0.1),
      r * 0.1,
      eye,
    );
  }

  static void _drawAbyssWraith(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Wraith: ethereal, tattered cloak, single glowing eye
    final r = radius;
    final path = Path();
    path.moveTo(center.dx, center.dy - r * 0.4);
    path.quadraticBezierTo(
      center.dx + r * 0.5,
      center.dy - r * 0.5,
      center.dx + r * 0.5,
      center.dy + r * 0.1,
    );
    path.quadraticBezierTo(
      center.dx + r * 0.6,
      center.dy + r * 0.5,
      center.dx + r * 0.3,
      center.dy + r * 0.8,
    );
    path.quadraticBezierTo(
      center.dx,
      center.dy + r * 1.0,
      center.dx - r * 0.3,
      center.dy + r * 0.8,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.6,
      center.dy + r * 0.5,
      center.dx - r * 0.5,
      center.dy + r * 0.1,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.5,
      center.dy - r * 0.5,
      center.dx,
      center.dy - r * 0.4,
    );
    canvas.drawPath(
      path,
      silhouette..color = silhouette.color.withValues(alpha: 0.65),
    );
    canvas.drawCircle(center + Offset(0, center.dy - r * 0.15), r * 0.14, eye);
    final hemPaint = Paint()
      ..color = highlight.color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < 6; i++) {
      final x = center.dx - r * 0.4 + i * r * 0.15;
      canvas.drawLine(
        Offset(x, center.dy + r * 0.8),
        Offset(x, center.dy + r * 1.0),
        hemPaint,
      );
    }
  }

  static void _drawTerraWarden(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Warden: stout, shield-bearing, stone plating
    final r = radius;
    final bodyPath = Path();
    bodyPath.addRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: center, width: r * 1.1, height: r * 1.0),
        topLeft: Radius.circular(r * 0.15),
        topRight: Radius.circular(r * 0.15),
        bottomLeft: Radius.circular(r * 0.1),
        bottomRight: Radius.circular(r * 0.1),
      ),
    );
    canvas.drawPath(bodyPath, silhouette);
    final shieldPath = Path();
    shieldPath.moveTo(center.dx + r * 0.55, center.dy - r * 0.2);
    shieldPath.quadraticBezierTo(
      center.dx + r * 0.9,
      center.dy - r * 0.5,
      center.dx + r * 0.85,
      center.dy + r * 0.2,
    );
    shieldPath.quadraticBezierTo(
      center.dx + r * 0.8,
      center.dy + r * 0.5,
      center.dx + r * 0.55,
      center.dy + r * 0.3,
    );
    canvas.drawPath(shieldPath, highlight);
    canvas.drawCircle(
      center + Offset(-r * 0.2, center.dy - r * 0.2),
      r * 0.09,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.2, center.dy - r * 0.2),
      r * 0.09,
      eye,
    );
  }

  static void _drawTerraHydra(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Hydra: multiple heads on serpentine necks
    final r = radius;
    canvas.drawCircle(center, r * 0.45, silhouette);
    for (int h = 0; h < 3; h++) {
      final angle = -math.pi / 2 + h * math.pi / 3 + math.sin(time + h) * 0.1;
      final headPath = Path();
      headPath.moveTo(
        center.dx + math.cos(angle) * r * 0.5,
        center.dy + math.sin(angle) * r * 0.5,
      );
      headPath.quadraticBezierTo(
        center.dx + math.cos(angle) * r * 0.8,
        center.dy + math.sin(angle) * r * 0.8,
        center.dx + math.cos(angle) * r * 1.05,
        center.dy + math.sin(angle) * r * 1.05,
      );
      canvas.drawPath(
        headPath,
        Paint()
          ..color = silhouette.color.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * r * 1.05,
          center.dy + math.sin(angle) * r * 1.05,
        ),
        r * 0.1,
        eye,
      );
    }
  }

  static void _drawTerraBehemoth(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Behemoth: colossal quadruped, massive shoulders, tusks
    final r = radius;
    final bodyPath = Path();
    bodyPath.moveTo(center.dx, center.dy - r * 0.4);
    bodyPath.lineTo(center.dx + r * 0.9, center.dy - r * 0.2);
    bodyPath.lineTo(center.dx + r * 0.7, center.dy + r * 0.5);
    bodyPath.lineTo(center.dx - r * 0.7, center.dy + r * 0.5);
    bodyPath.lineTo(center.dx - r * 0.9, center.dy - r * 0.2);
    bodyPath.close();
    canvas.drawPath(bodyPath, silhouette);
    final tuskPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final tuskPath = Path();
    tuskPath.moveTo(center.dx - r * 0.6, center.dy + r * 0.2);
    tuskPath.lineTo(center.dx - r * 0.7, center.dy + r * 0.6);
    canvas.drawPath(tuskPath, tuskPaint);
    tuskPath.reset();
    tuskPath.moveTo(center.dx + r * 0.6, center.dy + r * 0.2);
    tuskPath.lineTo(center.dx + r * 0.7, center.dy + r * 0.6);
    canvas.drawPath(tuskPath, tuskPaint);
    canvas.drawCircle(
      center + Offset(-r * 0.3, center.dy - r * 0.15),
      r * 0.1,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.3, center.dy - r * 0.15),
      r * 0.1,
      eye,
    );
  }

  static void _drawVoidReaper(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Reaper: hooded figure, scythe, floating
    final r = radius;
    final path = Path();
    path.moveTo(center.dx, center.dy - r * 0.5);
    path.lineTo(center.dx - r * 0.6, center.dy - r * 0.1);
    path.lineTo(center.dx - r * 0.6, center.dy + r * 0.6);
    path.lineTo(center.dx + r * 0.6, center.dy + r * 0.6);
    path.lineTo(center.dx + r * 0.6, center.dy - r * 0.1);
    path.close();
    canvas.drawPath(path, silhouette);
    final scythePath = Path();
    scythePath.moveTo(center.dx - r * 0.6, center.dy + r * 0.3);
    scythePath.lineTo(center.dx - r * 1.1, center.dy - r * 0.2);
    scythePath.lineTo(center.dx - r * 0.9, center.dy + r * 0.1);
    scythePath.lineTo(center.dx - r * 0.6, center.dy + r * 0.3);
    canvas.drawPath(scythePath, highlight);
    canvas.drawCircle(
      center + Offset(-r * 0.15, center.dy - r * 0.35),
      r * 0.09,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.15, center.dy - r * 0.35),
      r * 0.09,
      eye,
    );
  }

  static void _drawVoidOracle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Oracle: robed, third eye, orbiting runes
    final r = radius;
    final path = Path();
    path.moveTo(center.dx, center.dy - r * 0.5);
    path.lineTo(center.dx - r * 0.5, center.dy + r * 0.1);
    path.lineTo(center.dx - r * 0.4, center.dy + r * 0.7);
    path.lineTo(center.dx + r * 0.4, center.dy + r * 0.7);
    path.lineTo(center.dx + r * 0.5, center.dy + r * 0.1);
    path.close();
    canvas.drawPath(path, silhouette);
    for (int i = 0; i < 6; i++) {
      final angle = time * 0.6 + i * math.pi / 3;
      final runeR = r * 0.75;
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * runeR,
          center.dy + math.sin(angle) * runeR,
        ),
        2.5,
        Paint()
          ..color = highlight.color.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawCircle(
      center + Offset(-r * 0.18, center.dy - r * 0.15),
      r * 0.09,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.18, center.dy - r * 0.15),
      r * 0.09,
      eye,
    );
    canvas.drawCircle(center + Offset(0, center.dy + r * 0.05), r * 0.11, eye);
  }

  static void _drawVoidArchon(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Paint highlight,
    Paint eye,
    int stars,
    double time,
  ) {
    // Archon: regal void entity, crown of spines, multiple arms
    final r = radius;
    final path = Path();
    path.moveTo(center.dx, center.dy - r * 0.55);
    path.quadraticBezierTo(
      center.dx + r * 0.5,
      center.dy - r * 0.8,
      center.dx + r * 0.65,
      center.dy - r * 0.2,
    );
    path.quadraticBezierTo(
      center.dx + r * 0.8,
      center.dy + r * 0.2,
      center.dx + r * 0.5,
      center.dy + r * 0.5,
    );
    path.quadraticBezierTo(
      center.dx,
      center.dy + r * 0.8,
      center.dx - r * 0.5,
      center.dy + r * 0.5,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.8,
      center.dy + r * 0.2,
      center.dx - r * 0.65,
      center.dy - r * 0.2,
    );
    path.quadraticBezierTo(
      center.dx - r * 0.5,
      center.dy - r * 0.8,
      center.dx,
      center.dy - r * 0.55,
    );
    canvas.drawPath(path, silhouette);
    for (int i = 0; i < 8; i++) {
      final angle = time * 0.2 + i * math.pi / 4;
      final spinePath = Path();
      spinePath.moveTo(
        center.dx + math.cos(angle) * r * 0.6,
        center.dy + math.sin(angle) * r * 0.6,
      );
      spinePath.lineTo(
        center.dx + math.cos(angle) * r * 1.0,
        center.dy + math.sin(angle) * r * 1.0,
      );
      canvas.drawPath(
        spinePath,
        Paint()
          ..color = highlight.color.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(
      center + Offset(-r * 0.2, center.dy - r * 0.25),
      r * 0.1,
      eye,
    );
    canvas.drawCircle(
      center + Offset(r * 0.2, center.dy - r * 0.25),
      r * 0.1,
      eye,
    );
  }

  static void _drawGeneric(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Element element,
  ) {
    // Element symbol
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
