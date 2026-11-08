import 'package:flutter/material.dart' hide Element;

/// Guía interactiva rápida ("Cómo Jugar") con 4 tarjetas explicativas.
class HowToPlayModal extends StatelessWidget {
  const HowToPlayModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFF14090D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.help_outline,
                color: Color(0xFFB16EFF),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CÓMO JUGAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._cards.map((c) => _tutorialCard(context, c)),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido, ¡a luchar!'),
          ),
        ],
      ),
    );
  }

  final List<Map<String, String>> _cards = const [
    {
      'title': '1. Fusionar Esferas',
      'text':
          'Arrastra dos esferas del mismo elemento y nivel en la bandeja para '
          'fusionarlas en una de nivel superior (Nv.1 → Nv.2 → Nv.3).',
    },
    {
      'title': '2. Flick al Bullseye',
      'text':
          'Desliza una esfera hacia arriba (flick) para lanzarla contra una diana. '
          'Impactar el centro (Bullseye) otorga daño crítico y maná extra.',
    },
    {
      'title': '3. Reacciones Elementales',
      'text':
          'Aplica un aura de un elemento y luego impacta con otro para detonar '
          'una reacción: ¡Erupción Magmática, Choque Térmico, Petrificación '
          'Abisal o Colapso del Sello!',
    },
    {
      'title': '4. Counter-Flick y Habilidades',
      'text':
          'Toca un proyectil enemigo para destruirlo con Counter-Flick. '
          'Cuando una carta tiene maná completo, tócala para disparar su '
          'habilidad activa contra el jefe.',
    },
  ];

  Widget _tutorialCard(BuildContext context, Map<String, String> c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0E14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB16EFF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c['title']!,
            style: const TextStyle(
              color: Color(0xFFB16EFF),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            c['text']!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
