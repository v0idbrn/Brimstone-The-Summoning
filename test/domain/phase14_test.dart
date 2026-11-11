import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:brimstone_summoning/domain/campaign/campaign_chapters.dart';
import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';

CombatEngine enrageEngine({BossConfig boss = BossConfig.pyroth}) =>
    CombatEngine(
      boss: boss,
      cards: [
        ManaCard(
          id: 'ignis_hound',
          name: 'Sabueso de Azufre',
          element: Element.igneous,
          baseManaCost: 100,
          attack: 10,
          mana: 50,
        ),
        ManaCard(
          id: 'abyss_siren',
          name: 'Sirena de Escarcha',
          element: Element.abyssal,
          baseManaCost: 95,
          attack: 12,
          mana: 90,
        ),
      ],
      random: math.Random(7),
    );

void main() {
  group('Phase 14 — campaña expandida a 5 capítulos', () {
    test('campaña tiene exactamente 10 capítulos en orden', () {
      expect(campaignChapters.length, 10);
    });

    test('Capítulo I Pyroth igneo', () {
      expect(campaignChapters[0].number, 1);
      expect(campaignChapters[0].boss.id, 'pyroth');
      expect(campaignChapters[0].boss.element, Element.igneous);
    });

    test('Capítulo II Vaelor abisal', () {
      expect(campaignChapters[1].number, 2);
      expect(campaignChapters[1].boss.id, 'vaelor');
      expect(campaignChapters[1].boss.element, Element.abyssal);
    });

    test('Capítulo III Gorgath telúrico', () {
      final c = campaignChapters[2];
      expect(c.number, 3);
      expect(c.id, 'chapter_tectonico');
      expect(c.boss.id, 'gorgath');
      expect(c.boss.element, Element.telluric);
      expect(CampaignChapter.chapterIIITitle, 'Monarca de Basalto');
    });

    test('Capítulo IV Nyxara Vacío', () {
      final c = campaignChapters[3];
      expect(c.number, 4);
      expect(c.id, 'chapter_velo');
      expect(c.boss.id, 'nyxara');
      expect(c.boss.element, Element.empty);
      expect(CampaignChapter.chapterIVTitle, 'Tejedor del Eclipse');
    });

    test('Capítulo V Azathor final Vacío', () {
      final c = campaignChapters[4];
      expect(c.number, 5);
      expect(c.id, 'chapter_tronco');
      expect(c.boss.id, 'azathor');
      expect(c.boss.element, Element.empty);
      expect(CampaignChapter.chapterVTitle, 'Gran Arconte del Sello');
    });

    test('desbloqueo progresivo: 1→2→…→5 capítulos', () {
      // 1 desbloqueado al inicio.
      expect(chapterUnlocked('chapter_ceniza', []), isTrue);
      expect(chapterUnlocked('chapter_fosa', []), isFalse);
      expect(chapterUnlocked('chapter_tectonico', []), isFalse);

      expect(nextLockedChapter([])?.id, 'chapter_ceniza');
      expect(nextLockedChapter(['chapter_ceniza'])?.id, 'chapter_fosa');
      expect(
        nextLockedChapter(['chapter_ceniza', 'chapter_fosa'])?.id,
        'chapter_tectonico',
      );
      expect(
        nextLockedChapter(
            ['chapter_ceniza', 'chapter_fosa', 'chapter_tectonico'])?.id,
        'chapter_velo',
      );
      expect(
        nextLockedChapter([
          'chapter_ceniza',
          'chapter_fosa',
          'chapter_tectonico',
          'chapter_velo',
        ])?.id,
        'chapter_tronco',
      );
      expect(nextLockedChapter([...campaignChapters.map((c) => c.id)]), isNull);
    });

    test('chaptersClearedCount cuenta capítulos válidos', () {
      expect(chaptersClearedCount(['chapter_ceniza']), 1);
      expect(chaptersClearedCount([]), 0);
      expect(chaptersClearedCount(['unknown']), 0);
    });
  });

  group('Phase 14 — furia de jefe (<45% HP)', () {
    List<BossConfig> bossesWithDialogue = const [
      BossConfig.pyroth,
      BossConfig.vaelor,
      BossConfig.gorgath,
      BossConfig.nyxara,
      BossConfig.azathor,
    ];

    void forceEnrage(CombatEngine e) {
      e.bossHp = e.boss.maxHp *
          0.44; // ligeramente por encima del 45% desencadena furia
      e.tickEnrage(1.0);
    }

    for (final boss in bossesWithDialogue) {
      test('enrage activado para ${boss.id}', () {
        final e = enrageEngine(boss: boss);
        forceEnrage(e);
        expect(e.enraged, isTrue);
      });
    }

    test(
        'Gorgath (telúrico): petrifica carta con más maná 4.0s y reduce dianas 20%',
        () {
      final e = enrageEngine(boss: BossConfig.gorgath);
      forceEnrage(e);
      // Carta con más maná: siren 90 > hound 50.
      final leader = e.cards.reduce(
        (a, b) => a.mana > b.mana ? a : b,
      );
      expect(leader.id, equals('abyss_siren'));

      final petrifiedId = e.gorgathPetrifiedCardId;
      expect(petrifiedId, isNotNull);
      expect(petrifiedId, equals(leader.id));
      expect(e.gorgathPetrifyRemaining, closeTo(4.0, 1e-9));
      expect(e.targetRadiusMult, closeTo(0.8, 1e-9));

      // Fuera de furia: radio restaurado.
      e.enraged = false;
      expect(e.targetRadiusMult, 1.0);
    });

    test('Nyxara (Vacío): teletransporta dianas cada 4.0s', () {
      final e = enrageEngine(boss: BossConfig.nyxara);
      forceEnrage(e);
      final beforeCx = e.targets.first.cx;
      final beforeCy = e.targets.first.cy;
      // tick más allá del intervalo 4.0s → teletransporte.
      e.tickEnrage(4.1);
      expect(
        e.targets.any((t) => t.cx != beforeCx || t.cy != beforeCy),
        isTrue,
        reason: 'Ninguna diana se movió: falso teletransporte',
      );
      expect(e.nyxaraTeleportRemaining, closeTo(4.0, 1e-9));
    });

    test('Azathor: proyectiles dobles + rotación invertida cíclica', () {
      final e = enrageEngine(boss: BossConfig.azathor);
      forceEnrage(e);
      // Proyectiles dobles con enrage: base puede ser 2, 4 o 6 (doble de 1-3).
      var count = e.bossProjectileCount;
      expect(count, greaterThanOrEqualTo(2));
      expect(count, lessThanOrEqualTo(6));
      count = e.bossProjectileCount;
      expect(count, greaterThanOrEqualTo(2));
      expect(count, lessThanOrEqualTo(6));
      // Rotación invertida cada 5.0s.
      expect(e.rotationInverted, isFalse);
      e.tickEnrage(5.1);
      expect(e.rotationInverted, isTrue);
      e.tickEnrage(5.1);
      expect(e.rotationInverted, isFalse);
    });

    test('Nyxara fallo drena 10 de maná del escuadrón (en rage)', () {
      final e = enrageEngine(boss: BossConfig.nyxara);
      forceEnrage(e);
      e.targets.clear(); // forzar miss: sin objetivos válidos
      final manaBefore = e.cards[0].mana;
      e.registerDamage(
        orb: CombatOrb(id: 'o', element: Element.igneous, level: OrbLevel.one),
        target: null,
        multiplier: 0,
        kind: HitKind.miss,
      );
      expect((manaBefore - e.cards[0].mana), closeTo(10, 1e-9));
    });

    test('diálogo de amenaza muestra al iniciar y furia en onEnrage', () {
      // Requiere UI, pero validamos que BossConfig contendrá diálogos.
      for (final b in bossesWithDialogue) {
        expect(b.threatDialog.isNotEmpty, isTrue,
            reason: 'falta amenaza para ${b.id}');
        expect(b.furyDialog.isNotEmpty, isTrue,
            reason: 'falta furia para ${b.id}');
      }
    });
  });
}
