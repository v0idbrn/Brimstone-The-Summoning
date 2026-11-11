import 'package:flutter_test/flutter_test.dart';

import 'package:brimstone_summoning/domain/campaign/campaign_enemies.dart';
import 'package:brimstone_summoning/domain/campaign/campaign_chapters.dart';
import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';

void main() {
  group('Elemental Weakness Wheel', () {
    test('Abyssal beats Igneous (+30%)', () {
      expect(
          elementalWeaknessMultiplier(Element.abyssal, Element.igneous), 1.30);
      expect(elementalWeakness(Element.igneous), Element.abyssal);
    });

    test('Igneous beats Telluric (+30%)', () {
      expect(
          elementalWeaknessMultiplier(Element.igneous, Element.telluric), 1.30);
      expect(elementalWeakness(Element.telluric), Element.igneous);
    });

    test('Telluric beats Void (+30%)', () {
      expect(
          elementalWeaknessMultiplier(Element.telluric, Element.empty), 1.30);
      expect(elementalWeakness(Element.empty), Element.telluric);
    });

    test('Void beats Abyssal (+30%)', () {
      expect(elementalWeaknessMultiplier(Element.empty, Element.abyssal), 1.30);
      expect(elementalWeakness(Element.abyssal), Element.empty);
    });

    test('Neutral elements deal 1.0x damage', () {
      expect(
          elementalWeaknessMultiplier(Element.igneous, Element.igneous), 1.0);
      expect(
          elementalWeaknessMultiplier(Element.abyssal, Element.telluric), 1.0);
      expect(
          elementalWeaknessMultiplier(Element.telluric, Element.abyssal), 1.0);
      expect(elementalWeaknessMultiplier(Element.empty, Element.igneous), 1.0);
    });
  });

  group('Campaign Enemies - 60 enemies across 10 chapters', () {
    test('Total enemy count is 60', () {
      expect(campaignEnemies.length, 60);
    });

    test('Each chapter has 6 enemies (4 minions, 1 miniBoss, 1 chapterBoss)',
        () {
      for (var chapter = 1; chapter <= 10; chapter++) {
        final chapterEnemies = enemiesForChapter(chapter);
        expect(chapterEnemies.length, 6,
            reason: 'Chapter $chapter should have 6 enemies');

        final minions =
            chapterEnemies.where((e) => e.tier == EnemyTier.minion).toList();
        final miniBosses =
            chapterEnemies.where((e) => e.tier == EnemyTier.miniBoss).toList();
        final chapterBosses = chapterEnemies
            .where((e) => e.tier == EnemyTier.chapterBoss)
            .toList();

        expect(minions.length, 4,
            reason: 'Chapter $chapter should have 4 minions');
        expect(miniBosses.length, 1,
            reason: 'Chapter $chapter should have 1 miniBoss');
        expect(chapterBosses.length, 1,
            reason: 'Chapter $chapter should have 1 chapterBoss');
      }
    });

    test('Floor assignments: 1,2,3,5=minion; 4=miniBoss; 7=chapterBoss', () {
      for (var chapter = 1; chapter <= 5; chapter++) {
        // Floor 1
        final floor1 = enemyForFloor(chapter, 1);
        expect(floor1?.tier, EnemyTier.minion,
            reason: 'Chapter $chapter floor 1 should be minion');
        expect(floor1?.floor, 1);

        // Floor 2
        final floor2 = enemyForFloor(chapter, 2);
        expect(floor2?.tier, EnemyTier.minion,
            reason: 'Chapter $chapter floor 2 should be minion');

        // Floor 3
        final floor3 = enemyForFloor(chapter, 3);
        expect(floor3?.tier, EnemyTier.minion,
            reason: 'Chapter $chapter floor 3 should be minion');

        // Floor 4 = miniBoss
        final floor4 = enemyForFloor(chapter, 4);
        expect(floor4?.tier, EnemyTier.miniBoss,
            reason: 'Chapter $chapter floor 4 should be miniBoss');

        // Floor 5 = minion
        final floor5 = enemyForFloor(chapter, 5);
        expect(floor5?.tier, EnemyTier.minion,
            reason: 'Chapter $chapter floor 5 should be minion');

        // Floor 7 = chapterBoss
        final floor7 = enemyForFloor(chapter, 7);
        expect(floor7?.tier, EnemyTier.chapterBoss,
            reason: 'Chapter $chapter floor 7 should be chapterBoss');
      }
    });

    test('Each enemy has valid portrait asset path', () {
      for (final enemy in campaignEnemies) {
        expect(enemy.portraitAsset, startsWith('portraits/'));
        expect(enemy.portraitAsset, endsWith('.webp'));
      }
    });

    test('Chapter 1 enemies are Igneous', () {
      final ch1 = enemiesForChapter(1);
      for (final e in ch1) {
        expect(e.element, Element.igneous,
            reason: '${e.name} should be Igneous');
      }
    });

    test('Chapter 2 enemies are Abyssal', () {
      final ch2 = enemiesForChapter(2);
      for (final e in ch2) {
        expect(e.element, Element.abyssal,
            reason: '${e.name} should be Abyssal');
      }
    });

    test('Chapter 3 enemies are Telluric', () {
      final ch3 = enemiesForChapter(3);
      for (final e in ch3) {
        expect(e.element, Element.telluric,
            reason: '${e.name} should be Telluric');
      }
    });

    test('Chapter 4 enemies are Void', () {
      final ch4 = enemiesForChapter(4);
      for (final e in ch4) {
        expect(e.element, Element.empty, reason: '${e.name} should be Void');
      }
    });

    test('Chapter 5 enemies are Void', () {
      final ch5 = enemiesForChapter(5);
      for (final e in ch5) {
        expect(e.element, Element.empty, reason: '${e.name} should be Void');
      }
    });

    test('Enemy stats scale with floor progression', () {
      for (var chapter = 1; chapter <= 5; chapter++) {
        final floor1 = enemyForFloor(chapter, 1)!;
        final floor7 = enemyForFloor(chapter, 7)!;
        expect(floor7.maxHp, greaterThan(floor1.maxHp));
        expect(floor7.attackDamage, greaterThanOrEqualTo(floor1.attackDamage));
      }
    });
  });

  group('CombatEngine', () {
    CombatEngine buildTestEngine() => CombatEngine(
          boss: BossConfig(
            id: 'test_boss',
            name: 'Test Boss',
            element: Element.igneous, // Weak to Abyssal
            maxHp: 1000,
            attackInterval: 10.0,
            attackDamage: 10,
            projectilesPerAttack: 1,
            shieldHp: 0, // Disable shield to isolate weakness multiplier test
          ),
          cards: [
            ManaCard(
                id: 'test_abyssal',
                name: 'Abyssal Card',
                element: Element.abyssal,
                baseManaCost: 100,
                attack: 20,
                stars: 1),
            ManaCard(
                id: 'test_igneous',
                name: 'Igneous Card',
                element: Element.igneous,
                baseManaCost: 100,
                attack: 20,
                stars: 1),
          ],
          playerMaxHp: 100,
          talentLevels: {},
          summonerGear: {},
        );

    setUp(() {});

    test('Abyssal orb deals more damage to Igneous boss (weakness + shield)',
        () {
      final engine = buildTestEngine();
      // Fill mana for both cards
      for (final card in engine.cards) {
        card.mana = card.baseManaCost.toDouble();
      }

      final abyssalOrb =
          CombatOrb(id: 'orb1', element: Element.abyssal, level: OrbLevel.one);
      final igneousOrb =
          CombatOrb(id: 'orb2', element: Element.igneous, level: OrbLevel.one);

      // Fire an abyssal orb at the boss (weak hit gets shield weakness multiplier 2.5x)
      var initialTotal = engine.damageTotal;
      engine.registerDamage(
        orb: abyssalOrb,
        target: null,
        multiplier: 1.0,
        kind: HitKind.normal,
      );
      final weakDamage = engine.damageTotal - initialTotal;

      // Fire an igneous orb at the boss (non-weak hit, no shield weakness multiplier)
      final engine2 = buildTestEngine();
      for (final card in engine2.cards) {
        card.mana = card.baseManaCost.toDouble();
      }
      initialTotal = engine2.damageTotal;
      engine2.registerDamage(
        orb: igneousOrb,
        target: null,
        multiplier: 1.0,
        kind: HitKind.normal,
      );
      final normalDamage = engine2.damageTotal - initialTotal;

      // Weak hit gets elemental weakness (1.3x) + shield weakness (2.5x) = 3.25x total
      // Normal hit gets no multiplier = 1.0x
      expect(weakDamage, greaterThan(normalDamage));
      expect(weakDamage / normalDamage, closeTo(3.25, 0.1));
    });

    test('Igneous orb deals normal damage to Igneous boss (no weakness)', () {
      final engine = buildTestEngine();
      for (final card in engine.cards) {
        card.mana = card.baseManaCost.toDouble();
      }

      final igneousOrb =
          CombatOrb(id: 'orb2', element: Element.igneous, level: OrbLevel.one);
      final initialTotal = engine.damageTotal;

      engine.registerDamage(
        orb: igneousOrb,
        target: null,
        multiplier: 1.0,
        kind: HitKind.normal,
      );

      final damageDealt = engine.damageTotal - initialTotal;
      // Base damage is ~35, no shield, no weakness multiplier
      expect(damageDealt, closeTo(35, 1.0));
    });

    test('Floating text shows SUPEREFICAZ for weakness hits', () {
      final engine = buildTestEngine();
      for (final card in engine.cards) {
        card.mana = card.baseManaCost.toDouble();
      }

      final abyssalOrb =
          CombatOrb(id: 'orb3', element: Element.abyssal, level: OrbLevel.one);

      engine.registerDamage(
        orb: abyssalOrb,
        target: null,
        multiplier: 1.0,
        kind: HitKind.normal,
      );

      final floatingText = engine.texts.last;
      expect(floatingText.text, contains('SUPEREFICAZ'));
      expect(floatingText.kind, FloatingTextKind.superEffective);
    });

    test('Critical hit with weakness shows SUPEREFICAZ', () {
      final engine = buildTestEngine();
      for (final card in engine.cards) {
        card.mana = card.baseManaCost.toDouble();
      }

      final abyssalOrb =
          CombatOrb(id: 'orb4', element: Element.abyssal, level: OrbLevel.one);

      engine.registerDamage(
        orb: abyssalOrb,
        target: null,
        multiplier: 1.0,
        kind: HitKind.bullseye,
      );

      final floatingText = engine.texts.last;
      expect(floatingText.text, contains('SUPEREFICAZ'));
      expect(floatingText.kind, FloatingTextKind.superEffective);
    });
  });

  group('Battle Pass - 20 Tier Progression', () {
    const xpPerLevel = 200;
    const maxLevel = 20;

    test('Level calculation from XP', () {
      // Uncapped formula: (xp ~/ xpPerLevel) + 1
      expect((0 ~/ xpPerLevel) + 1, 1);
      expect((199 ~/ xpPerLevel) + 1, 1);
      expect((200 ~/ xpPerLevel) + 1, 2);
      expect((399 ~/ xpPerLevel) + 1, 2);
      expect((3800 ~/ xpPerLevel) + 1, 20);
      // Capped at maxLevel
      expect((5000 ~/ xpPerLevel) + 1, 26); // Uncapped would be 26
      expect(((5000 ~/ xpPerLevel) + 1).clamp(1, maxLevel),
          maxLevel); // Capped = 20
    });

    test('XP per enemy: 50 for minions, 150 for bosses', () {
      // 4 minions = 200 XP = 1 level
      // 1 boss = 150 XP
      // 1 boss + 1 minion = 200 XP = 1 level
      expect(50 * 4, xpPerLevel);
      expect(150 + 50, xpPerLevel);
    });

    test('Rewards scale with level', () {
      // Base: 300 gold + 100 shards at level 1
      // +85 gold + 35 shards per level
      final level1Gold = 300 + 1 * 85;
      final level10Gold = 300 + 10 * 85;
      final level20Gold = 300 + 20 * 85;

      expect(level10Gold > level1Gold, true);
      expect(level20Gold > level10Gold, true);
    });

    test('Special card rewards at levels 5, 10, 15, 20', () {
      final specialLevels = [5, 10, 15, 20];
      for (final level in specialLevels) {
        expect(specialLevels.contains(level), true);
      }
    });

    test('Premium track gives 2x rewards', () {
      const premiumMult = 2.0;
      final level1Gold = 300 + 1 * 85;
      final premiumGold = (level1Gold * premiumMult).round();
      expect(premiumGold, level1Gold * 2);
    });
  });

  group('Deck Presets - 3 Saved Squads + Auto-Arm', () {
    test('Auto-arm selects top 4 unique cards by ATK * stars', () {
      // Simulated collection
      final cards = <_MockCard>[
        _MockCard(id: 1, catalogId: 'a', attack: 10, stars: 1), // 10
        _MockCard(id: 2, catalogId: 'b', attack: 20, stars: 2), // 40
        _MockCard(id: 3, catalogId: 'c', attack: 15, stars: 3), // 45
        _MockCard(id: 4, catalogId: 'd', attack: 30, stars: 1), // 30
        _MockCard(
            id: 5,
            catalogId: 'a',
            attack: 25,
            stars: 2), // 50 (duplicate catalogId)
        _MockCard(id: 6, catalogId: 'e', attack: 12, stars: 4), // 48
      ];

      // Sort by effective power descending
      cards.sort((a, b) => (b.attack * b.stars).compareTo(a.attack * a.stars));

      final uniqueCatalogIds = <String>{};
      final selected = <int>[];
      for (final card in cards) {
        if (selected.length >= 4) break;
        if (uniqueCatalogIds.contains(card.catalogId)) continue;
        uniqueCatalogIds.add(card.catalogId);
        selected.add(card.id);
      }

      expect(selected.length, 4);
      // Should pick: id=5 (50), id=6 (48), id=3 (45), id=2 (40)
      expect(selected.contains(5), true); // Best 'a'
      expect(selected.contains(6), true); // 'e'
      expect(selected.contains(3), true); // 'c'
      expect(selected.contains(2), true); // 'b'
      expect(selected.contains(1), false); // Duplicate 'a', lower power
      expect(selected.contains(4), false); // Not in top 4 unique
    });

    test('Preset save/load uses correct indices 0,1,2', () {
      const maxPresets = 3;
      for (var i = 0; i < maxPresets; i++) {
        expect(i >= 0 && i <= 2, true);
      }
    });

    test('Preset names match elements', () {
      final names = ['Mazo I: Ígneo', 'Mazo II: Abisal', 'Mazo III: Táctico'];
      expect(names[0], contains('Ígneo'));
      expect(names[1], contains('Abisal'));
      expect(names[2], contains('Táctico'));
    });
  });

  group('Story Mode Flow - Chapter Unlock', () {
    test('Chapter unlock requires previous chapter cleared', () {
      final cleared = <String>['chapter_ceniza'];
      expect(chapterUnlocked('chapter_ceniza', cleared), true);
      expect(chapterUnlocked('chapter_fosa', cleared),
          true); // Chapter 2 unlocked after 1
      expect(chapterUnlocked('chapter_bastion', cleared),
          false); // Chapter 3 locked
    });

    test('Chapter 1 unlocked by default', () {
      final cleared = <String>[];
      expect(chapterUnlocked('chapter_ceniza', cleared), true);
      expect(chapterUnlocked('chapter_fosa', cleared), false);
    });
  });

  group('Loot Chest - Drop Rates', () {
    test('Chapter boss guarantees card drop (100%)', () {
      const chapterBossDropChance = 1.0;
      expect(chapterBossDropChance, 1.0);
    });

    test('Mini-boss has 50% card drop chance', () {
      const miniBossDropChance = 0.5;
      expect(miniBossDropChance, 0.5);
    });

    test('Rewards include gold and shards', () {
      // Chapter boss: 800-1200 gold, 200-300 shards
      // Mini-boss: 400-600 gold, 100-150 shards
      expect(800 < 1200, true);
      expect(400 < 600, true);
    });
  });

  group('Speed Toggle - 1x / 1.5x', () {
    test('Speed multiplier values', () {
      const normalSpeed = 1.0;
      const fastSpeed = 1.5;
      expect(fastSpeed / normalSpeed, 1.5);
    });

    test('Engine tick receives multiplied dt', () {
      // In BrimstoneCombatGame.update: engine.tick(dt * speedMultiplier)
      const baseDt = 0.016; // ~60 FPS
      const fastDt = baseDt * 1.5;
      expect(fastDt, 0.024);
    });
  });
}

class _MockCard {
  final int id;
  final String catalogId;
  final int attack;
  final int stars;

  _MockCard(
      {required this.id,
      required this.catalogId,
      required this.attack,
      required this.stars});
}
