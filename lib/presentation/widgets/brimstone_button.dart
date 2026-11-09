import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

/// Dark Fantasy Gothic Button with beveled metallic borders,
/// rich crimson/obsidian gradient fill, icon support, and full
/// interaction states (hover, pressed, disabled).
class BrimstoneButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final bool isDestructive;
  final double height;
  final double? width;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool expandWidth;

  const BrimstoneButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isSecondary = false,
    this.isDestructive = false,
    this.height = 46,
    this.width,
    this.fontSize = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.expandWidth = false,
  });

  @override
  State<BrimstoneButton> createState() => _BrimstoneButtonState();
}

class _BrimstoneButtonState extends State<BrimstoneButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    final baseGradient = widget.isDestructive
        ? BrimstoneGradients.crimson
        : widget.isSecondary
            ? BrimstoneGradients.cardBase
            : BrimstoneGradients.gold;

    final borderColor = widget.isSecondary
        ? BrimstoneAccents.goldMuted
        : BrimstoneAccents.goldPrimary;
    final borderColorHover = BrimstoneAccents.goldBright;
    final borderColorDisabled = const Color(0xFF332D42);

    final textColor = widget.isSecondary
        ? BrimstoneAccents.goldPrimary
        : BrimstoneAccents.textOnGold;

    final iconColor = widget.isSecondary
        ? BrimstoneAccents.goldPrimary
        : BrimstoneAccents.goldBright;

    final shadowColor = widget.isDestructive
        ? BrimstoneAccents.crimsonGlow
        : BrimstoneAccents.goldPrimary;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: enabled ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: BrimstoneMotion.fast,
          curve: BrimstoneMotion.press,
          child: AnimatedContainer(
            duration: BrimstoneMotion.fast,
            curve: BrimstoneMotion.standard,
            width: widget.expandWidth ? double.infinity : widget.width,
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BrimstoneRadii.radiusMD),
              gradient: baseGradient,
              boxShadow: enabled && !widget.isSecondary
                  ? [
                      BoxShadow(
                        color: shadowColor.withValues(
                          alpha: _isHovered ? 0.35 : 0.25,
                        ),
                        blurRadius: _isHovered ? 12 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
              border: Border.all(
                color: enabled
                    ? (_isHovered ? borderColorHover : borderColor)
                    : borderColorDisabled,
                width: enabled ? 1.6 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: widget.fontSize + 4,
                    color: enabled ? iconColor : BrimstoneAccents.textMuted,
                  ),
                  const SizedBox(width: BrimstoneSpacing.spaceSM),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BrimstoneTypography.buttonPrimary.copyWith(
                      color: enabled ? textColor : BrimstoneAccents.textMuted,
                      fontSize: widget.fontSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
