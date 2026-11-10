import 'dart:typed_data';

import 'wav_player_stub.dart'
    if (dart.library.js_interop) 'wav_player_web.dart'
    if (dart.library.io) 'wav_player_io.dart' as impl;

/// Cross-platform PCM playback bridge for the WAV buffers synthesized by
/// `ProceduralSfxEngine`.
///
/// * Web  → `HTMLAudioElement` pool (Blob URLs, six voices, autoplay-safe).
/// * IO   → silent fallback for now (native backend is registered per flavor).
///
/// Every method is safe to call from any isolate/thread; failures are swallowed
/// so audio can never break a frame or a test.
class WavPlayback {
  const WavPlayback._();

  /// Whether the current platform can play synthesized PCM at all.
  static bool get supported => impl.wavPlaybackSupported;

  /// Whether long ambient loops are supported.
  static bool get supportsLoops => impl.wavLoopSupported;

  /// Unlocks the platform audio context — call from the first user gesture.
  static void unlock() => impl.unlockAudio();

  /// Plays [wav] once. [key] identifies the cached sound so a backend can keep
  /// one decoded element per sound instead of re-decoding every shot.
  static void play(String key, Uint8List wav, {double volume = 1.0}) =>
      impl.playWav(key, wav, volume);

  /// Starts (or re-targets) a looping ambient bed under [key].
  static void loop(String key, Uint8List wav, {double volume = 1.0}) =>
      impl.loopWav(key, wav, volume);

  /// Stops the loop registered under [key].
  static void stopLoop(String key) => impl.stopLoopWav(key);

  /// Stops every voice and loop (used when leaving combat).
  static void stopAll() => impl.stopAllWav();
}
