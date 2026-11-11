import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/meta/rune_system.dart';
import '../../../domain/meta/squad_synergy_resolver.dart';
import '../../../domain/value_objects/element.dart';
import '../../controllers/meta_controller.dart';
import '../combat/combat_screen.dart';

/// Modo Endgame "Abismo Sin Fin": oleadas infinitas de jefes escalados.
/// Cada oleada incrementa HP del jefe (1.25x) y daño de proyectiles (1.15x).
/// Tras cada victoria, el jugador elige 1 de 3 bendiciones antes de continuar.
class EndlessAbyssScreen extends ConsumerStatefulWidget {
  const EndlessAbyssScreen({super.key});

  @override
  ConsumerState<EndlessAbyssScreen> createState() => _EndlessAbyssScreenState();
}

class _EndlessAbyssScreenState extends ConsumerState<EndlessAbyssScreen> {
  int _wave = 1;
  int _highestEndlessWave = 0;
  bool _victory = false;
  bool _defeat = false;
  String? _blessing;
  int? _selectedBlessing;
  bool _runActive = false;

  // Bonos acumulados por bendición "Filo de Azufre" (+20% daño por pick).
  double _damageMult = 1.0;

  // HP actual del jugador, se conserva entre oleadas.
  double _currentPlayerHp = 100;

  // Sobrecarga Arcana: maná completo para la siguiente oleada.
  bool _startManaFull = false;

  @override
  void initState() {
    super.initState();
    _loadRecord();
    _startWave();
  }

  Future<void> _loadRecord() async {
    final wave =
        await ref.read(playerRepositoryProvider).loadHighestEndlessWave();
    if (mounted) setState(() => _highestEndlessWave = wave);
  }

  void _startWave() {
    _victory = false;
    _defeat = false;
    _blessing = null;
    _selectedBlessing = null;
    _runActive = true;
    _startManaFull = false;
  }

  /// Construye un jefe escalado por oleada: HP = baseHp * 1.25^(wave-1),
  /// ataque = baseAtk * 1.15^(wave-1).
  BossConfig _bossForWave(int wave) {
    final hpMult = math.pow(1.25, wave - 1);
    final atkMult = math.pow(1.15, wave - 1);
    return BossConfig(
      id: 'abyssal_boss_$_wave',
      name: 'Jefe Abisal — Oleada $wave',
      element: Element.values[wave % 4],
      maxHp: BossConfig.pyroth.maxHp * hpMult,
      attackInterval: math.max(2.5, 6.0 - (wave - 1) * 0.25),
      attackDamage: BossConfig.pyroth.attackDamage * atkMult * _damageMult,
      projectilesPerAttack: 2 + (wave % 3),
    );
  }

  List<ManaCard> _squadCards() {
    final collection = ref.read(collectionProvider);
    final squad = <ManaCard>[];
    for (final id in collection.squad.take(4)) {
      final c = collection.owned.firstWhereOrNull(
        (card) => card.instanceId == id,
      );
      if (c != null) {
        squad.add(
          ManaCard(
            id: c.catalogId,
            name: c.name,
            element: c.element,
            baseManaCost: c.baseManaCost,
            attack: c.baseAttack.toDouble(),
            stars: c.stars,
            skillLevel: c.skillLevel,
            masteryRank: c.masteryRank,
          ),
        );
      }
    }
    // Rellenar con cartas por defecto si el escuadrón está incompleto.
    while (squad.length < 4) {
      squad.add(
        ManaCard(
          id: 'ignis_hound',
          name: 'Sabueso de Azufre',
          element: Element.igneous,
          baseManaCost: 100,
          attack: 10,
          skillLevel: 1,
          masteryRank: 1,
        ),
      );
    }
    return squad;
  }

  Future<void> _enterCombat() async {
    final boss = _bossForWave(_wave);
    final cards = _squadCards();
    final synergy = SquadSynergyResolver.resolve(cards);
    // Cargar runas equipadas por carta (keyed by catalogId = c.id).
    final cardRunes = <String, RuneInstance>{};
    final collection = ref.read(collectionProvider);
    final repo = ref.read(playerRepositoryProvider);
    for (final id in collection.squad.take(4)) {
      try {
        final c = collection.owned.firstWhere(
          (card) => card.instanceId == id,
        );
        final manaCard = cards.firstWhere((mc) => mc.id == c.catalogId);
        final rune = await repo.loadCardRune(c.instanceId);
        if (rune != null) cardRunes[manaCard.id] = rune;
      } catch (_) {}
    }
    // Aplicar bendición Sangre Inmortal: curar 35% HP máximo al empezar oleada.
    final playerMaxHp = 100 * (synergy.hpMult);
    final startHp = _currentPlayerHp.clamp(0.0, playerMaxHp);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CombatScreen(
          engine: CombatScreen.buildEngine(
            boss: boss,
            cards: cards,
            playerMaxHp: playerMaxHp,
            synergy: synergy.isActive ? synergy : null,
            cardRunes: cardRunes,
            playerDamageMult: _damageMult,
            startHp: startHp,
            startManaFull: _startManaFull,
          ),
          onCombatResolved: (victory, playerHp) {
            Navigator.of(context).pop();
            _currentPlayerHp = playerHp;
            _resolveWave(victory);
          },
        ),
      ),
    );
  }

  void _resolveWave(bool victory) {
    if (victory) {
      _victory = true;
      _runActive = false;
      // Otorgar oro y esquirlas por oleada superada.
      final gold = 50 * _wave;
      final shards = 25 * _wave;
      ref.read(profileProvider.notifier).grant(gold: gold, shards: shards);
      // Actualizar récord.
      ref.read(playerRepositoryProvider).saveHighestEndlessWave(_wave);
      if (mounted) setState(() => _highestEndlessWave = _wave);
    } else {
      _defeat = true;
      _runActive = false;
    }
    if (mounted) setState(() {});
  }

  void _pickBlessing(int index) {
    _selectedBlessing = index;
    switch (index) {
      case 0: // Sangre Inmortal: curar 35% HP máximo
        ProceduralSfxEngine.playEvolutionSuccess();
        _currentPlayerHp = (_currentPlayerHp + 35.0).clamp(0.0, 100.0);
        break;
      case 1: // Sobrecarga Arcana: maná 100% a las 4 cartas
        ProceduralSfxEngine.playOrbMerge(3);
        _startManaFull = true;
        break;
      case 2: // Filo de Azufre: +20% daño permanente
        _damageMult += 0.20;
        ProceduralSfxEngine.playHitBullseye();
        break;
    }
    _blessing = _blessingNames[index];
    if (mounted) setState(() {});
    // Auto-avanzar a la siguiente oleada tras un breve retraso.
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _wave++;
      _startWave();
      _enterCombat();
    });
  }

  final List<String> _blessingNames = const [
    'Sangre Inmortal',
    'Sobrecarga Arcana',
    'Filo de Azufre',
  ];

  final List<String> _blessingDescriptions = const [
    'Recupera 35% del HP máximo.',
    'Llena al 100% el maná de las 4 cartas para la siguiente oleada.',
    'Aumenta permanentemente tu daño un +20% por el resto de la incursión.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: Text(
          'ABISMO SIN FIN — OLEADA $_wave',
          style: const TextStyle(
            color: Color(0xFFFFC93C),
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFB16EFF)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Text(
                _runActive && !_victory && !_defeat
                    ? 'Oleada $_wave — En combate'
                    : _victory
                        ? '¡Oleada $_wave superada!'
                        : 'Derrota en oleada $_wave',
                style: TextStyle(
                  color: _victory
                      ? const Color(0xFF4FFFA3)
                      : _defeat
                          ? Colors.redAccent
                          : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              if (_runActive && !_victory && !_defeat)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB16EFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.local_fire_department),
                  label: const Text('DESCENDER AL ABISMO'),
                  onPressed: () => _enterCombat(),
                ),
              if (_victory && _blessing == null) ...[
                const SizedBox(height: 10),
                const Text(
                  'Elige una Bendición de Oleada:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...List.generate(3, (i) => _blessingButton(i)),
              ],
              if (_defeat) ...[
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () {
                    _wave = 1;
                    _damageMult = 1.0;
                    _startWave();
                    setState(() {});
                  },
                  child: const Text('Reiniciar Incursión'),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Récord: $_highestEndlessWave oleadas',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blessingButton(int index) {
    final selected = _selectedBlessing == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          backgroundColor:
              selected ? const Color(0xFFB16EFF) : const Color(0xFF1A0E14),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onPressed: selected ? null : () => _pickBlessing(index),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _blessingNames[index],
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _blessingDescriptions[index],
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

extension FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
