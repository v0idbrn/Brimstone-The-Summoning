import 'dart:typed_data';

/// IO (Android / iOS / desktop) audio backend.
///
/// The procedural WAV buffers are fully synthesized on this side, but PCM
/// playback needs a native sink. No pure-Dart sink exists, and the project
/// ships without native audio plugins, so the engine keeps its platform
/// `SystemSound` + haptics feedback here and reports `supported = false`.
///
/// Everything below is a no-op with the exact same contract as the web bridge,
/// so `ProceduralSfxEngine` can call it unconditionally.
const bool wavPlaybackSupported = false;
const bool wavLoopSupported = false;

void unlockAudio() {}

void playWav(String key, Uint8List wav, double volume) {}

void loopWav(String key, Uint8List wav, double volume) {}

void stopLoopWav(String key) {}

void stopAllWav() {}
