import 'package:flutter/material.dart';

/// Dark Fantasy Gothic Button with beveled metallic borders,
/// rich crimson/obsidian gradient fill, and icon support.
class BrimstoneButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final double height;
  final double? width;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const BrimstoneButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isSecondary = false,
    this.height = 46,
    this.width,
    this.fontSize = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  State<BrimstoneButton> createState() => _BrimstoneButtonState();
}

class _BrimstoneButtonState extends State<BrimstoneButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    final baseGradient = widget.isSecondary
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF261420), Color(0xFF140810), Color(0xFF0C040A)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8B1E2F), Color(0xFF5C0F1C), Color(0xFF2E050C)],
          );

    final borderColor =
        widget.isSecondary ? const Color(0xFF8A6538) : const Color(0xFFD4AF37);

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: baseGradient,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: widget.isSecondary
                          ? const Color(0x33000000)
                          : const Color(0x66FF2A54),
                      blurRadius: widget.isSecondary ? 4 : 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
            border: Border.all(
              color: enabled ? borderColor : Colors.white12,
              width: 1.6,
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
                  color: enabled
                      ? (widget.isSecondary
                          ? const Color(0xFFD4AF37)
                          : const Color(0xFFFFD700))
                      : Colors.white24,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: enabled
                      ? (widget.isSecondary
                          ? const Color(0xFFE5D4FF)
                          : Colors.white)
                      : Colors.white24,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  shadows: enabled
                      ? const [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
