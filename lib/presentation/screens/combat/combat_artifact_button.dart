import 'package:flutter/material.dart';

import '../../../domain/meta/summoner_artifact.dart';

/// 5to botón táctico: artefacto del Invocador junto a la barra de HP.
///
/// Estado listo -> icono dorado activable; en cooldown -> segundos restantes.
/// Si no hay artefacto equipado no se dibuja nada.
class CombatArtifactButton extends StatelessWidget {
  final SummonerArtifact? artifact;
  final double cooldownRemaining;
  final VoidCallback onTap;
  const CombatArtifactButton({
    super.key,
    required this.artifact,
    required this.cooldownRemaining,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final artifact = this.artifact;
    if (artifact == null) return const SizedBox.shrink();
    final ready = cooldownRemaining <= 0;
    return Tooltip(
      message: ready
          ? '${artifact.name}: ${artifact.description}'
          : '${artifact.name} — listo en ${cooldownRemaining.ceil()}s',
      child: GestureDetector(
        onTap: ready ? onTap : null,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A0E14),
            border: Border.all(
              color:
                  const Color(0xFFFFC93C).withValues(alpha: ready ? 1.0 : 0.35),
              width: 1.5,
            ),
          ),
          child: ready
              ? const Icon(Icons.auto_fix_high,
                  size: 20, color: Color(0xFFFFC93C))
              : Center(
                  child: Text(
                    '${cooldownRemaining.ceil()}s',
                    style: const TextStyle(
                      color: Color(0xFFFFC93C),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
