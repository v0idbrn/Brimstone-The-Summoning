import 'dart:convert';

import 'seal_sha256.dart';

/// Firma criptográfica de integridad para los respaldos del jugador.
///
/// El sello es un HMAC-SHA256 de 256 bits sobre una serialización **canónica**
/// del payload (claves ordenadas, sin espacios), de modo que cambiar un solo
/// dígito del oro, las estrellas de una carta o el nivel de un talento produce
/// una firma distinta y el import se rechaza.
///
/// La clave se reconstruye en caliente desde fragmentos de bytes ofuscados:
/// no existe ningún literal de contraseña legible en el binario, y el salt se
/// mezcla con un acumulador para que la clave final no aparezca tal cual en
/// el `.apk`.
class IntegritySigner {
  IntegritySigner({List<int>? salt}) : _salt = salt ?? _derivedSalt();

  /// Campo donde viaja la firma dentro del JSON del backup.
  static const String signatureKey = 'sealSignature';

  /// Mensaje exacto que ve el jugador cuando el sello no cuadra.
  static const String tamperMessage =
      'Sello Abisal corrupto: se detectó manipulación externa del respaldo.';

  final List<int> _salt;

  /// Longitud (en caracteres hex) de una firma válida.
  static const int signatureLength = 64;

  /// Calcula la firma del payload (ignorando una firma previa si existe).
  String sign(Map<String, dynamic> payload) {
    final body = Map<String, dynamic>.of(payload)..remove(signatureKey);
    final canonical = canonicalize(body);
    final mac = SealSha256.hmac(_salt, utf8.encode(canonical));
    return SealSha256.hex(mac);
  }

  /// `true` si el payload incluye una firma válida.
  bool verify(Map<String, dynamic> payload) {
    final provided = payload[signatureKey];
    if (provided is! String || provided.length != signatureLength) {
      return false;
    }
    return constantTimeEquals(sign(_stripSignature(payload)), provided);
  }

  /// Serialización determinista: claves de mapa ordenadas, listas en orden.
  static String canonicalize(Object? value) {
    final buffer = StringBuffer();
    _writeCanonical(value, buffer);
    return buffer.toString();
  }

  static void _writeCanonical(Object? value, StringBuffer out) {
    if (value == null) {
      out.write('null');
      return;
    }
    if (value is bool) {
      out.write(value ? 'true' : 'false');
      return;
    }
    if (value is num) {
      if (value is double &&
          value == value.truncateToDouble() &&
          value.isFinite) {
        out.write(value.toInt().toString());
      } else {
        out.write(value.toString());
      }
      return;
    }
    if (value is String) {
      out.write(jsonEncode(value));
      return;
    }
    if (value is Iterable) {
      out.write('[');
      var first = true;
      for (final item in value) {
        if (!first) out.write(',');
        first = false;
        _writeCanonical(item, out);
      }
      out.write(']');
      return;
    }
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      out.write('{');
      var first = true;
      for (final key in keys) {
        if (!first) out.write(',');
        first = false;
        out.write(jsonEncode(key));
        out.write(':');
        _writeCanonical(value[key], out);
      }
      out.write('}');
      return;
    }
    out.write(jsonEncode(value.toString()));
  }

  static Map<String, dynamic> _stripSignature(Map<String, dynamic> payload) =>
      Map<String, dynamic>.of(payload)..remove(signatureKey);

  /// Comparación en tiempo constante (evita filtraciones por temporización).
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Salt derivado de fragmentos de bytes ofuscados y un acumulador.
  static List<int> _derivedSalt() {
    const fragments = <List<int>>[
      <int>[0x1D, 0x7A, 0x53, 0xC1, 0x08],
      <int>[0x92, 0x0B, 0xE4, 0x38, 0x6F],
      <int>[0x44, 0xAF, 0x21, 0x9C, 0xD3],
      <int>[0x7E, 0x35, 0xB8, 0x02, 0xAA],
      <int>[0xC5, 0x61, 0x1F, 0xED, 0x74],
      <int>[0x3A, 0x9D, 0x80, 0x56, 0x0C],
    ];
    var acc = 0x5A17C3E9;
    final salt = <int>[];
    for (var i = 0; i < fragments.length; i++) {
      final fragment = fragments[i];
      for (var j = 0; j < fragment.length; j++) {
        acc = (acc * 33 + i * 7 + j * 13 + fragment[j]) & 0xFFFFFFFF;
        salt.add((fragment[j] ^ ((acc >> 11) & 0xFF)) & 0xFF);
      }
    }
    return salt;
  }
}
