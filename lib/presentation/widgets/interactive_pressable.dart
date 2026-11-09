import 'package:flutter/material.dart' hide Element;
import '../../core/theme/design_tokens.dart';
import '../../../domain/value_objects/element.dart';

/// A widget that wraps any child with consistent interaction states:
/// - Hover (web): brightens border, adds subtle glow
/// - Pressed: scales to 0.96 with quick spring
/// - Disabled: 45% opacity, stone-gray border, shows lock/cost indicator
class InteractivePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final String? disabledReason;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? hoverBorderColor;
  final Color? hoverGlowColor;
  final double pressScale;
  final Duration pressDuration;
  final bool showLockWhenDisabled;

  const InteractivePressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.disabledReason,
    this.padding,
    this.borderRadius,
    this.hoverBorderColor,
    this.hoverGlowColor,
    this.pressScale = 0.96,
    this.pressDuration = BrimstoneMotion.fast,
    this.showLockWhenDisabled = true,
  });

  @override
  State<InteractivePressable> createState() => _InteractivePressableState();
}

class _InteractivePressableState extends State<InteractivePressable> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(BrimstoneRadii.radiusMD);
    final hoverBorder = widget.hoverBorderColor ?? BrimstoneAccents.goldBright;
    final hoverGlow = widget.hoverGlowColor ?? BrimstoneAccents.goldPrimary;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: enabled ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _isPressed ? widget.pressScale : 1.0,
          duration: widget.pressDuration,
          curve: BrimstoneMotion.press,
          child: AnimatedContainer(
            duration: BrimstoneMotion.normal,
            curve: BrimstoneMotion.standard,
            padding: widget.padding,
            decoration: enabled
                ? BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color:
                          _isHovered ? hoverBorder : BrimstoneAccents.goldMuted,
                      width: _isHovered ? 2 : 1.5,
                    ),
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: hoverGlow.withValues(alpha: 0.25),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  )
                : BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: const Color(0xFF332D42),
                      width: 1,
                    ),
                  ),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Opacity(
                  opacity: enabled ? 1.0 : 0.45,
                  child: widget.child,
                ),
                if (!enabled && widget.showLockWhenDisabled)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              color: BrimstoneAccents.danger,
                              size: 20,
                            ),
                            if (widget.disabledReason != null) ...[
                              const SizedBox(height: BrimstoneSpacing.spaceXS),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: BrimstoneSpacing.spaceSM),
                                child: Text(
                                  widget.disabledReason!,
                                  textAlign: TextAlign.center,
                                  style: BrimstoneTypography.labelSM.copyWith(
                                    color: BrimstoneAccents.danger,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
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

/// Specialized version for card-like widgets (TcgCardWidget, chapter tiles, etc.)
class InteractiveCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final bool selected;
  final Element? element;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const InteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.selected = false,
    this.element,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onTap != null;
    final glowColor = element != null
        ? BrimstoneElements.forElementGlow(element!)
        : BrimstoneAccents.goldPrimary;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: BrimstoneMotion.normal,
          curve: BrimstoneMotion.standard,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius:
                borderRadius ?? BorderRadius.circular(BrimstoneRadii.radiusLG),
            gradient: selected
                ? BrimstoneGradients.cardSelected
                : BrimstoneGradients.cardBase,
            border: Border.all(
              color: selected
                  ? BrimstoneAccents.goldBright
                  : isEnabled
                      ? (element != null
                          ? BrimstoneElements.forElement(element!)
                              .withValues(alpha: 0.6)
                          : BrimstoneAccents.goldMuted)
                      : const Color(0xFF332D42),
              width: selected ? 2.5 : (isEnabled ? 1.5 : 1),
            ),
            boxShadow: (selected || (isEnabled && element != null))
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: selected ? 0.4 : 0.25),
                      blurRadius: selected ? 16 : 10,
                      spreadRadius: selected ? 2 : 1,
                    ),
                  ]
                : null,
          ),
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.5,
            child: child,
          ),
        ),
      ),
    );
  }
}
