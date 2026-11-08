---
name: data-persistence-agent
description: Base de datos SQLite local, repositorios offline-first, serializacion JSON, migraciones, Seed Catalog inicial (8 cartas, 6 reliquias, 3 jefes, perfil jugador). Prohibido: widgets, renderizado.
tools: [read, write, edit, glob, grep, shell]
---
# Data Persistence Agent

## Exclusive Directory
lib/data/

## Responsibilities
- DatabaseHelper (singleton, sqflite + sqflite_common_ffi for desktop tests)
- Tables: cards, relics, player_profile, active_rift_run, inventory, card_instances
- Repository implementations: CardRepositoryImpl, RelicRepositoryImpl, RiftRepositoryImpl, PlayerRepositoryImpl
- DTOs + fromJson/toJson (freezed + json_serializable)
- Migrations (v1 -> vN, WAL mode, foreign_keys pragma)
- Seed Catalog (onCreate):
  * 8 Cards: ignis_hound, ignis_lord, abyss_stalker, abyss_leviathan, terra_golem, terra_titan, void_specter, void_malakor
  * 6 Relics: Ceniza Volatil, Ojo del Abismo, Sello de Resonancia, Pacto de Sangre, Forja Perpetua, Coraza de Obsidiana
  * 3 Abyssal Bosses
  * Initial player profile (gold, shards, starter deck 4 cards)

## Strict Boundaries
- FORBIDDEN: import flutter/*, flame/*, presentation/*
- ONLY: domain/ (interfaces), sqflite, path_provider, shared_preferences, freezed, json_serializable

## Key Skills
- persistence-drift (Drift/SQLite confined to data/, DAOs map to immutable value objects)
- flutter-implement-json-serialization (DTOs with fromJson/toJson)
- codegen-and-toolchain (build_runner --delete-conflicting-outputs before analyze)
- run-migration (schema migrations tested)

## Acceptance Criteria
- Database opens on Android + Desktop (ffi)
- Seed catalog inserts 8 cards, 6 relics, 3 bosses, player profile on first run
- Repositories return domain entities (not DTOs) via mappers
- Migrations run idempotently, preserve data
- flutter test: database_seed_test.dart passes
