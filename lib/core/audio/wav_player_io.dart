import 'package:flutter/services.dart';

/// IO (Android / iOS / desktop) audio backend.
///
/// Ships zero pub dependencies: the synthesized WAV bytes travel over a
/// [MethodChannel] to a native sink registered by the host app. On Android that
/// sink is `MainActivity`'s `AudioTrack` engine (see `android/.../MainActivity.kt`);
/// on desktop/iOS there is no handler, so every call degrades to a silent no-op
/// (`MissingPluginException` / `PlatformException` are swallowed).
///
/// The web build never compiles this file (conditional import picks
/// `wav_player_web.dart`), so `package:flutter/services.dart` here costs nothing
/// on the browser bundle.
const MethodChannel _channel = MethodChannel('com.brimstone.summoning/audio');

/// True: the buffers are handed to a native sink that can actually sound them
/// when a handler is registered. The bridge cannot know synchronously whether
/// the host app registered it, so it optimistically reports support and stays
/// silent when the call bounces.
const bool wavPlaybackSupported = true;
const bool wavLoopSupported = true;

bool _unlocked = false;

Future<Object?> _invoke(String method, [Map<String, Object?>? args]) async {
  try {
    return await _channel.invokeMethod<Object?>(method, args);
  } catch (_) {
    // MissingPluginException (tests, desktop, iOS without handler) and any
    // platform error must never reach the game loop.
    return null;
  }
}

void unlockAudio() {
  if (_unlocked) return;
  _unlocked = true;
  _invoke('unlock');
}

void playWav(String key, Uint8List wav, double volume) {
  _invoke('play', {
    'key': key,
    'bytes': wav,
    'volume': volume.clamp(0.0, 1.0),
  });
}

void loopWav(String key, Uint8List wav, double volume) {
  _invoke('loop', {
    'key': key,
    'bytes': wav,
    'volume': volume.clamp(0.0, 1.0),
  });
}

void stopLoopWav(String key) {
  _invoke('stopLoop', {'key': key});
}

void stopAllWav() {
  _invoke('stopAll');
}
