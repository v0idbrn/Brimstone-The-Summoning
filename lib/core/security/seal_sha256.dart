import 'dart:typed_data';

/// SHA-256 + HMAC-SHA256 en Dart puro (sin `dart:io`, sin paquetes nativos).
///
/// Necesario para firmar respaldos en Android, escritorio y navegador con el
/// mismo algoritmo determinista.
class SealSha256 {
  SealSha256._();

  static const int _mask32 = 0xFFFFFFFF;

  static const List<int> _k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, //
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  /// Digest SHA-256 (32 bytes) del mensaje.
  static Uint8List hash(List<int> message) {
    final h = Uint32List.fromList(<int>[
      0x6a09e667,
      0xbb67ae85,
      0x3c6ef372,
      0xa54ff53a,
      0x510e527f,
      0x9b05688c,
      0x1f83d9ab,
      0x5be0cd19,
    ]);

    final messageLength = message.length;
    final bitLength = messageLength * 8;
    // Padding: 0x80 + ceros hasta 56 mod 64 + 8 bytes de longitud.
    final paddedLength = ((messageLength + 9 + 63) ~/ 64) * 64;
    final padded = Uint8List(paddedLength);
    padded.setRange(0, messageLength, message);
    padded[messageLength] = 0x80;
    for (var i = 0; i < 8; i++) {
      padded[paddedLength - 1 - i] = (bitLength >> (8 * i)) & 0xFF;
    }

    final w = Uint32List(64);
    for (var offset = 0; offset < paddedLength; offset += 64) {
      for (var i = 0; i < 16; i++) {
        final base = offset + i * 4;
        w[i] = (padded[base] << 24) |
            (padded[base + 1] << 16) |
            (padded[base + 2] << 8) |
            padded[base + 3];
      }
      for (var i = 16; i < 64; i++) {
        final x = w[i - 15];
        final y = w[i - 2];
        final s0 = _rotr(x, 7) ^ _rotr(x, 18) ^ (x >> 3);
        final s1 = _rotr(y, 17) ^ _rotr(y, 19) ^ (y >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & _mask32;
      }

      var a = h[0];
      var b = h[1];
      var c = h[2];
      var d = h[3];
      var e = h[4];
      var f = h[5];
      var g = h[6];
      var hh = h[7];

      for (var i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ (~e & _mask32 & g);
        final temp1 = (hh + s1 + ch + _k[i] + w[i]) & _mask32;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & _mask32;

        hh = g;
        g = f;
        f = e;
        e = (d + temp1) & _mask32;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & _mask32;
      }

      h[0] = (h[0] + a) & _mask32;
      h[1] = (h[1] + b) & _mask32;
      h[2] = (h[2] + c) & _mask32;
      h[3] = (h[3] + d) & _mask32;
      h[4] = (h[4] + e) & _mask32;
      h[5] = (h[5] + f) & _mask32;
      h[6] = (h[6] + g) & _mask32;
      h[7] = (h[7] + hh) & _mask32;
    }

    final digest = Uint8List(32);
    for (var i = 0; i < 8; i++) {
      digest[i * 4] = (h[i] >> 24) & 0xFF;
      digest[i * 4 + 1] = (h[i] >> 16) & 0xFF;
      digest[i * 4 + 2] = (h[i] >> 8) & 0xFF;
      digest[i * 4 + 3] = h[i] & 0xFF;
    }
    return digest;
  }

  /// HMAC-SHA256 (RFC 2104) de 32 bytes.
  static Uint8List hmac(List<int> key, List<int> message) {
    var normalized =
        key.length > 64 ? hash(key) : Uint8List.fromList(List<int>.of(key));
    if (normalized.length < 64) {
      final padded = Uint8List(64);
      padded.setRange(0, normalized.length, normalized);
      normalized = padded;
    }
    final inner = Uint8List(64 + message.length);
    final outer = Uint8List(64 + 32);
    for (var i = 0; i < 64; i++) {
      inner[i] = normalized[i] ^ 0x36;
      outer[i] = normalized[i] ^ 0x5C;
    }
    inner.setRange(64, 64 + message.length, message);
    outer.setRange(64, 96, hash(inner));
    return hash(outer);
  }

  /// Representación hexadecimal en minúsculas.
  static String hex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write((byte & 0xFF).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask32;
}
