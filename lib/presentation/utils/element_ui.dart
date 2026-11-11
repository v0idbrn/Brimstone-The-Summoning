import 'package:flutter/material.dart' hide Element;
import '../../domain/value_objects/element.dart';

/// Extension methods on Element for UI (color, icon).
/// Kept in presentation layer to avoid Flutter imports in domain.
extension ElementUI on Element {
  /// Semantic color for this element (harmonized for dark backgrounds).
  Color get color => switch (this) {
        Element.igneous => const Color(0xFFE05A2B),
        Element.abyssal => const Color(0xFF2E95D3),
        Element.telluric => const Color(0xFF8C6D46),
        Element.empty => const Color(0xFF8B4FD9),
      };

  /// Glow variant for emissive effects.
  Color get glowColor => switch (this) {
        Element.igneous => const Color(0xFFFF8A5A),
        Element.abyssal => const Color(0xFF6EC6FF),
        Element.telluric => const Color(0xFFD4A87A),
        Element.empty => const Color(0xFFC89AFF),
      };

  /// Material icon representing this element.
  IconData get icon => switch (this) {
        Element.igneous => Icons.local_fire_department,
        Element.abyssal => Icons.water_drop,
        Element.telluric => Icons.shield,
        Element.empty => Icons.auto_awesome,
      };
}
