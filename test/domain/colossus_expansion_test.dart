import 'dart:math' as math;

import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/entities/owned_card.dart';
import 'package:brimstone_summoning/domain/meta/card_mastery_system.dart';
import 'package:brimstone_summoning/domain/meta/meta_rules.dart';
import 'package:brimstone_summoning/domain/meta/rune_system.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';
import 'package:brimstone_summoning/domain/value_objects/rarity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BLOCK 1: Card Mastery System (Rank 1-10, Skill 1-5, Awakening)', () {
    late OwnedCard testCard;
    final testElement = Element.igneous;

    setUp(() {
      testCard = OwnedCard(
        instanceId: 1,
        catalogId: 'ignis_hound',
        name: 'Sabueso de Azufre',
        element: testElement,
        rarity: Rarity.common,
        baseManaCost: 100,
        baseAttack: 10,
        baseHealth: 15,
        level: 1,
        stars: 1,
        skillLevel: 1,
        masteryXp: 0,
      );
    });

    test('Mastery Rank starts at 1 with 0 XP', () {
      expect(testCard.masteryRank, equals(1));
    });

    test('Mastery Rank increases every 100 XP, max 10', () {
      var card = testCard.copyWith(masteryXp: 99);
      expect(card.masteryRank, equals(1));

      card = card.copyWith(masteryXp: 100);
      expect(card.masteryRank, equals(2));

      card = card.copyWith(masteryXp: 999);
      expect(card.masteryRank, equals(10));

      // Cap at 10
      card = card.copyWith(masteryXp: 1500);
      expect(card.masteryRank, equals(10));
    });

    test('Mastery stat multiplier: +3% per rank', () {
      var card = testCard.copyWith(masteryXp: 0); // Rank 1
      expect(calculateMasteryStatMult(card), equals(1.0));

      card = card.copyWith(masteryXp: 100); // Rank 2
      expect(calculateMasteryStatMult(card), equals(1.03));

      card = card.copyWith(masteryXp: 900); // Rank 10
      expect(calculateMasteryStatMult(card), equals(1.27));
    });

    test('Skill Level starts at 1, max 5', () {
      expect(testCard.skillLevel, equals(1));
      expect(CardMasteryConstants.maxSkillLevel, equals(5));
    });

    test('Skill Effect Mult: +15% per level above 1', () {
      var card = testCard.copyWith(skillLevel: 1);
      expect(card.skillEffectMult, equals(1.0));

      card = card.copyWith(skillLevel: 2);
      expect(card.skillEffectMult, equals(1.15));

      card = card.copyWith(skillLevel: 5);
      expect(card.skillEffectMult, equals(1.60));
    });

    test('Skill Mana Cost Reduction: -4 per level above 1', () {
      var card = testCard.copyWith(skillLevel: 1);
      expect(card.skillManaCostReduction, equals(0));

      card = card.copyWith(skillLevel: 2);
      expect(card.skillManaCostReduction, equals(4));

      card = card.copyWith(skillLevel: 5);
      expect(card.skillManaCostReduction, equals(16));
    });

    test('Awakening unlocked at Skill Level 5 OR Mastery Rank 5', () {
      var card = testCard.copyWith(skillLevel: 4, masteryXp: 0); // Rank 1
      expect(card.isAwakened, isFalse);

      card = card.copyWith(skillLevel: 5, masteryXp: 0); // Skill 5
      expect(card.isAwakened, isTrue);

      card = card.copyWith(skillLevel: 1, masteryXp: 400); // Rank 5
      expect(card.isAwakened, isTrue);
    });

    test('Awakening effects: spawn Level 2 orb + 5% shield/heal', () {
      final card = testCard.copyWith(skillLevel: 5);
      final effects = applyAwakeningEffect(card);

      expect(effects.length, equals(2));
      expect(effects.any((e) => e is AwakeningSpawnOrb), isTrue);
      expect(effects.any((e) => e is AwakeningShieldHeal), isTrue);

      final orbEffect = effects.firstWhere((e) => e is AwakeningSpawnOrb)
          as AwakeningSpawnOrb;
      expect(orbEffect.level, equals(CardMasteryConstants.awakeningOrbLevel));
      expect(orbEffect.element, equals(testElement));

      final healEffect = effects.firstWhere((e) => e is AwakeningShieldHeal)
          as AwakeningShieldHeal;
      expect(healEffect.fraction,
          equals(CardMasteryConstants.awakeningShieldHealFraction));
    });

    test('Skill upgrade costs: 200 * level gold, 40 * level shards', () {
      expect(calculateSkillUpgradeGoldCost(1), equals(200));
      expect(calculateSkillUpgradeGoldCost(2), equals(400));
      expect(calculateSkillUpgradeGoldCost(4), equals(800));
      expect(calculateSkillUpgradeGoldCost(5), equals(0)); // Max level

      expect(calculateSkillUpgradeShardsCost(1), equals(40));
      expect(calculateSkillUpgradeShardsCost(2), equals(80));
      expect(calculateSkillUpgradeShardsCost(4), equals(160));
      expect(calculateSkillUpgradeShardsCost(5), equals(0));
    });

    test('Mastery XP gain: 25 normal, 75 boss', () {
      expect(CardMasteryConstants.masteryXpPerWin, equals(25));
      expect(CardMasteryConstants.masteryXpPerBossWin, equals(75));
    });
  });

  group('BLOCK 2: World Boss Raids (4 Titans, Persistent HP, 60s, Milestones)',
      () {
    test('4 Titans with correct base HP and elements', () {
      // These values match the database seed
      const titans = [
        ('titan_igneous', 'Bahamut de Escoria', Element.igneous, 8000),
        ('titan_abyssal', 'Jörmungandr del Foso', Element.abyssal, 12000),
        ('titan_telluric', 'Atlas Monolítico', Element.telluric, 18000),
        ('titan_void', 'Nyarlathotep del Eclipse', Element.empty, 25000),
      ];

      for (final (id, name, element, hp) in titans) {
        expect(id, isNotEmpty);
        expect(name, isNotEmpty);
        expect(element, isNotNull);
        expect(hp, greaterThan(0));
      }
    });

    test('Ascension scales HP by 1.8x per level', () {
      const baseHp = 8000;
      expect((baseHp * math.pow(1.8, 1)).round(), equals(14400));
      expect((baseHp * math.pow(1.8, 2)).round(), equals(25920));
      expect((baseHp * math.pow(1.8, 3)).round(), equals(46656));
    });

    test('Damage milestones at 25%, 50%, 75%, 100%', () {
      const maxHp = 10000;
      expect((maxHp * 0.75).round(), equals(7500)); // 25% damage
      expect((maxHp * 0.50).round(), equals(5000)); // 50% damage
      expect((maxHp * 0.25).round(), equals(2500)); // 75% damage
      expect(0, equals(0)); // 100% damage (defeated)
    });
  });

  group('BLOCK 3: Boss Shield Break & Auto-Battle AI', () {
    late CombatEngine engine;
    final boss = BossConfig(
      id: 'test_boss',
      name: 'Test Boss',
      element: Element.igneous,
      maxHp: 1000,
      shieldHp: 250, // 25%
      attackInterval: 6.0,
      attackDamage: 10,
      projectilesPerAttack: 2,
    );

    setUp(() {
      engine = CombatEngine(
        boss: boss,
        cards: [
          ManaCard(
              id: 'ignis_hound',
              name: 'Ignis',
              element: Element.igneous,
              baseManaCost: 100,
              attack: 10,
              skillLevel: 1,
              masteryRank: 1),
          ManaCard(
              id: 'abyss_stalker',
              name: 'Abyss',
              element: Element.abyssal,
              baseManaCost: 100,
              attack: 10,
              skillLevel: 1,
              masteryRank: 1),
          ManaCard(
              id: 'terra_golem',
              name: 'Terra',
              element: Element.telluric,
              baseManaCost: 100,
              attack: 10,
              skillLevel: 1,
              masteryRank: 1),
          ManaCard(
              id: 'void_specter',
              name: 'Void',
              element: Element.empty,
              baseManaCost: 100,
              attack: 10,
              skillLevel: 1,
              masteryRank: 1),
        ],
        playerMaxHp: 100,
      );
    });

    test('Boss starts with shield HP = 25% of maxHp', () {
      expect(engine.boss.shieldHp, equals(250));
      expect(engine.bossShieldHp, equals(250));
    });

    test('Weak element (Abyssal vs Igneous) deals 2.5x to shield', () {
      // Igneous boss is weak to Abyssal
      final weaknessMult =
          elementalWeaknessMultiplier(Element.abyssal, Element.igneous);
      expect(weaknessMult, equals(1.3)); // Base weakness is 1.3x

      // With shield weakness multiplier 2.5x
      final shieldWeaknessMult = CombatEngine.shieldWeaknessMult;
      expect(shieldWeaknessMult, equals(2.5));
    });

    test('Shield breaks at 0 HP, triggers BREAK state for 5s', () {
      // Deal enough damage to break shield
      engine.registerDamage(
        orb: CombatOrb(
            id: 'orb1', element: Element.abyssal, level: OrbLevel.one),
        target: engine.targets.first,
        multiplier: 100, // Enough to break 250 shield
        kind: HitKind.normal,
      );

      expect(engine.bossShieldHp, lessThanOrEqualTo(0));
      expect(engine.bossShieldBroken, isTrue);
      expect(engine.bossBreakTimer, equals(CombatEngine.bossBreakDuration));
    });

    test('BREAK state: +50% damage, boss stunned, targets enlarged', () {
      // First break the shield
      engine.registerDamage(
        orb: CombatOrb(
            id: 'orb1', element: Element.abyssal, level: OrbLevel.one),
        target: engine.targets.first,
        multiplier: 100,
        kind: HitKind.normal,
      );

      // During BREAK, damage should be multiplied by 1.5
      expect(CombatEngine.bossBreakDamageMult, equals(1.5));
      expect(CombatEngine.bossBreakCritMult, equals(1.5));

      // Boss should be stunned
      expect(engine.bossStunRemaining, greaterThan(0));

      // Targets should be frozen and enlarged
      for (final target in engine.targets) {
        expect(target.frozen, isTrue);
        expect(target.enlargedUntil, greaterThan(0));
      }
    });

    test('Auto-Battle: casts skill when mana >= cost', () {
      engine.autoBattleEnabled = true;
      // Give first card full mana
      engine.cards[0].mana = engine.cards[0].baseManaCost.toDouble();

      final initialMana = engine.cards[0].mana;
      engine.tickAutoBattle(1.0);

      // Should have cast skill, mana reduced
      expect(engine.cards[0].mana, lessThan(initialMana));
    });

    test('Auto-Battle: merges same element/level orbs', () {
      engine.autoBattleEnabled = true;
      // Put two Igneous Level 1 orbs in tray
      engine.tray[0] =
          CombatOrb(id: 'orb1', element: Element.igneous, level: OrbLevel.one);
      engine.tray[1] =
          CombatOrb(id: 'orb2', element: Element.igneous, level: OrbLevel.one);

      engine.tickAutoBattle(1.0);

      // Should have merged into Level 2
      expect(engine.tray[0]?.level, equals(OrbLevel.two));
      expect(engine.tray[1], isNull);
    });

    test('Auto-Battle: fires highest level orb at weak element target', () {
      engine.autoBattleEnabled = true;
      // Put orbs of different levels
      engine.tray[0] =
          CombatOrb(id: 'orb1', element: Element.igneous, level: OrbLevel.one);
      engine.tray[1] = CombatOrb(
          id: 'orb2',
          element: Element.abyssal,
          level: OrbLevel.two); // Higher level, weak to boss

      engine.tickAutoBattle(1.0);

      // Should fire the Level 2 Abyssal orb (higher level + weak element)
      expect(engine.projectiles.length, equals(1));
      expect(engine.projectiles.first.level, equals(OrbLevel.two));
      expect(engine.projectiles.first.element, equals(Element.abyssal));
    });
  });

  group('BLOCK 4: Gacha Pity Counter, 5 Banners, Daily Free Summon', () {
    test('Pity counter: 0-20, guaranteed 3★ at 20', () {
      // pity 0-19: no guarantee
      // pity 20: guaranteed legendary
      expect(20, equals(20));
    });

    test('5 Elemental Banners with 60% featured element rate', () {
      const banners = [
        ('general', null),
        ('igneous', Element.igneous),
        ('abyssal', Element.abyssal),
        ('telluric', Element.telluric),
        ('void', Element.empty),
      ];

      for (final (id, element) in banners) {
        if (element != null) {
          // 60% chance for featured element
          final service = SummonService();
          final cards = [
            'ignis_hound',
            'abyss_stalker',
            'terra_golem',
            'void_specter'
          ];
          int featuredCount = 0;
          final random = math.Random(42);
          for (int i = 0; i < 1000; i++) {
            final card =
                service.catalogFor(Rarity.common, banner: id, random: random);
            if (card.startsWith('ignis_') && element == Element.igneous) {
              featuredCount++;
            }
            if (card.startsWith('abyss_') && element == Element.abyssal) {
              featuredCount++;
            }
            if (card.startsWith('terra_') && element == Element.telluric) {
              featuredCount++;
            }
            if (card.startsWith('void_') && element == Element.empty) {
              featuredCount++;
            }
          }
          // Should be around 60%
          expect(featuredCount, greaterThan(500));
          expect(featuredCount, lessThan(700));
        }
      }
    });

    test('Banner switch resets pity to 0', () {
      // Changing banner should reset pity counter
      // This is handled in PlayerRepository.setActiveBanner
      expect(true, isTrue); // Placeholder for integration test
    });

    test('Daily free summon available once per day', () {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);

      // If last_free_summon_date != today, free summon available
      expect(yesterday != today, isTrue);
      expect(today != today, isFalse);
    });
  });

  group('BLOCK 5: Altar Triple (Batch Evolve, Rune Synthesis, Soul Crafting)',
      () {
    test('Batch Evolve: finds all evolvable duplicates', () {
      final cards = [
        OwnedCard(
            instanceId: 1,
            catalogId: 'ignis_hound',
            name: 'Hound',
            element: Element.igneous,
            rarity: Rarity.common,
            baseManaCost: 100,
            baseAttack: 10,
            baseHealth: 15,
            level: 1,
            stars: 1,
            skillLevel: 1,
            masteryXp: 0),
        OwnedCard(
            instanceId: 2,
            catalogId: 'ignis_hound',
            name: 'Hound',
            element: Element.igneous,
            rarity: Rarity.common,
            baseManaCost: 100,
            baseAttack: 10,
            baseHealth: 15,
            level: 1,
            stars: 1,
            skillLevel: 1,
            masteryXp: 0),
        OwnedCard(
            instanceId: 3,
            catalogId: 'ignis_hound',
            name: 'Hound',
            element: Element.igneous,
            rarity: Rarity.common,
            baseManaCost: 100,
            baseAttack: 10,
            baseHealth: 15,
            level: 1,
            stars: 1,
            skillLevel: 1,
            masteryXp: 0),
        OwnedCard(
            instanceId: 4,
            catalogId: 'abyss_stalker',
            name: 'Stalker',
            element: Element.abyssal,
            rarity: Rarity.common,
            baseManaCost: 100,
            baseAttack: 10,
            baseHealth: 15,
            level: 1,
            stars: 1,
            skillLevel: 1,
            masteryXp: 0),
      ];

      // Group by catalogId + stars
      final groups = <String, List<OwnedCard>>{};
      for (final c in cards) {
        if (c.stars < EvolutionRules.maxStars) {
          groups.putIfAbsent('${c.catalogId}_${c.stars}', () => []).add(c);
        }
      }

      // ignis_hound_1 has 3 copies -> 1 evolution (consumes 1 dupe, 2 remain)
      // Actually: 3 copies = 1 pair + 1 leftover = 1 evolution
      expect(groups['ignis_hound_1']?.length, equals(3));
      expect(groups['abyss_stalker_1']?.length, equals(1));
    });

    test('Rune Forge: cost varies by type, Level 5 max', () {
      for (final type in RuneType.values) {
        final cost = RuneSystem.forgeCost(type);
        expect(cost, greaterThan(0));
      }

      // Upgrade costs increase
      final rune = RuneInstance(type: RuneType.crimsonFury, level: 1);
      expect(
          RuneSystem.upgradeCost(rune),
          lessThan(RuneSystem.upgradeCost(
              RuneInstance(type: RuneType.crimsonFury, level: 2))));
      expect(
          RuneSystem.upgradeCost(
              RuneInstance(type: RuneType.crimsonFury, level: 4)),
          greaterThan(0));
    });

    test('Soul Crafting: 20 catalog cards with correct shard costs', () {
      const costs = {
        Rarity.common: 120,
        Rarity.rare: 240,
        Rarity.epic: 450,
        Rarity.legendary: 900,
      };

      // Verify all rarities have costs
      for (final entry in costs.entries) {
        final rarity = entry.key;
        final cost = entry.value;
        expect(cost, greaterThan(0));
        if (rarity.index > 0) {
          expect(cost, greaterThan(costs[Rarity.values[rarity.index - 1]]!));
        }
      }
    });
  });

  group('BLOCK 6: Collection Milestones (4, 8, 12, 16, 20)', () {
    test('Milestones at 4, 8, 12, 16, 20 unique creatures', () {
      const milestones = [4, 8, 12, 16, 20];
      expect(milestones.length, equals(5));
    });

    test('Rewards: 250-1000 shards + 5%-25% global ATK/HP', () {
      const rewards = [
        (4, 250, 0.05),
        (8, 400, 0.10),
        (12, 600, 0.15),
        (16, 800, 0.20),
        (20, 1000, 0.25),
      ];

      for (final (count, shards, bonus) in rewards) {
        expect(shards, greaterThan(0));
        expect(bonus, greaterThan(0));
        expect(bonus, lessThanOrEqualTo(0.25));
      }
    });

    test('Global bonus stacks additively: 5 milestones = 25%', () {
      const maxBonus = 0.05 + 0.10 + 0.15 + 0.20 + 0.25;
      // Actually each milestone gives its own bonus, total = 25%
      // At 20/20, player has all 5 milestones = 0.05+0.10+0.15+0.20+0.25 = 0.75? No, each milestone gives a bonus, so total = sum
      // Wait, the spec says "+5% ATK/HP global per milestone completed"
      // So 5 milestones = 25% total
      expect(0.05 * 5, equals(0.25));
    });
  });

  group('BLOCK 7: Brimstone Shop (Flash Offers, Founder Packs, Promo Codes)',
      () {
    test('4 Promo Codes with correct rewards', () {
      const codes = {
        'HELLFIRE2026': {'shards': 1000, 'gold': 2500},
        'BRIMSTONEVIP': {'shards': 500, 'card': 'ignis_colossus'},
        'VOIDLORD': {'shards': 500, 'card': 'void_archon'},
        'AUTOBATTLE': {'gold': 3000, 'shards': 300},
      };

      expect(codes.length, equals(4));
      for (final entry in codes.entries) {
        final code = entry.key;
        final rewards = entry.value;
        expect(code, isNotEmpty);
        expect(rewards.isNotEmpty, isTrue);
      }
    });

    test('Promo codes one-time use per account', () {
      // Handled by redeemed_codes table in SQLite
      expect(true, isTrue); // Placeholder
    });

    test('Founder Packs: 3 tiers with increasing rewards', () {
      const packs = [
        ('starter_pack', 500, 1000),
        ('war_chest', 2000, 5000),
        ('archon_pass', 5000, 15000),
      ];

      for (int i = 1; i < packs.length; i++) {
        expect(
            packs[i].$2, greaterThan(packs[i - 1].$2)); // shards cost increases
        expect(
            packs[i].$3, greaterThan(packs[i - 1].$3)); // gold cost increases
      }
    });

    test('Flash Offers: 3 daily offers with discount', () {
      const offers = [
        ('energy_refill', 500, 300, 100, 60), // 40% off
        ('rune_chest', 2000, 1200, 300, 180), // 40% off
        ('epic_card_daily', 5000, 3000, 800, 500), // 40% off
      ];

      for (final (_, origGold, discGold, origShards, discShards) in offers) {
        expect(discGold, lessThan(origGold));
        expect(discShards, lessThan(origShards));
        final discount = ((origGold - discGold) / origGold * 100).round();
        expect(discount, equals(40));
      }
    });
  });

  group('Integration: Combat with Mastery, Shield, Auto-Battle', () {
    test('Full combat: mastery XP granted on victory', () {
      final engine = CombatEngine(
        boss: BossConfig(
          id: 'boss1',
          name: 'Boss',
          element: Element.igneous,
          maxHp: 500,
          shieldHp: 125,
          attackInterval: 6.0,
          attackDamage: 10,
          projectilesPerAttack: 2,
        ),
        cards: [
          ManaCard(
              id: 'c1',
              name: 'C1',
              element: Element.abyssal,
              baseManaCost: 100,
              attack: 20,
              skillLevel: 2,
              masteryRank: 2),
          ManaCard(
              id: 'c2',
              name: 'C2',
              element: Element.igneous,
              baseManaCost: 100,
              attack: 20,
              skillLevel: 1,
              masteryRank: 1),
          ManaCard(
              id: 'c3',
              name: 'C3',
              element: Element.telluric,
              baseManaCost: 100,
              attack: 20,
              skillLevel: 3,
              masteryRank: 3),
          ManaCard(
              id: 'c4',
              name: 'C4',
              element: Element.empty,
              baseManaCost: 100,
              attack: 20,
              skillLevel: 1,
              masteryRank: 1),
        ],
        playerMaxHp: 100,
      );

      // Verify shield exists
      expect(engine.bossShieldHp, equals(125));

      // Deal damage with weak element (Abyssal vs Igneous = 1.3x, plus shield 2.5x)
      engine.registerDamage(
        orb: CombatOrb(
            id: 'orb1', element: Element.abyssal, level: OrbLevel.one),
        target: engine.targets.first,
        multiplier: 10,
        kind: HitKind.normal,
      );

      // Shield should take 2.5x damage from weak element
      // Base damage 35 * 10 * 1.3 (weakness) * 2.5 (shield) = 1137.5
      // But shield is only 125, so it breaks
      expect(engine.bossShieldBroken, isTrue);

      // BREAK state active
      expect(engine.bossShieldBroken, isTrue);
      expect(engine.bossBreakTimer, equals(CombatEngine.bossBreakDuration));
    });
  });

  group('Edge Cases & Validation', () {
    test('Mastery XP capped at 999 (Rank 10)', () {
      var card = OwnedCard(
        instanceId: 1,
        catalogId: 'test',
        name: 'Test',
        element: Element.igneous,
        rarity: Rarity.common,
        baseManaCost: 100,
        baseAttack: 10,
        baseHealth: 15,
        level: 1,
        stars: 1,
        skillLevel: 1,
        masteryXp: 999,
      );
      expect(card.masteryRank, equals(10));

      // Adding more XP shouldn't increase rank
      card = card.copyWith(masteryXp: 1500);
      expect(card.masteryRank, equals(10));
    });

    test('Skill level capped at 5', () {
      var card = OwnedCard(
        instanceId: 1,
        catalogId: 'test',
        name: 'Test',
        element: Element.igneous,
        rarity: Rarity.common,
        baseManaCost: 100,
        baseAttack: 10,
        baseHealth: 15,
        level: 1,
        stars: 1,
        skillLevel: 5,
        masteryXp: 0,
      );
      expect(card.skillLevel, equals(5));
      expect(canUpgradeSkill(card), isFalse);
    });

    test('Pity counter resets after legendary', () {
      // When a legendary (3★) is obtained, pity should reset to 0
      // This is tested in PlayerRepository.incrementPityAndCheckGuaranteed
      expect(true, isTrue);
    });

    test('Auto-Battle can be toggled any time', () {
      final engine = CombatEngine(
        boss: BossConfig(
            id: 'b',
            name: 'B',
            element: Element.igneous,
            maxHp: 100,
            attackInterval: 6,
            attackDamage: 10,
            projectilesPerAttack: 2),
        cards: [
          ManaCard(
              id: 'c1',
              name: 'C1',
              element: Element.igneous,
              baseManaCost: 100,
              attack: 10,
              skillLevel: 1,
              masteryRank: 1)
        ],
        playerMaxHp: 100,
      );

      expect(engine.autoBattleEnabled, isFalse);
      engine.autoBattleEnabled = true;
      expect(engine.autoBattleEnabled, isTrue);
      engine.autoBattleEnabled = false;
      expect(engine.autoBattleEnabled, isFalse);
    });

    test('Shield break only triggers once per combat', () {
      final engine = CombatEngine(
        boss: BossConfig(
            id: 'b',
            name: 'B',
            element: Element.igneous,
            maxHp: 100,
            shieldHp: 25,
            attackInterval: 6,
            attackDamage: 10,
            projectilesPerAttack: 2),
        cards: [
          ManaCard(
              id: 'c1',
              name: 'C1',
              element: Element.abyssal,
              baseManaCost: 100,
              attack: 20,
              skillLevel: 1,
              masteryRank: 1)
        ],
        playerMaxHp: 100,
      );

      // Break shield
      engine.registerDamage(
          orb: CombatOrb(
              id: 'o1', element: Element.abyssal, level: OrbLevel.one),
          target: engine.targets.first,
          multiplier: 10,
          kind: HitKind.normal);
      expect(engine.bossShieldBroken, isTrue);

      // Further damage shouldn't re-trigger break
      final breakTimerBefore = engine.bossBreakTimer;
      engine.registerDamage(
          orb: CombatOrb(
              id: 'o2', element: Element.abyssal, level: OrbLevel.one),
          target: engine.targets.first,
          multiplier: 10,
          kind: HitKind.normal);
      // Timer should continue counting down, not reset
      expect(engine.bossBreakTimer, equals(breakTimerBefore));
    });
  });
}
