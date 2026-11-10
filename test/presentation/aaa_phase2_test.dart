import 'dart:io';

import 'package:brimstone_summoning/core/audio/procedural_sfx_engine.dart';
import 'package:brimstone_summoning/core/audio/wav_player.dart';
import 'package:brimstone_summoning/domain/entities/owned_card.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/rarity.dart';
import 'package:brimstone_summoning/presentation/graphics/elemental_vfx.dart';
import 'package:brimstone_summoning/presentation/graphics/rift_effect.dart';
import 'package:brimstone_summoning/presentation/screens/summon/summon_portal_screen.dart';
import 'package:brimstone_summoning/presentation/screens/title/title_splash_screen.dart';
import 'package:brimstone_summoning/presentation/widgets/gothic_modal_frame.dart';
import 'package:brimstone_summoning/presentation/widgets/tcg_card_widget.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';

OwnedCard _card({int stars = 3}) => OwnedCard(
      instanceId: 900 + stars,
      catalogId: 'ignis_hound',
      name: 'Sabueso de Azufre',
      element: Element.igneous,
      rarity: Rarity.legendary,
      baseManaCost: 100,
      baseAttack: 12,
      baseHealth: 40,
      level: 3,
      stars: stars,
      skillLevel: 2,
      masteryXp: 120,
    );

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('Shaders GLSL — impellerc contract', () {
    const shaders = <String>[
      'shaders/abyssal_rift.frag',
      'shaders/foil_card.frag',
      'shaders/shockwave_break.frag',
      'shaders/orb_plasma.frag',
    ];

    test('los cuatro programas existen y son GLSL ES para Flutter', () {
      for (final path in shaders) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path missing');
        final src = file.readAsStringSync();
        expect(src, contains('#version 460 core'), reason: path);
        expect(src, contains('#include <flutter/runtime_effect.glsl>'),
            reason: path);
        expect(src, contains('FlutterFragCoord()'), reason: path);
        expect(src, contains('out vec4 fragColor;'), reason: path);
      }
    });

    test('ningún uniform usa bool/int (solo float y vectores)', () {
      final uniform = RegExp(r'uniform\s+(\w+)');
      for (final path in shaders) {
        final src = File(path).readAsStringSync();
        for (final match in uniform.allMatches(src)) {
          final type = match.group(1)!;
          expect(
            <String>['float', 'vec2', 'vec3', 'vec4'].contains(type),
            isTrue,
            reason: '$path declares unsupported uniform type $type',
          );
        }
      }
    });

    test('los cuatro shaders están declarados en pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final path in shaders) {
        expect(pubspec, contains(path), reason: '$path not bundled');
      }
    });

    test('BrimstoneShaders expone las rutas nuevas', () {
      expect(BrimstoneShaders.shockwaveAsset, 'shaders/shockwave_break.frag');
      expect(BrimstoneShaders.plasmaAsset, 'shaders/orb_plasma.frag');
    });

    test('sin warm-up en tests los getters no lanzan ni mienten', () {
      expect(() => BrimstoneShaders.newShockwaveShader(), returnsNormally);
      expect(() => BrimstoneShaders.newPlasmaShader(), returnsNormally);
    });
  });

  group('Puente de audio WAV', () {
    test('en la VM usa el backend silencioso y no rompe', () {
      final wav = ProceduralSfxEngine.bufferFor('hit_normal');
      expect(WavPlayback.supported, isFalse);
      expect(WavPlayback.supportsLoops, isFalse);
      expect(() => WavPlayback.unlock(), returnsNormally);
      expect(() => WavPlayback.play('hit_normal', wav), returnsNormally);
      expect(() => WavPlayback.loop('drone', wav), returnsNormally);
      expect(() => WavPlayback.stopLoop('drone'), returnsNormally);
      expect(() => WavPlayback.stopAll(), returnsNormally);
    });

    test('el ambiente se conmuta de forma idempotente', () {
      ProceduralSfxEngine.setMuted(false);
      ProceduralSfxEngine.startAmbient('drone');
      expect(ProceduralSfxEngine.currentAmbient, 'drone');
      ProceduralSfxEngine.startAmbient('drone');
      expect(ProceduralSfxEngine.currentAmbient, 'drone');
      ProceduralSfxEngine.startAmbient('boss_pulse');
      expect(ProceduralSfxEngine.currentAmbient, 'boss_pulse');
      ProceduralSfxEngine.stopAmbient();
      expect(ProceduralSfxEngine.currentAmbient, isNull);
      expect(() => ProceduralSfxEngine.refreshAmbientVolume(), returnsNormally);
    });

    test('los nuevos efectos son WAV válidos', () {
      for (final name in <String>[
        'hit_shield_break',
        'title_open',
        'ui_heavy_click',
      ]) {
        final wav = ProceduralSfxEngine.bufferFor(name);
        expect(wav.length, greaterThan(44), reason: name);
        expect(wav[0], 0x52, reason: name);
        expect(wav[8], 0x57, reason: name);
        expect(wav.length % 2, 0, reason: name);
      }
      expect(() => ProceduralSfxEngine.playShieldBreak(), returnsNormally);
      expect(() => ProceduralSfxEngine.playTitleOpen(), returnsNormally);
    });

    test('el ambiente de combate es un loop más corto que el Santuario', () {
      final drone = ProceduralSfxEngine.generateSanctuaryDroneWav();
      final drums = ProceduralSfxEngine.generateBossPulseWav();
      expect(drone.length, greaterThan(drums.length));
      // Ritual loop: 96 BPM × 4 beats = 2.5 s.
      expect(drums.length, closeTo(44100 * 2.5 * 2 + 44, 4096));
    });
  });

  group('VFX elementales', () {
    testWidgets('PlasmaOrb pinta sin excepción', (tester) async {
      await tester.pumpWidget(
        _host(const SizedBox(
          width: 64,
          height: 64,
          child: PlasmaOrb(color: Color(0xFFFF5A26)),
        )),
      );
      expect(find.byType(PlasmaOrb), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('BreakShockwave se dispara con el token', (tester) async {
      await tester.pumpWidget(_host(
        const SizedBox(
          width: 300,
          height: 300,
          child: BreakShockwave(token: 0),
        ),
      ));
      await tester.pumpWidget(_host(
        const SizedBox(
          width: 300,
          height: 300,
          child: BreakShockwave(token: 1),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('cada elemento tiene su barrido de impacto', (tester) async {
      for (final element in Element.values) {
        await tester.pumpWidget(_host(
          SizedBox(
            width: 320,
            height: 320,
            child: ElementalBarrage(token: 0, element: element),
          ),
        ));
        await tester.pumpWidget(_host(
          SizedBox(
            width: 320,
            height: 320,
            child: ElementalBarrage(token: 1, element: element),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull, reason: element.name);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('BossShatter muestra el banner de sello purificado',
        (tester) async {
      await tester.pumpWidget(_host(
        const SizedBox(
          width: 320,
          height: 240,
          child: BossShatterOverlay(
            token: 1,
            portraitId: 'boss_pyroth',
            element: Element.igneous,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('¡SELLO PURIFICADO!'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('Ceremonia gacha 3D', () {
    testWidgets('carta boca abajo muestra su reverso rúnico', (tester) async {
      await tester.pumpWidget(_host(
        GachaFlipCard(card: _card(stars: 3), revealed: false, onTap: () {}),
      ));
      expect(find.text('ÉPICA'), findsOneWidget);
      expect(find.byType(TcgCardWidget), findsNothing);
    });

    testWidgets('al revelar aparece la carta real', (tester) async {
      await tester.pumpWidget(_host(
        GachaFlipCard(card: _card(stars: 3), revealed: true, onTap: () {}),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(TcgCardWidget), findsOneWidget);
    });

    testWidgets('la rareza tiñe el reverso', (tester) async {
      for (final entry in <int, String>{
        2: 'RARA',
        3: 'ÉPICA',
        4: 'LEGENDARIA',
      }.entries) {
        await tester.pumpWidget(_host(
          GachaFlipCard(
              card: _card(stars: entry.key), revealed: false, onTap: () {}),
        ));
        expect(find.text(entry.value), findsOneWidget);
      }
    });
  });

  group('Pantalla de título', () {
    testWidgets('el gate con skipSplash entrega el hijo directo',
        (tester) async {
      await tester.pumpWidget(_host(
        const TitleGate(
          skipSplash: true,
          child: Text('SANTUARIO'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('SANTUARIO'), findsOneWidget);
    });

    testWidgets('el sello responde al toque', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_host(
        TitleSplashScreen(onUnseal: () => tapped++),
      ));
      expect(find.text('BRIMSTONE'), findsOneWidget);
      expect(find.text('CRÓNICAS DEL SELLO ROTO'), findsOneWidget);
      await tester.tap(find.text('TOCAR PARA DESELLAR LA GRIETA'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });
  });

  group('Marco gótico de modales', () {
    testWidgets('GothicModalFrame rotula y pinta metálico', (tester) async {
      await tester.pumpWidget(_host(
        const GothicModalFrame(
          title: 'PACTO MENOR',
          subtitle: 'SELLO',
          icon: Icons.local_fire_department,
          actions: [Text('CONTINUAR')],
          children: [
            MetallicProgressBar(value: 0.5, label: 'PROGRESO'),
            GothicSectionTitle(text: 'Recompensas'),
          ],
        ),
      ));
      expect(find.text('PACTO MENOR'), findsOneWidget);
      expect(find.text('PROGRESO'), findsOneWidget);
      expect(find.text('RECOMPENSAS'), findsOneWidget);
      expect(find.text('CONTINUAR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
