import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Procedural audio engine that generates WAV PCM buffers in memory.
/// No external audio assets required - all sounds synthesized mathematically.
class ProceduralSfxEngine {
  // Audio constants
  static const int _sampleRate = 44100;
  static const int _bitsPerSample = 16;
  static const int _channels = 1;

  // Mute state (persisted in SQLite)
  static bool _muted = false;

  // Volúmenes y hápticas (ajustables desde SettingsModal).
  static double _sfxVolume = 0.8;
  static double _ambientVolume = 0.4;
  static bool _hapticsEnabled = true;

  /// Toggle mute state.
  static void setMuted(bool muted) {
    _muted = muted;
  }

  /// Current mute state.
  static bool get isMuted => _muted;

  /// Volumen de efectos (0.0 - 1.0).
  static double get sfxVolume => _sfxVolume;

  /// Volumen del ambiente (0.0 - 1.0).
  static double get ambientVolume => _ambientVolume;

  /// Si las respuestas hápticas están activas.
  static bool get hapticsEnabled => _hapticsEnabled;

  static void setSfxVolume(double value) {
    _sfxVolume = value.clamp(0.0, 1.0).toDouble();
  }

  static void setAmbientVolume(double value) {
    _ambientVolume = value.clamp(0.0, 1.0).toDouble();
  }

  static void setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
  }

  /// Restaura los ajustes desde valores persistidos (0-100 en SQLite).
  static void restoreSettings({
    required int sfxVolume,
    required int ambientVolume,
    required bool hapticsEnabled,
  }) {
    setSfxVolume(sfxVolume / 100.0);
    setAmbientVolume(ambientVolume / 100.0);
    setHapticsEnabled(hapticsEnabled);
  }

  /// Volumen efectivo de un efecto concreto.
  static double get effectiveSfxVolume =>
      _muted ? 0.0 : _sfxVolume.clamp(0.0, 1.0);

  /// Volumen efectivo del ambiente.
  static double get effectiveAmbientVolume =>
      _muted ? 0.0 : _ambientVolume.clamp(0.0, 1.0);

  /// Buffer del drone del Santuario (ambiente oscuro en loop).
  static Uint8List sanctuaryDroneBuffer() => cached('drone');

  /// Buffer del pulso del jefe (ambiente de combate).
  static Uint8List bossPulseBuffer() => cached('boss_pulse');

  /// Play orb spawn: short ascending crystalline tone (440Hz -> 660Hz, 60ms).
  static void playOrbSpawn() {
    _play(cached('orb_spawn'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.selectionClick);
  }

  /// Play orb merge: resonant harmonic chord, base frequency rises by level (Lv2/Lv3, 140ms) + haptic.
  static void playOrbMerge(int newLevel) {
    _play(cached('orb_merge_${newLevel <= 2 ? 2 : 3}'));
    if (!_muted && _sfxVolume > 0) SystemSound.play(SystemSoundType.click);
    if (newLevel >= 2 && _hapticsEnabled) HapticFeedback.mediumImpact();
  }

  /// Play orb flick: whoosh frequency sweep (220Hz -> 880Hz, 110ms) + haptic selection click.
  static void playOrbFlick() {
    _play(cached('orb_flick'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.selectionClick);
  }

  /// Play normal hit: percussive impact (90Hz exponential decay).
  static void playHitNormal() {
    _play(cached('hit_normal'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.lightImpact);
  }

  /// Play bullseye: double metallic bell (880Hz + 1320Hz, 220ms) + heavy haptic.
  static void playHitBullseye() {
    _play(cached('hit_bullseye'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.heavyImpact);
  }

  /// Play graze: very short soft click.
  static void playHitGraze() {
    _play(cached('hit_graze'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.selectionClick);
  }

  /// Play elemental reaction: sub-bass explosion (55Hz) + arcane ring modulation (350ms) + intense vibration.
  static void playElementalReaction() {
    _play(cached('elemental_reaction'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.heavyImpact);
  }

  /// Play card skill invoke: gothic 3-note ascending fanfare (300ms).
  static void playCardSkillInvoke() {
    _play(cached('card_skill_invoke'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.mediumImpact);
  }

  /// Play counter-flick destroy: sharp metallic clang (1200Hz, 90ms).
  static void playCounterFlickDestroy() {
    _play(cached('counter_flick_destroy'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.heavyImpact);
  }

  /// Play summon reveal: mystical arpeggio sequence, more epic with more stars.
  static void playSummonReveal(int stars) {
    _play(cached('summon_reveal_${stars.clamp(1, 5)}'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.mediumImpact);
  }

  /// Play boss enrage: deep ominous rumble + alarm.
  static void playBossEnrage() {
    _play(cached('boss_enrage'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.heavyImpact);
  }

  /// Play chest open: magical chime with gold coin sound.
  static void playChestOpen() {
    _play(cached('evolution_success')); // Reuse evolution success sound for now
    _nativeFeedback(SystemSoundType.click, HapticFeedback.mediumImpact);
  }

  /// Play level up: ascending fanfare.
  static void playLevelUp() {
    _play(cached('card_skill_invoke'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.mediumImpact);
  }

  /// Play altar evolution success: ascending celestial choir chord.
  static void playEvolutionSuccess() {
    _play(cached('evolution_success'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.mediumImpact);
  }

  /// Play altar evolution fail: dissonant descending tone.
  static void playEvolutionFail() {
    _play(cached('evolution_fail'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.lightImpact);
  }

  /// Play a heavy UI click sound.
  static void playUIHeavyClick() {
    _play(cached('ui_heavy_click'));
    _nativeFeedback(SystemSoundType.click, HapticFeedback.heavyImpact);
  }

  // --- Internal synthesis methods ---

  /// Generate a WAV file in memory (Uint8List) from PCM samples.
  static Uint8List _encodeWav(List<double> samples) {
    final int dataSize = samples.length * 2; // 16-bit = 2 bytes
    final int riffSize = 36 + dataSize; // total file size minus 8 (RIFF header)
    final int fileSize = 44 + dataSize; // total file size

    final buffer = ByteData(fileSize);
    var offset = 0;

    // RIFF header
    buffer.setUint8(offset++, 0x52); // 'R'
    buffer.setUint8(offset++, 0x49); // 'I'
    buffer.setUint8(offset++, 0x46); // 'F'
    buffer.setUint8(offset++, 0x46); // 'F'
    buffer.setUint32(offset, riffSize, Endian.little); // file size - 8
    offset += 4;
    buffer.setUint8(offset++, 0x57); // 'W'
    buffer.setUint8(offset++, 0x41); // 'A'
    buffer.setUint8(offset++, 0x56); // 'V'
    buffer.setUint8(offset++, 0x45); // 'E'

    // fmt chunk
    buffer.setUint8(offset++, 0x66); // 'f'
    buffer.setUint8(offset++, 0x6D); // 'm'
    buffer.setUint8(offset++, 0x74); // 't'
    buffer.setUint8(offset++, 0x20); // ' '
    buffer.setUint32(offset, 16, Endian.little); // chunk size
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM format
    offset += 2;
    buffer.setUint16(offset, _channels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, _sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(
      offset,
      _sampleRate * _channels * 2,
      Endian.little,
    ); // byte rate
    offset += 4;
    buffer.setUint16(offset, _channels * 2, Endian.little); // block align
    offset += 2;
    buffer.setUint16(offset, _bitsPerSample, Endian.little);
    offset += 2;

    // data chunk
    buffer.setUint8(offset++, 0x64); // 'd'
    buffer.setUint8(offset++, 0x61); // 'a'
    buffer.setUint8(offset++, 0x74); // 't'
    buffer.setUint8(offset++, 0x61); // 'a'
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // PCM data (16-bit signed)
    for (final sample in samples) {
      final int clamped = (sample.clamp(-1.0, 1.0) * 32767).round();
      buffer.setInt16(offset, clamped, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  /// Caché estático de WAV: cada sonido se sintetiza una sola vez por proceso
  /// y a partir de ahí se reutiliza exactamente el mismo [Uint8List], sin
  /// volver a alojar buffers PCM en RAM.
  static final Map<String, Uint8List> _wavCache = <String, Uint8List>{};

  /// Sonidos que se pre-sintetizan en el arranque del menú.
  static const List<String> prewarmNames = <String>[
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
    'boss_enrage',
    'evolution_success',
    'evolution_fail',
    'drone',
    'boss_pulse',
  ];

  /// Cantidad de buffers actualmente residentes en el caché.
  static int get cachedBufferCount => _wavCache.length;

  /// `true` si [name] ya está sintetizado en memoria.
  static bool isCached(String name) => _wavCache.containsKey(name);

  /// Sintetiza de golpe los sonidos de uso frecuente (menú / inicio de run).
  static void prewarmCache() {
    for (final name in prewarmNames) {
      cached(name);
    }
    for (var stars = 1; stars <= 5; stars++) {
      cached('summon_reveal_$stars');
    }
  }

  /// Libera los buffers retenidos (tests / cambio de escena).
  static void clearCache() => _wavCache.clear();

  /// Get the synthesized WAV buffer for [name] (used by tests and audio
  /// playback backends). Names: orb_spawn, orb_merge_2, orb_merge_3,
  /// orb_flick, hit_normal, hit_bullseye, hit_graze, elemental_reaction,
  /// card_skill_invoke, counter_flick_destroy, summon_reveal_N,
  /// boss_enrage, evolution_success, evolution_fail, drone, boss_pulse.
  static Uint8List bufferFor(String name) => cached(name);

  /// Igual que [bufferFor] pero memorizando el resultado: la segunda llamada
  /// devuelve la **misma instancia** (`identical(buf1, buf2)`).
  static Uint8List cached(String name) => _wavCache[name] ??= _generate(name);

  static Uint8List _generate(String name) {
    return switch (name) {
      'orb_spawn' => _orbSpawn(),
      'orb_merge_2' => _orbMerge(2),
      'orb_merge_3' => _orbMerge(3),
      'orb_flick' => _orbFlick(),
      'hit_normal' => _hitNormal(),
      'hit_bullseye' => _hitBullseye(),
      'hit_graze' => _hitGraze(),
      'elemental_reaction' => _elementalReaction(),
      'card_skill_invoke' => _cardSkillInvoke(),
      'counter_flick_destroy' => _counterFlickDestroy(),
      'boss_enrage' => _bossEnrage(),
      'evolution_success' => _evolutionSuccess(),
      'evolution_fail' => _evolutionFail(),
      'drone' => generateSanctuaryDroneWav(),
      'boss_pulse' => generateBossPulseWav(),
      _ when name.startsWith('summon_reveal_') => _summonReveal(
          int.tryParse(name.substring('summon_reveal_'.length)) ?? 1,
        ),
      _ => throw ArgumentError('unknown sound: $name'),
    };
  }

  /// Play a cached or generated sound.
  static void _play(Uint8List wavData) {
    if (_muted || _sfxVolume <= 0) return;
    // In a real implementation, this would use audioplayers or just_audio
    // For now we just ensure the buffer is valid.
    // The actual playback would be triggered via a platform channel or audio plugin.
    // This is a placeholder - in production you'd use:
    // await AudioPlayer().play(BytesSource(wavData));
  }

  // --- Sound generators ---

  /// Orb spawn: 440Hz -> 660Hz ascending sine, 60ms, with quick ADSR.
  static Uint8List _orbSpawn() {
    const duration = 0.06; // 60ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = t / duration;
      // Exponential frequency sweep 440 -> 660
      final freq = 440 * math.exp(progress * math.log(660 / 440));
      final phase = 2 * math.pi * freq * t;
      // ADSR: quick attack, short decay, no sustain, quick release
      final env = _adsrEnvelope(progress, 0.05, 0.3, 0.0, 0.65);
      result[i] = math.sin(phase) * env * 0.4;
    }
    return _encodeWav(result);
  }

  /// Orb merge: harmonic chord based on level. Lv2 = major triad, Lv3 = 7th chord.
  static Uint8List _orbMerge(int level) {
    const duration = 0.14; // 140ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    // Base frequency rises with level index (0=one, 1=two, 2=three).
    final baseFreq = switch (level) {
      1 => 220.0, // A3 (level 2)
      2 => 330.0, // E4 (level 3)
      _ => 220.0,
    };

    // Chord intervals
    final intervals = level >= 3
        ? [1.0, 1.25, 1.5, 1.75] // Major 7th
        : [1.0, 1.25, 1.5]; // Major triad

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = t / duration;
      double sum = 0;
      for (final interval in intervals) {
        final freq = baseFreq * interval;
        final phase = 2 * math.pi * freq * t;
        sum += math.sin(phase);
      }
      final env = _adsrEnvelope(progress, 0.02, 0.4, 0.1, 0.48);
      result[i] = (sum / intervals.length) * env * 0.35;
    }
    return _encodeWav(result);
  }

  /// Orb flick: whoosh sweep 220Hz -> 880Hz, 110ms, filtered noise + sine.
  static Uint8List _orbFlick() {
    const duration = 0.11; // 110ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);
    final random = math.Random(42);

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = t / duration;
      // Exponential sweep
      final freq = 220 * math.exp(progress * math.log(880 / 220));
      final phase = 2 * math.pi * freq * t;
      // Mix sine with filtered noise for "whoosh"
      final sine = math.sin(phase) * 0.6;
      final noise = (random.nextDouble() * 2 - 1) * 0.4;
      // Low-pass the noise (simple one-pole)
      final noiseFiltered = noise * (1 - progress);
      final env = _adsrEnvelope(progress, 0.01, 0.5, 0.0, 0.49);
      result[i] = (sine + noiseFiltered) * env * 0.4;
    }
    return _encodeWav(result);
  }

  /// Normal hit: percussive 90Hz exponential decay.
  static Uint8List _hitNormal() {
    const duration = 0.12; // 120ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = t / duration;
      final freq = 90.0;
      final phase = 2 * math.pi * freq * t;
      // Exponential decay envelope
      final env = math.exp(-progress * 8.0) * (1 - progress);
      result[i] = math.sin(phase) * env * 0.5;
    }
    return _encodeWav(result);
  }

  /// Bullseye: double metallic bell 880Hz + 1320Hz, 220ms.
  static Uint8List _hitBullseye() {
    const duration = 0.22; // 220ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = t / duration;
      final f1 = 880.0;
      final f2 = 1320.0;
      final phase1 = 2 * math.pi * f1 * t;
      final phase2 = 2 * math.pi * f2 * t;
      // Metallic timbre: add odd harmonics
      final s1 = math.sin(phase1) +
          0.3 * math.sin(3 * phase1) +
          0.15 * math.sin(5 * phase1);
      final s2 = math.sin(phase2) +
          0.3 * math.sin(3 * phase2) +
          0.15 * math.sin(5 * phase2);
      // Bell decay: double exponential
      final env =
          math.exp(-progress * 6.0) * 0.7 + math.exp(-progress * 20.0) * 0.3;
      result[i] = (s1 + s2) * 0.5 * env * 0.35;
    }
    return _encodeWav(result);
  }

  /// Graze: very short soft click.
  static Uint8List _hitGraze() {
    const duration = 0.04; // 40ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = t / duration;
      final env = math.exp(-progress * 15.0);
      result[i] = math.sin(2 * math.pi * 400 * t) * env * 0.2;
    }
    return _encodeWav(result);
  }

  /// Elemental reaction: sub-bass 55Hz + ring modulation 350ms.
  static Uint8List _elementalReaction() {
    const duration = 0.35; // 350ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = t / duration;
      // Sub-bass fundamental
      final sub = math.sin(2 * math.pi * 55 * t);
      // Ring modulation: 55Hz * 350Hz creates sum/difference tones
      final ring =
          math.sin(2 * math.pi * 350 * t) * math.sin(2 * math.pi * 55 * t);
      // Add some noise for "explosion" texture
      final noise =
          (math.sin(t * 12345.67) * 0.5 + math.sin(t * 23456.78) * 0.5) *
              (1 - progress);
      // Envelope: fast attack, slow decay
      final env = math.exp(-progress * 4.0);
      result[i] = (sub * 0.6 + ring * 0.3 + noise * 0.1) * env * 0.5;
    }
    return _encodeWav(result);
  }

  /// Card skill invoke: 3-note ascending gothic fanfare (300ms).
  static Uint8List _cardSkillInvoke() {
    const duration = 0.3; // 300ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    // Notes: C4 (261.63) -> E4 (329.63) -> G4 (392.00)
    final notes = [261.63, 329.63, 392.00];
    final noteDuration = duration / notes.length;

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final noteIndex = (t / noteDuration).floor().clamp(0, notes.length - 1);
      final freq = notes[noteIndex];
      final localProgress = (t - noteIndex * noteDuration) / noteDuration;
      final phase = 2 * math.pi * freq * t;
      // Rich harmonic content for "gothic" feel
      final s = math.sin(phase) +
          0.4 * math.sin(2 * phase) +
          0.2 * math.sin(3 * phase) +
          0.1 * math.sin(4 * phase);
      // Per-note envelope with quick attack
      final env = math.exp(-localProgress * 5.0) * 0.8 +
          math.exp(-localProgress * 20.0) * 0.2;
      result[i] = s * env * 0.25;
    }
    return _encodeWav(result);
  }

  /// Counter-flick: sharp metallic clang 1200Hz, 90ms.
  static Uint8List _counterFlickDestroy() {
    const duration = 0.09; // 90ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = t / duration;
      final freq = 1200.0;
      final phase = 2 * math.pi * freq * t;
      // Inharmonic partials for metallic clang
      final s = math.sin(phase) +
          0.5 * math.sin(phase * 1.4) +
          0.3 * math.sin(phase * 1.9) +
          0.2 * math.sin(phase * 2.5);
      // Very fast decay
      final env = math.exp(-progress * 18.0);
      result[i] = s * env * 0.4;
    }
    return _encodeWav(result);
  }

  /// Summon reveal: mystical arpeggio, complexity scales with stars.
  static Uint8List _summonReveal(int stars) {
    const duration = 0.8; // 800ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    // More stars = more notes, wider range, more harmonics
    final noteCount = 4 + stars; // 5 to 9 notes
    final baseFreq = 220.0; // A3
    // Generate a mystical scale (minor pentatonic + tritone)
    final intervals = [1.0, 1.2, 1.333, 1.5, 1.6, 1.8, 2.0]; // Minor-ish
    final notes = <double>[];
    for (int i = 0; i < noteCount; i++) {
      notes.add(
        baseFreq *
            intervals[i % intervals.length] *
            math.pow(2, (i / intervals.length).floor()),
      );
    }

    final noteDuration = duration / notes.length;

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = t / duration;
      final noteIndex = (t / noteDuration).floor().clamp(0, notes.length - 1);
      final freq = notes[noteIndex];
      final localProgress = (t - noteIndex * noteDuration) / noteDuration;
      final phase = 2 * math.pi * freq * t;
      // Ethereal timbre: fundamental + soft harmonics
      final s = math.sin(phase) +
          0.3 * math.sin(2 * phase) +
          0.15 * math.sin(3 * phase) +
          0.08 * math.sin(4 * phase);
      // Add subtle shimmer (amplitude modulation)
      final shimmer = 1 + 0.1 * math.sin(2 * math.pi * 6 * t);
      // Per-note envelope with overlapping tails
      final env = math.exp(-localProgress * 3.0) * 0.7 +
          math.exp(-localProgress * 12.0) * 0.3;
      // Overall envelope
      final overallEnv = 1 - progress * 0.3;
      result[i] = s * env * shimmer * overallEnv * 0.18;
    }
    return _encodeWav(result);
  }

  /// Boss enrage: deep ominous rumble + alarm.
  static Uint8List _bossEnrage() {
    const duration = 0.5; // 500ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = t / duration;
      // Deep rumble
      final rumble = math.sin(2 * math.pi * 40 * t) * 0.5 +
          math.sin(2 * math.pi * 60 * t) * 0.3;
      // Rising alarm
      final alarmFreq = 440 + progress * 440;
      final alarm = math.sin(2 * math.pi * alarmFreq * t);
      // Noise burst
      final noise = math.sin(t * 12345.67) * 0.2 * (1 - progress);
      final env = math.exp(-progress * 3.0);
      result[i] = (rumble + alarm * 0.4 + noise) * env * 0.5;
    }
    return _encodeWav(result);
  }

  /// Evolution success: ascending celestial chord.
  static Uint8List _evolutionSuccess() {
    const duration = 0.6; // 600ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    // Major 9th chord: C E G B D
    final notes = [261.63, 329.63, 392.00, 493.88, 587.33];

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = t / duration;
      double sum = 0;
      for (final freq in notes) {
        sum += math.sin(2 * math.pi * freq * t) / notes.length;
      }
      // Slow attack, long sustain, gentle release
      final env = (1 - math.exp(-progress * 8.0)) * math.exp(-progress * 1.5);
      // Add shimmer
      final shimmer = 1 + 0.15 * math.sin(2 * math.pi * 5 * t);
      result[i] = sum * env * shimmer * 0.25;
    }
    return _encodeWav(result);
  }

  /// Evolution fail: dissonant descending tone.
  static Uint8List _evolutionFail() {
    const duration = 0.4; // 400ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = t / duration;
      // Tritone descent (the "devil's interval")
      final freq = 440 * math.exp(-progress * math.log(2.0)) * 0.75;
      final phase = 2 * math.pi * freq * t;
      final s = math.sin(phase) + 0.5 * math.sin(phase * 1.414); // tritone
      final env = math.exp(-progress * 4.0);
      result[i] = s * env * 0.35;
    }
    return _encodeWav(result);
  }

  /// Generate WAV buffer for ambient drone sound (long loop, low frequency).
  static Uint8List generateSanctuaryDroneWav() {
    const duration = 4.0; // 4 seconds loop
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      // Slow, deep, evolving sine wave (40Hz base, with slow modulation)
      final freq = 40.0 + 5.0 * math.sin(t * 0.2);
      final phase = 2 * math.pi * freq * t;
      // Slow, evolving envelope
      final env = 0.5 + 0.3 * math.sin(t * 0.5);
      result[i] = math.sin(phase) * env * 0.1;
    }
    return _encodeWav(result);
  }

  /// Generate WAV buffer for boss pulse (short, rhythmic, mid-low frequency).
  static Uint8List generateBossPulseWav() {
    const duration = 0.3; // 300ms
    final samples = (_sampleRate * duration).round();
    final result = List<double>.filled(samples, 0.0);

    for (int i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      // Rhythmic pulse: 80Hz to 150Hz sweeping
      final freq = 80.0 + (150.0 - 80.0) * (1 - math.sin(t * 5.0) / 2);
      final phase = 2 * math.pi * freq * t;
      // Short, sharp envelope
      final env = math.exp(-t * 10.0);
      result[i] = math.sin(phase) * env * 0.3;
    }
    return _encodeWav(result);
  }

  /// ADSR envelope helper.
  static double _adsrEnvelope(
    double progress,
    double attack,
    double decay,
    double sustain,
    double release,
  ) {
    if (progress < attack) {
      return progress / attack;
    }
    progress -= attack;
    if (progress < decay) {
      return 1.0 - (1.0 - sustain) * (progress / decay);
    }
    progress -= decay;
    if (progress < 1.0 - attack - decay - release) {
      return sustain;
    }
    progress -= (1.0 - attack - decay - release);
    return sustain * (1.0 - progress / release);
  }

  // --- Haptic feedback helpers ---

  /// Emite respuesta auditiva y táctil nativa inmediata si el audio no está silenciado.
  static void _nativeFeedback(SystemSoundType sound, VoidCallback haptic) {
    if (!_muted && _sfxVolume > 0) {
      SystemSound.play(sound);
    }
    if (_hapticsEnabled) {
      haptic();
    }
  }
}
