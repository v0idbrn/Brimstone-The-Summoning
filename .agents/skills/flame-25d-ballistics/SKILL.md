---
name: flame-25d-ballistics
description: Reglas matemáticas para proyección 2.5D en Flame Engine
version: 1.0.0
---

# Flame 2.5D Ballistics Skill

## Proposito
Define la matematica determinista para proyectar coordenadas 3D (x, y, z) en un canvas 2D de Flame Engine, donde z avanza de 0.0 (bandeja del jugador) a 1.0 (plano de dianas del jefe).

## Proyección 2.5D (Core Math)

### Parametros base
- zStart = 0.0 (bandeja inferior jugador)
- zEnd = 1.0 (plano de dianas jefe)
- flightDuration = 0.45 segundos
- arcHeight = 120.0 pixels
- scaleStart = 1.0
- scaleEnd = 0.38

### Interpolaciones por frame
- z = (elapsedTime / flightDuration).clamp(0.0, 1.0)
- scale = lerpDouble(scaleStart, scaleEnd, z)
- screenX = lerpDouble(startX, targetX, z)
- screenY = lerpDouble(startY, targetY, z) - sin(z * pi) * arcHeight

### Detección de Impacto (z >= 1.0)
- distance < innerRadius (24.0) = BULLSEYE CRITICO (daño x1.5 + haptic heavy)
- distance < outerRadius (48.0) = IMPACTO NORMAL (daño x1.0)
- else = FALLO

## Merge Tray (Bandeja de Fusión)
- 5 slots fijos, spawn cada 1.2s
- Niveles: 1 (1.0x daño, +15 mana), 2 (2.2x, +35, aura 5s), 3 (4.8x, +75, aura potenciada, atraviesa)
- Fusion: mismo elemento + mismo nivel => nivel+1

## Counter-Flick Defensivo
- Proyectiles enemigos: z=1.0 -> z=0.0
- Defensa: tap directo O colision aire-aire con orbe propio
- Recompensa: +10 mana elemento destruido

## Componentes Flame Requeridos
- BrimstoneCombatGame extends FlameGame
- MergeTrayComponent
- OrbProjectileComponent
- BossTargetReticle
- EnemyProjectileComponent

## Prohibiciones
- NO sprites/binarios v1 (todo procedural)
- NO SQLite/navegación desde este skill
- NO importar material.dart en lógica combate
- NO Random no inyectado
