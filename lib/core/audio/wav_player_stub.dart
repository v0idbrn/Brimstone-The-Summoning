import 'dart:typed_data';

/// No-audio backend used by tests, web-without-js and unsupported targets.
const bool wavPlaybackSupported = false;
const bool wavLoopSupported = false;

void unlockAudio() {}

void playWav(String key, Uint8List wav, double volume) {}

void loopWav(String key, Uint8List wav, double volume) {}

void stopLoopWav(String key) {}

void stopAllWav() {}
