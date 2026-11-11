import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'wav_player.dart';

/// Compositor Musical Procedural de 5 pistas completas (Etapa III, Pilar 4).
///
/// Sintetiza algorítmicamente en PCM 16-bit pistas polifónicas de 16–24 s con
/// loop zero-crossing (melodía + arpegio + bajo + percusión) y las reproduce
/// vía [WavPlayback] (WebAudio en web, AudioTrack en Android). Cada pista se
/// genera una vez y se cachea de forma perezosa.
class ProceduralMusicComposer {
  const ProceduralMusicComposer._();

  // ------------------------------------------------------------ pistas

  /// Las 5 pistas del juego.
  static const List<MusicTrack> tracks = [
    MusicTrack(
      id: 'sanctuary_requiem',
      name: 'Sanctuary Requiem',
      rootHz: 110.0, // A2
      mode: ScaleMode.minor,
      tempoBpm: 68,
      seconds: 22,
      brightness: 0.55,
    ),
    MusicTrack(
      id: 'rift_march',
      name: 'Rift March',
      rootHz: 130.81, // C3
      mode: ScaleMode.dorian,
      tempoBpm: 112,
      seconds: 18,
      brightness: 0.75,
    ),
    MusicTrack(
      id: 'boss_confrontation',
      name: 'Boss Confrontation',
      rootHz: 98.0, // G2
      mode: ScaleMode.phrygian,
      tempoBpm: 138,
      seconds: 18,
      brightness: 0.85,
    ),
    MusicTrack(
      id: 'titan_apocalypse',
      name: 'Titan & Samael Apocalypse',
      rootHz: 87.31, // F2
      mode: ScaleMode.locrian,
      tempoBpm: 152,
      seconds: 20,
      brightness: 1.0,
    ),
    MusicTrack(
      id: 'portal_of_souls',
      name: 'Portal of Souls',
      rootHz: 123.47, // B2
      mode: ScaleMode.pentatonic,
      tempoBpm: 84,
      seconds: 24,
      brightness: 0.65,
    ),
  ];

  MusicTrack trackById(String id) =>
      tracks.firstWhere((t) => t.id == id, orElse: () => tracks.first);

  // ---------------------------------------------------------- cache

  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  /// PCM WAV de la pista (cache perezoso). Nada de I/O: pura síntesis.
  static Uint8List compose(String trackId) {
    final cached = _cache[trackId];
    if (cached != null) return cached;
    final track = const ProceduralMusicComposer._().trackById(trackId);
    final wav = _render(track);
    _cache[trackId] = wav;
    return wav;
  }

  /// Reproduce la pista en loop automático (si la plataforma soporta loops).
  static void play(String trackId, {double volume = 0.6}) {
    if (!WavPlayback.supported) return;
    WavPlayback.loop(trackId, compose(trackId), volume: volume);
  }

  /// Detiene la reproducción musical.
  static void stop(String trackId) => WavPlayback.stopLoop(trackId);

  // --------------------------------------------------------- síntesis

  static const int _sampleRate = 22050;

  static Uint8List _render(MusicTrack t) {
    final totalSamples = (t.seconds * _sampleRate).round();
    final mix = List<double>.filled(totalSamples, 0.0);
    final rand = math.Random(t.id.hashCode); // determinista por pista

    final beatSec = 60.0 / t.tempoBpm;
    final scale = _scaleSteps(t.mode);
    final beatCount = (t.seconds / beatSec).round();

    // Acordes (i - VI - III - VII en grados de la escala).
    const chordProgression = [0, 5, 2, 6];

    for (var beat = 0; beat < beatCount; beat++) {
      final t0 = beat * beatSec;
      final chordRoot = chordProgression[(beat ~/ 4) % 4];

      // ── BASS: nota fundamental por compás (saw suave) ──
      final bassHz = t.rootHz * _semitone(scale[chordRoot % scale.length]);
      _addTone(
        mix,
        t0,
        beatSec * 0.92,
        bassHz,
        amp: 0.34 * (1.0 + t.brightness * 0.3),
        timbre: _Timbre.saw,
      );

      // ── MELODÍA: frase de 2 compases determinista ──
      final melodyStep = scale[
          (chordRoot + ((beat * 5 + (beat ~/ 4) * 3) % 7)) % scale.length];
      final melodyHz =
          t.rootHz * 2.0 * _semitone(melodyStep); // una octava arriba
      if (beat % 2 == 0 || rand.nextDouble() < 0.35) {
        _addTone(
          mix,
          t0,
          beatSec * 1.6,
          melodyHz,
          amp: 0.22 * t.brightness,
          timbre: _Timbre.triangle,
          vibrato: 4.5,
        );
      }

      // ── ARPEGIO: corcheas sobre el acorde ──
      for (var sub = 0; sub < 2; sub++) {
        final arpStep = scale[(chordRoot + sub * 2) % scale.length];
        final arpHz = t.rootHz * 4.0 * _semitone(arpStep); // 2 octavas arriba
        _addTone(
          mix,
          t0 + sub * beatSec * 0.5,
          beatSec * 0.38,
          arpHz,
          amp: 0.10 * t.brightness,
          timbre: _Timbre.sine,
        );
      }

      // ── PERCUSIÓN: kick en 1 y 3, hat en cada corchea ──
      _addPercussion(
        mix,
        t0,
        beatSec,
        kick: beat % 2 == 0,
        hatIntensity: 0.35 + 0.3 * t.brightness,
      );
    }

    // Loop zero-crossing: funde los últimos 40ms con los primeros.
    const fade = _sampleRate ~/ 25;
    for (var i = 0; i < fade; i++) {
      final w = i / fade;
      mix[i] = mix[i] * w + mix[totalSamples - fade + i] * (1 - w);
    }

    // Normaliza a ~0.85 pico y codifica PCM16 WAV.
    var peak = 0.0;
    for (final v in mix) {
      final a = v.abs();
      if (a > peak) peak = a;
    }
    final gain = peak > 0 ? 0.85 / peak : 1.0;
    final pcm = Int8List(totalSamples * 2);
    for (var i = 0; i < totalSamples; i++) {
      final v = (mix[i] * gain).clamp(-1.0, 1.0);
      final s = (v * 32767).round();
      pcm[i * 2] = s & 0xff;
      pcm[i * 2 + 1] = (s >> 8) & 0xff;
    }
    return _encodeWav(pcm);
  }

  static void _addTone(
    List<double> mix,
    double startSec,
    double durationSec,
    double hz, {
    required double amp,
    required _Timbre timbre,
    double vibrato = 0.0,
  }) {
    final start = (startSec * _sampleRate).round();
    final len = (durationSec * _sampleRate).round();
    for (var i = 0; i < len; i++) {
      final idx = start + i;
      if (idx < 0 || idx >= mix.length) continue;
      final s = i / _sampleRate;
      final progress = i / math.max(1, len);
      // ADSR: ataque corto, decaimiento largo.
      final env = progress < 0.06
          ? progress / 0.06
          : math.pow(1.0 - (progress - 0.06) / 0.94, 1.6).toDouble();
      final vib =
          vibrato > 0 ? 1.0 + 0.006 * math.sin(2 * math.pi * vibrato * s) : 1.0;
      final phase = 2 * math.pi * hz * vib * s;
      final osc = switch (timbre) {
        _Timbre.sine => math.sin(phase),
        _Timbre.triangle => 2.0 / math.pi * math.asin(math.sin(phase)),
        _Timbre.saw =>
          2.0 * (hz * vib * s - (hz * vib * s + 0.5).floor()) - 1.0,
      };
      mix[idx] += osc * env * amp;
    }
  }

  static void _addPercussion(
    List<double> mix,
    double startSec,
    double beatSec, {
    required bool kick,
    required double hatIntensity,
  }) {
    // Kick: barrido 120->45Hz, 120ms.
    if (kick) {
      final start = (startSec * _sampleRate).round();
      final len = (_sampleRate * 0.12).round();
      for (var i = 0; i < len; i++) {
        final idx = start + i;
        if (idx < 0 || idx >= mix.length) continue;
        final progress = i / len;
        final hz = 45.0 + (1 - progress) * 75.0;
        final env = math.pow(1 - progress, 2.4).toDouble();
        mix[idx] += math.sin(2 * math.pi * hz * (i / _sampleRate)) * env * 0.5;
      }
    }
    // Hi-hat: ruido corto en la contratiempo.
    final hatStart = ((startSec + beatSec * 0.5) * _sampleRate).round();
    final hatLen = (_sampleRate * 0.03).round();
    final rand = math.Random(hatStart);
    for (var i = 0; i < hatLen; i++) {
      final idx = hatStart + i;
      if (idx < 0 || idx >= mix.length) continue;
      final env = 1 - i / hatLen;
      mix[idx] += (rand.nextDouble() * 2 - 1) * env * hatIntensity * 0.3;
    }
  }

  /// WAV PCM16 mono 22050Hz (header RIFF de 44 bytes).
  static Uint8List _encodeWav(Int8List pcm) {
    const headerSize = 44;
    final dataLen = pcm.length;
    final total = headerSize + dataLen;
    final out = Uint8List(total);
    void writeAscii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        out[offset + i] = s.codeUnitAt(i);
      }
    }

    void writeU32(int offset, int v) {
      out[offset] = v & 0xff;
      out[offset + 1] = (v >> 8) & 0xff;
      out[offset + 2] = (v >> 16) & 0xff;
      out[offset + 3] = (v >> 24) & 0xff;
    }

    void writeU16(int offset, int v) {
      out[offset] = v & 0xff;
      out[offset + 1] = (v >> 8) & 0xff;
    }

    writeAscii(0, 'RIFF');
    writeU32(4, total - 8);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    writeU32(16, 16);
    writeU16(20, 1); // PCM
    writeU16(22, 1); // mono
    writeU32(24, _sampleRate);
    writeU32(28, _sampleRate * 2);
    writeU16(32, 2);
    writeU16(34, 16);
    writeAscii(36, 'data');
    writeU32(40, dataLen);
    out.setRange(headerSize, total, pcm);
    return out;
  }

  // ------------------------------------------------------------ escalas

  static List<int> _scaleSteps(ScaleMode mode) => switch (mode) {
        ScaleMode.minor => [0, 2, 3, 5, 7, 8, 10],
        ScaleMode.dorian => [0, 2, 3, 5, 7, 9, 10],
        ScaleMode.phrygian => [0, 1, 3, 5, 7, 8, 10],
        ScaleMode.locrian => [0, 1, 3, 5, 6, 8, 10],
        ScaleMode.pentatonic => [0, 3, 5, 7, 10],
      };

  static double _semitone(int steps) => math.pow(2, steps / 12).toDouble();
}

/// Semilla musical de una pista: tonalidad, modo, tempo y duración.
class MusicTrack {
  final String id;
  final String name;
  final double rootHz;
  final ScaleMode mode;
  final int tempoBpm;
  final int seconds;
  final double brightness;

  const MusicTrack({
    required this.id,
    required this.name,
    required this.rootHz,
    required this.mode,
    required this.tempoBpm,
    required this.seconds,
    required this.brightness,
  });
}

enum ScaleMode { minor, dorian, phrygian, locrian, pentatonic }

enum _Timbre { sine, triangle, saw }

// Silence unused import analyzer hint for Color (kept for future tinting).
// ignore: unused_element
const Color _unusedColorRef = Color(0x00000000);
