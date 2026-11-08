import 'package:flutter/material.dart';

import '../../../domain/roguelite/abyssal_events.dart';

/// Modal de un Encuentro del Abismo dentro de la Grieta.
///
/// Muestra la narración y las tres decisiones con el resumen exacto de sus
/// efectos. El llamador decide qué hacer con la opción elegida y cierra el
/// modal.
class AbyssalEventModal extends StatelessWidget {
  final AbyssalEvent event;
  final ValueChanged<AbyssalEventOption> onOptionChosen;

  const AbyssalEventModal({
    super.key,
    required this.event,
    required this.onOptionChosen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF14090D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.auto_stories,
                color: Color(0xFFB16EFF),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ENCUENTRO ABISAL',
                  style: TextStyle(
                    color: const Color(0xFFB16EFF).withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            event.title,
            style: const TextStyle(
              color: Color(0xFFFFC93C),
              fontWeight: FontWeight.w900,
              fontSize: 17,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ELIGE TU CAMINO',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 9,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          for (final option in event.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionTile(
                option: option,
                onTap: () => onOptionChosen(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final AbyssalEventOption option;
  final VoidCallback onTap;

  const _OptionTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final risky = option.hpDelta < 0;
    final accent = risky ? const Color(0xFFFF5A26) : const Color(0xFF4FFFA3);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0E14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
          ),
          child: Row(
            children: [
              Icon(
                risky ? Icons.warning_amber : Icons.auto_awesome,
                color: accent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.effectSummary,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
