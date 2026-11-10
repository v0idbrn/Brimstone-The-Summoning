import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web backend: turns the cached PCM WAV buffers into Blob URLs and plays them
/// through a small pool of `HTMLAudioElement` voices.
///
/// * Six voices allow overlapping SFX without cutting the previous hit.
/// * The same sound key always reuses one Blob URL (no re-encoding per shot).
/// * Autoplay rejections are swallowed: browsers block audio until the first
///   gesture, and we simply resume on the next shot after the title tap.
const bool wavPlaybackSupported = true;
const bool wavLoopSupported = true;

const int _maxVoices = 6;

final Map<String, String> _urls = <String, String>{};
final List<web.HTMLAudioElement> _voices = <web.HTMLAudioElement>[];
final Map<String, web.HTMLAudioElement> _loops =
    <String, web.HTMLAudioElement>{};

int _cursor = 0;
bool _blockedOnce = false;

bool get _audioBlocked => _blockedOnce;

web.HTMLAudioElement _acquireVoice() {
  if (_voices.length < _maxVoices) {
    final voice = web.HTMLAudioElement()
      ..preload = 'auto'
      ..autoplay = false;
    _voices.add(voice);
    return voice;
  }
  _cursor = (_cursor + 1) % _voices.length;
  return _voices[_cursor];
}

String _urlFor(String key, Uint8List wav) {
  final cached = _urls[key];
  if (cached != null) return cached;
  final blob = web.Blob(
    <JSAny>[wav.toJS].toJS,
    web.BlobPropertyBag(type: 'audio/wav'),
  );
  final url = web.URL.createObjectURL(blob);
  _urls[key] = url;
  return url;
}

void _swallow(JSPromise<JSAny?> promise) {
  promise.toDart.catchError((Object _) {
    // Autoplay policy or a decode hiccup: never surface to gameplay.
    _blockedOnce = true;
    return null;
  });
}

void unlockAudio() {
  _blockedOnce = false;
}

void playWav(String key, Uint8List wav, double volume) {
  if (volume <= 0 || wav.length <= 44) return;
  try {
    final voice = _acquireVoice();
    final url = _urlFor(key, wav);
    if (voice.src != url) {
      voice.src = url;
    }
    voice
      ..volume = volume.clamp(0.0, 1.0)
      ..currentTime = 0;
    _swallow(voice.play());
  } catch (_) {
    _blockedOnce = true;
  }
}

void loopWav(String key, Uint8List wav, double volume) {
  try {
    final existing = _loops[key];
    if (existing != null) {
      existing.volume = volume.clamp(0.0, 1.0);
      return;
    }
    final element = web.HTMLAudioElement()
      ..preload = 'auto'
      ..loop = true
      ..src = _urlFor(key, wav)
      ..volume = volume.clamp(0.0, 1.0);
    _loops[key] = element;
    _swallow(element.play());
  } catch (_) {
    _blockedOnce = true;
  }
}

void stopLoopWav(String key) {
  final element = _loops.remove(key);
  if (element == null) return;
  try {
    element.pause();
    element.currentTime = 0;
  } catch (_) {
    // Element already detached.
  }
}

void stopAllWav() {
  for (final voice in _voices) {
    try {
      voice.pause();
      voice.currentTime = 0;
    } catch (_) {}
  }
  for (final key in _loops.keys.toList(growable: false)) {
    stopLoopWav(key);
  }
  _cursor = 0;
}

/// True once a browser blocked playback for lack of a user gesture.
bool get wavPlaybackWasBlocked => _audioBlocked;
