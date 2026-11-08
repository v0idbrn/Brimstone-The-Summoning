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
    'abyss_stalker': Element.abyssal,
    'abyss_leviathan': Element.abyssal,
    'terra_golem': Element.telluric,
    'terra_titan': Element.telluric,
    'void_specter': Element.empty,
    'void_malakor': Element.empty,
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
        final p =
            center +
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

  static void _drawGeneric(
    Canvas canvas,
    Offset center,
    double radius,
    Paint silhouette,
    Element element,
  ) {
    canvas.drawCircle(center, radius * 0.7, silhouette);
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
