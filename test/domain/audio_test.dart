import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:brimstone_summoning/core/audio/procedural_sfx_engine.dart';

void main() {
  group('ProceduralSfxEngine — WAV PCM synthesis', () {
    test('generates valid WAV header: RIFF / WAVE / fmt / data', () {
      ProceduralSfxEngine.setMuted(false);
      final wav = ProceduralSfxEngine.bufferFor('orb_spawn');
      final bytes = Uint8List.fromList(wav);

      // RIFF magic
      expect(bytes[0], 0x52); // 'R'
      expect(bytes[1], 0x49); // 'I'
      expect(bytes[2], 0x46); // 'F'
      expect(bytes[3], 0x46); // 'F'
      // WAVE magic
      expect(bytes[8], 0x57); // 'W'
      expect(bytes[9], 0x41); // 'A'
      expect(bytes[10], 0x56); // 'V'
      expect(bytes[11], 0x45); // 'E'
      // fmt chunk
      expect(bytes[12], 0x66); // 'f'
      expect(bytes[13], 0x6D); // 'm'
      expect(bytes[14], 0x74); // 't'
      expect(bytes[15], 0x20); // ' '
      // PCM format tag = 1
      expect(bytes[20], 1);
      expect(bytes[21], 0);
      // channels = 1 (mono)
      expect(bytes[22], 1);
      expect(bytes[23], 0);
      // sample rate = 44100
      expect(bytes[24], 44100 & 0xFF);
      expect(bytes[25], (44100 >> 8) & 0xFF);
      // data chunk header starts at offset 36 (12 RIFF + 24 fmt)
      expect(bytes[36], 0x64); // 'd'
      expect(bytes[37], 0x61); // 'a'
      expect(bytes[38], 0x74); // 't'
      expect(bytes[39], 0x61); // 'a'
    });

    test('all sound buffers produce valid WAV headers', () {
      ProceduralSfxEngine.setMuted(false);
      final names = <String>[
        'orb_spawn',
        'orb_merge_2',
        'orb_merge_3',
        'orb_flick',
        'hit_normal',
        'hit_bullseye',
        'hit_graze',
        'elemental_reaction',
        'card_skill_invoke',
        'counter_flick_destroy',
        'summon_reveal_1',
        'summon_reveal_4',
        'boss_enrage',
        'evolution_success',
        'evolution_fail',
      ];
      for (final name in names) {
        final bytes = Uint8List.fromList(ProceduralSfxEngine.bufferFor(name));
        expect(bytes[0], 0x52, reason: '$name missing RIFF');
        expect(bytes[1], 0x49, reason: '$name missing RIFF');
        expect(bytes[2], 0x46, reason: '$name missing RIFF');
        expect(bytes[3], 0x46, reason: '$name missing RIFF');
        expect(bytes[8], 0x57, reason: '$name missing WAVE');
        expect(bytes[9], 0x41, reason: '$name missing WAVE');
        expect(bytes[10], 0x56, reason: '$name missing WAVE');
        expect(bytes[11], 0x45, reason: '$name missing WAVE');
        expect(bytes.length, greaterThan(36), reason: '$name too short');
        expect(bytes.length % 2, equals(0), reason: '$name odd length');
      }
    });

    test('summon reveal buffers are valid WAV for all star counts', () {
      ProceduralSfxEngine.setMuted(false);
      for (final stars in [1, 2, 3, 4]) {
        final bytes = Uint8List.fromList(
          ProceduralSfxEngine.bufferFor('summon_reveal_$stars'),
        );
        expect(bytes[0], 0x52, reason: 'summon_reveal_$stars missing RIFF');
        expect(bytes[8], 0x57, reason: 'summon_reveal_$stars missing WAVE');
        expect(bytes.length, greaterThan(44));
      }
    });

    test('mute toggles playback state', () {
      ProceduralSfxEngine.setMuted(true);
      expect(ProceduralSfxEngine.isMuted, isTrue);
      ProceduralSfxEngine.setMuted(false);
      expect(ProceduralSfxEngine.isMuted, isFalse);
    });
  });
}
