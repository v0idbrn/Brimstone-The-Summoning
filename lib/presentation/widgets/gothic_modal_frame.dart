import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Ornamented modal shell shared by every secondary dialog of the game.
///
/// Cinzel heading with a gilded rule, beveled corner brackets, dark volcanic
/// gradient and a consistent action row — so no screen falls back to the plain
/// grey Material form look.
class GothicModalFrame extends StatelessWidget {
  const GothicModalFrame({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.accent = BrimstoneTokens.goldPrimary,
    this.children = const <Widget>[],
    this.actions = const <Widget>[],
    this.maxWidth = 420,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color accent;
  final List<Widget> children;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B0D14), Color(0xFF0A0508)],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.9), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 26,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CornerBracketsPainter(accent: accent),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: accent),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: BrimstoneFonts.cinzel(
                            size: 14,
                            weight: FontWeight.w900,
                            color: accent,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: BrimstoneFonts.sans(
                        size: 10.5,
                        color: BrimstoneTokens.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _GildedRule(accent: accent),
                  const SizedBox(height: 12),
                  ...children,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          actions[i],
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GildedRule extends StatelessWidget {
  const _GildedRule({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          color: accent.withValues(alpha: 0.9),
        ),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.0),
                  accent.withValues(alpha: 0.8),
                  accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Transform.rotate(
          angle: 0.785,
          child: Container(
            width: 4,
            height: 4,
            color: accent.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent.withValues(alpha: 0.55);
    const arm = 12.0;
    const inset = 4.0;
    final w = size.width;
    final h = size.height;
    // Top-left / top-right / bottom-left / bottom-right brackets.
    canvas.drawLine(
      const Offset(inset, inset + arm),
      const Offset(inset, inset),
      paint,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + arm, inset),
      paint,
    );
    canvas.drawLine(
      Offset(w - inset, inset + arm),
      Offset(w - inset, inset),
      paint,
    );
    canvas.drawLine(
      Offset(w - inset, inset),
      Offset(w - inset - arm, inset),
      paint,
    );
    canvas.drawLine(
      Offset(inset, h - inset - arm),
      Offset(inset, h - inset),
      paint,
    );
    canvas.drawLine(
      Offset(inset, h - inset),
      Offset(inset + arm, h - inset),
      paint,
    );
    canvas.drawLine(
      Offset(w - inset, h - inset - arm),
      Offset(w - inset, h - inset),
      paint,
    );
    canvas.drawLine(
      Offset(w - inset, h - inset),
      Offset(w - inset - arm, h - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter old) =>
      old.accent != accent;
}

/// Metallic progress bar with an inner specular highlight and gilded rim.
class MetallicProgressBar extends StatelessWidget {
  const MetallicProgressBar({
    super.key,
    required this.value,
    this.color = BrimstoneTokens.goldPrimary,
    this.height = 8,
    this.label,
  });

  final double value;
  final Color color;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final fraction = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: BrimstoneFonts.sans(
              size: 9,
              weight: FontWeight.w700,
              color: BrimstoneTokens.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 3),
        ],
        Container(
          height: height,
          decoration: BoxDecoration(
            color: BrimstoneTokens.surfaceInteractive,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: BrimstoneTokens.goldMuted.withValues(alpha: 0.6),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(color, Colors.black, 0.35)!,
                          color,
                          Color.lerp(color, Colors.white, 0.35)!,
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: height * 0.34,
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Engraved section heading used inside modals and secondary panels.
class GothicSectionTitle extends StatelessWidget {
  const GothicSectionTitle({
    super.key,
    required this.text,
    this.accent = BrimstoneTokens.goldPrimary,
    this.trailing,
  });

  final String text;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 12, color: accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BrimstoneFonts.cinzel(
              size: 10,
              weight: FontWeight.w800,
              color: accent,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
