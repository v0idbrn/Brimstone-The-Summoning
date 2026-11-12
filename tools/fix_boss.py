#!/usr/bin/env python3
# -*- coding: utf-8 -*-

with open('lib/presentation/combat_engine/boss_actor_component.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find and replace _drawOrganicPortrait method
old_method = '''  // ── Plane 2: organic portrait ────────────────────────────────────────
  void _drawOrganicPortrait(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    Color color,
    double time,
  ) {
    const size = 260.0;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: size * scale,
      height: size * scale,
    );

    // Layer isolates the art so `dstIn` only dissolves this silhouette.
    canvas.saveLayer(rect.inflate(2), Paint());

    if (_portraitImage != null) {
      final image = _portraitImage!;
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final scaleFactor = math.max(
        rect.width / src.width,
        rect.height / src.height,
      );
      final drawW = src.width * scaleFactor;
      final drawH = src.height * scaleFactor;
      final dst = Rect.fromCenter(
        center: rect.center,
        width: drawW,
        height: drawH,
      );
      canvas.drawImageRect(image, src, dst, _imagePaint);
    } else {
      _fillPaint.shader = RadialGradient(
        colors: [color.withValues(alpha: 0.9), const Color(0xFF0A0407)],
      ).createShader(rect);
      canvas.drawOval(rect, _fillPaint);
      _fillPaint.shader = null;
    }

    // Organic dissolve: elliptical gradient fades every edge to alpha 0.
    _maskPaint.shader = RadialGradient(
      colors: [
        Colors.white,
        Colors.white,
        Colors.white.withValues(alpha: 0.72),
        Colors.transparent,
      ],
      stops: const [0.0, 0.58, 0.82, 1.0],
    ).createShader(rect);
    canvas.drawOval(rect, _maskPaint);
    _maskPaint.shader = null;
    canvas.restore();

    // Elemental rim light hugging the dissolved silhouette.
    _strokePaint
      ..strokeWidth = 2.2
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.7),
          color.withValues(alpha: 0.55),
          color.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(time * 0.8),
      ).createShader(rect);
    canvas.drawOval(rect.deflate(6), _strokePaint);
    _strokePaint.shader = null;
  }'''

new_method = '''  // ── Plane 2: organic portrait ────────────────────────────────────────
  void _drawOrganicPortrait(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    Color color,
    double time,
  ) {
    const medallionRadius = 92.0;
    final center = Offset(cx, cy);
    final rect = Rect.fromCircle(center: center, radius: medallionRadius * scale);

    // Layer isolates the art so `dstIn` only dissolves this silhouette.
    canvas.saveLayer(rect.inflate(2), Paint());

    // Clip to circular medallion
    canvas.clipPath(Path()..addOval(rect));

    if (_portraitImage != null) {
      final image = _portraitImage!;
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final scaleFactor = math.max(
        rect.width / src.width,
        rect.height / src.height,
      );
      final drawW = src.width * scaleFactor;
      final drawH = src.height * scaleFactor;
      final dst = Rect.fromCenter(
        center: rect.center,
        width: drawW,
        height: drawH,
      );
      canvas.drawImageRect(image, src, dst, _imagePaint);
    } else {
      _fillPaint.shader = RadialGradient(
        colors: [color.withValues(alpha: 0.9), const Color(0xFF0A0407)],
      ).createShader(rect);
      canvas.drawOval(rect, _fillPaint);
      _fillPaint.shader = null;
    }

    canvas.restore();

    // Gothic metallic double ring border (gold + dark bronze with spikes/runes)
    _drawMedallionBorder(canvas, center, medallionRadius, scale, color, time);

    // Elemental rim light inside the medallion
    _strokePaint
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.7),
          color.withValues(alpha: 0.55),
          color.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(time * 0.8),
      ).createShader(rect);
    canvas.drawCircle(center, medallionRadius * scale * 0.95, _strokePaint);
    _strokePaint.shader = null;
  }

  // Gothic metallic double ring border for the Abyssal Portal Medallion
  void _drawMedallionBorder(
    Canvas canvas,
    Offset center,
    double radius,
    double scale,
    Color color,
    double time,
  ) {
    final r = radius * scale;
    final gold = const Color(0xFFF2D078);
    final darkBronze = const Color(0xFF3A2A1A);
    final bronzeHighlight = const Color(0xFF5A4A2A);

    // Outer ring: dark bronze base
    _strokePaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 * scale
      ..color = darkBronze;
    canvas.drawCircle(center, r, _strokePaint);

    // Inner edge of outer ring: gold highlight
    _strokePaint
      ..strokeWidth = 1.5 * scale
      ..shader = SweepGradient(
        colors: [
          gold.withValues(alpha: 0.9),
          darkBronze,
          gold.withValues(alpha: 0.9),
          darkBronze,
          gold.withValues(alpha: 0.9),
        ],
        transform: GradientRotation(time * 0.3),
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, _strokePaint);
    _strokePaint.shader = null;

    // Middle ring: bronze with engraved runes/spikes
    final midR = r - 6.0 * scale;
    _strokePaint
      ..strokeWidth = 2.0 * scale
      ..color = bronzeHighlight;
    canvas.drawCircle(center, midR, _strokePaint);

    // Engraved spikes/runes on middle ring
    const spikeCount = 16;
    for (var i = 0; i < spikeCount; i++) {
      final angle = time * 0.15 + i * (math.pi * 2 / spikeCount);
      final spikeLen = 4.0 * scale * (0.7 + 0.3 * math.sin(time * 2 + i));
      final innerR = midR - spikeLen;
      _strokePaint
        ..strokeWidth = 1.2 * scale
        ..color = gold.withValues(alpha: 0.7 + 0.3 * math.sin(time * 3 + i));
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * innerR,
          center.dy + math.sin(angle) * innerR,
        ),
        Offset(
          center.dx + math.cos(angle) * midR,
          center.dy + math.sin(angle) * midR,
        ),
        _strokePaint,
      );
    }

    // Inner ring: gold filigree
    final innerR = r - 12.0 * scale;
    _strokePaint
      ..strokeWidth = 1.0 * scale
      ..shader = SweepGradient(
        colors: [
          gold.withValues(alpha: 0.8),
          darkBronze,
          gold.withValues(alpha: 0.8),
          darkBronze,
        ],
        transform: GradientRotation(-time * 0.2),
      ).createShader(Rect.fromCircle(center: center, radius: innerR));
    canvas.drawCircle(center, innerR, _strokePaint);
    _strokePaint.shader = null;

    // Four cardinal rune marks (gold)
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final markR = innerR - 4.0 * scale;
      canvas.save();
      canvas.translate(
        center.dx + math.cos(angle) * markR,
        center.dy + math.sin(angle) * markR,
      );
      canvas.rotate(angle);
      _fillPaint.color = gold.withValues(alpha: 0.9);
      final runePath = Path()
        ..moveTo(0, -3.0 * scale)
        ..lineTo(-2.0 * scale, 3.0 * scale)
        ..lineTo(2.0 * scale, 3.0 * scale)
        ..close();
      canvas.drawPath(runePath, _fillPaint);
      canvas.restore();
    }
  }'''

if old_method in content:
    content = content.replace(old_method, new_method)
    with open('lib/presentation/combat_engine/boss_actor_component.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Replaced _drawOrganicPortrait successfully')
else:
    print('Old method NOT found')
    # Debug
    idx = content.find('_drawOrganicPortrait')
    if idx >= 0:
        print('Found at:', idx)
        print(repr(content[idx:idx+200]))