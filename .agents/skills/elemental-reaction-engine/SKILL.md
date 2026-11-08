---
name: elemental-reaction-engine
description: Maquina de estados determinista para 4 elementos, auras 5s y tabla de 4 reacciones elementales
version: 1.0.0
---

# Elemental Reaction Engine Skill

## Propósito
Especificación completa del motor de reacciones elementales: 4 elementos, duracion de auras (5.0s), tabla de detonaciones de combos y machine de estados determinista.

---

## 4 Elementos (Enum)
`dart
enum Element {
  igneous,    // Ígneo (Fuego) - Rojo/Naranja
  abyssal,    // Abisal (Agua/Hielo) - Azul/Cian
  telluric,   // Telúrico (Tierra) - Marron/Dorado
  void,       // Vacío (Oscuridad) - Purpura/Negro
}
`

---

## Auras Elementales
- **Duracion**: 5.0 segundos exactos
- **Aplicacion**: Al impactar orbe Nv.2+ o habilidad activa de carta
- **Visual**: Brillo perimetral en la diana (BossTargetReticle) color del elemento
- **Stacking**: NO se acumulan - nueva aura del mismo elemento reinicia timer a 5.0s
- **Expiracion**: Si timer llega a 0 sin detonar -> aura se consume sin efecto

---

## Tabla de Reacciones Elementales (4 Combos)

| Aura Base (Activa) | Detonador (Entrante) | Nombre Reacción | Efecto Mecánico |
|--------------------|----------------------|-----------------|-----------------|
| Ígneo | Telúrico | **Erupción Magmática** | 160% daño en área a TODAS las dianas activas del jefe |
| Abisal | Ígneo | **Choque Térmico** | Daño crítico x2.0 + otorga +25% carga maná instantánea a las 4 cartas del escuadrón |
| Telúrico | Abisal | **Petrificación Abisal** | -50% velocidad movimiento dianas + retrasa 3.5s próximo ataque jefe |
| Vacío | CUALQUIER (solo Nv.3) | **Colapso del Sello** | Drena vida jefe = 15% vida max jugador + vulnerabilidad +30% daño recibido 4.0s |

---

## Reglas de Detonación

1. **Orden importa**: Aura debe estar ACTIVA (timer > 0) cuando llega el detonador
2. **Consumo**: Al detonar, aura base se consume (timer = 0), detonador aplica su efecto normal + bonus reacción
3. **Nivel mínimo detonador**: Nv.2 para Ígneo/Abisal/Telúrico; **Nv.3 obligatorio** para Vacío
4. **Una detonación por aura**: No se puede detonar la misma aura dos veces
5. **Feedback visual**: Cada reacción tiene partículas/colores únicos + screen shake + SFX

---

## Maquina de Estados (Por Diana/Target)

`
Estado: IDLE
  -> OnElementalHit(element, orbLevel) 
     -> if orbLevel >= 2: aplicar Aura(element, 5.0s) -> Estado: AURA_ACTIVE(element, timer=5.0)
     -> if orbLevel == 1 && isBullseye: aplicar Aura(element, 5.0s) -> Estado: AURA_ACTIVE

Estado: AURA_ACTIVE(element, timer)
  -> OnTick(dt): timer -= dt; if timer <= 0 -> Estado: IDLE
  -> OnElementalHit(detonatorElement, orbLevel):
     -> if (element, detonatorElement) en TABLA_REACCIONES:
          -> ejecutarReaccion(element, detonatorElement)
          -> Estado: IDLE (aura consumida)
     -> else if detonatorElement == element:
          -> reiniciar timer a 5.0s (refresh aura)
     -> else:
          -> aplicar aura detonatorElement (reemplaza anterior) -> Estado: AURA_ACTIVE(detonatorElement, 5.0)

Estado: REACTION_EXECUTING(reactionType)
  -> aplicar efectos instantaneos (daño, mana, debuffs)
  -> spawn partículas reacción
  -> Estado: IDLE
`

---

## Integración con Sistema de Maná (TCG 4 Cartas)

- Cada carta tiene: elemento, costoManá, manaActual (0 a costoManá)
- **Carga por impacto**: Orbe Nv.1 = +15, Nv.2 = +35, Nv.3 = +75 (al elemento de la carta)
- **Choque Térmico bonus**: +25% costoManá a TODAS las 4 cartas (instantáneo)
- **Disparo habilidad**: Tap en carta con manaActual >= costoManá -> ejecuta habilidad activa

---

## Constantes Centralizadas
`dart
// lib/core/constants/elemental_constants.dart
class ElementalConstants {
  static const double auraDuration = 5.0;
  static const double reactionVulnerabilityDuration = 4.0;
  static const double petrificationSlow = 0.5;      // -50% velocidad
  static const double petrificationDelay = 3.5;     // segundos delay ataque
  static const double magmaEruptionMultiplier = 1.6; // 160%
  static const double thermalShockCritMultiplier = 2.0;
  static const double thermalShockManaBonus = 0.25;  // +25%
  static const double sealCollapseLifeDrain = 0.15;  // 15% vida max jugador
  static const double sealCollapseVulnerability = 0.30; // +30% daño recibido
  static const int minOrbLevelForAura = 2;
  static const int minOrbLevelForVoid = 3;
}
`

---

## Prohibiciones Estrictas
- ❌ NO importar Flutter/Flame en lib/domain/ - logica pura Dart
- ❌ NO usar DateTime.now() - inyectar Clock para tests deterministas
- ❌ NO random en resolución de reacciones - todo determinista
- ❌ NO mutar estado desde UI - solo via UseCases/Repository

---

## Tests Requeridos (dart-add-unit-test)
- elemental_reaction_engine_test.dart: 4 reacciones, duraciones, consumo aura
- ura_state_machine_test.dart: IDLE -> AURA_ACTIVE -> REACTION -> IDLE
- mana_charge_test.dart: carga por nivel orbe, bonus Choque Térmico
- oid_reaction_test.dart: solo Nv.3 detona Vacío, drena vida, vulnerabilidad
- eaction_priority_test.dart: aura fresca vs expirada, reemplazo vs refresh
