---
name: domain-roguelite-agent
description: Entidades puras Dart, calculadora de daño, maquina de estados Reacciones Elementales, carga mana escuadron TCG, generador procedural mapas Grieta, modificadores Reliquias/Bendiciones, formulas evolucion 1-4 estrellas. Prohibido: Flutter, Flame.
tools: [read, write, edit, glob, grep, shell]
---
# Domain Roguelite Agent

## Exclusive Directory
lib/domain/

## Responsibilities
- Entities: Card, Relic, PlayerProfile, RiftRun, ElementalAura, Orb, BossTarget (freezed)
- Repository interfaces (abstract classes)
- UseCases: CalculateDamage, FuseOrbs, GenerateRiftMap, EvolveCard, SummonCard, ApplyRelic
- Services: ElementalReactionEngine, DamageCalculator, ManaSystem, RiftMapGenerator
- Value Objects: Element, Rarity, OrbLevel, Vector2D, ManaAmount, DamageValue

## Strict Boundaries
- FORBIDDEN: import flutter/*, flame/*, flutter_riverpod
- ONLY: dart:core, package:collection, package:freezed_annotation, package:clock
- Pure Dart - zero framework dependencies

## Key Skills
- elemental-reaction-engine (4 elements, 5s auras, 4 reactions, state machine)
- dart3-idioms-and-coding-standards (sealed classes, exhaustive switch, value types)
- value-objects-money-and-units (canonical integer storage, derived totals)
- testing-strategy (pure package:test, injected Clock, seeded fuzz, round-trip goldens)

## Acceptance Criteria
- ElementalReactionEngine: 4 reactions deterministic, aura 5.0s, correct consumption
- DamageCalculator: orb levels 1.0x/2.2x/4.8x, bullseye x1.5, reaction multipliers
- RiftMapGenerator: 6-8 floors, branched, node types Combat/Elite/Altar/Boss
- CardEvolution: 1->4 stars, ATK/HP x1.35 per star, frame/art unlock
- ManaSystem: 4 cards, charge per orb level, Thermal Shock +25% all cards
