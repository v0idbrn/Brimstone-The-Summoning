import 'secure_int.dart';

/// Guardián anti-cheat del cálculo de daño.
///
/// Todo daño que entra a [CombatSanityGuard.sanitize] se valida contra tres
/// reglas: no puede ser negativo, no puede ser `NaN`/`infinito` y no puede
/// superar el techo matemático alcanzable por un solo golpe. Los intentos
/// inválidos se registran ([rejections], [clamps], [lastRejected]) y el valor
/// se recorta a `0` o al techo legal, de modo que una inyección de memoria
/// (por ejemplo `999999999`) no puede matar a un jefe de un golpe.
class CombatSanityGuard {
  CombatSanityGuard({int? maxAllowedSingleHit, int? key})
      : _ceiling = SecureInt(
          maxAllowedSingleHit ?? defaultCeiling,
          key: key,
        );

  /// Techo absoluto por defecto (≈ 500× el daño base del motor).
  static const int defaultCeiling = 17500;

  /// Límite de intentos registrados antes de reiniciar el contador.
  static const int maxRecordedRejections = 999;

  final SecureInt _ceiling;

  int _rejections = 0;
  int _clamps = 0;
  double? _lastRejected;

  /// Techo legal por golpe.
  int get maxAllowedSingleHit => _ceiling.value;

  /// Intentos descartados por valores negativos, NaN o infinitos.
  int get rejections => _rejections;

  /// Intentos recortados por superar el techo.
  int get clamps => _clamps;

  /// Último valor rechazado/recortado (telemetría acotada).
  double? get lastRejected => _lastRejected;

  /// `true` si la memoria del techo fue alterada externamente.
  bool get detectedTampering => !_ceiling.isValid;

  /// Total de anomalías detectadas.
  int get anomalyCount => _rejections + _clamps;

  /// Devuelve un daño legal y registra las anomalías.
  double sanitize(double raw) {
    if (raw.isNaN || raw.isInfinite || raw < 0) {
      _recordRejection(raw);
      return 0;
    }
    final ceiling = maxAllowedSingleHit.toDouble();
    if (raw > ceiling) {
      _recordClamp(raw);
      return ceiling;
    }
    return raw;
  }

  /// Reinicia la telemetría (nuevo combate).
  void reset() {
    _rejections = 0;
    _clamps = 0;
    _lastRejected = null;
  }

  /// Cambia el techo legal (tests / dificultades especiales).
  void setMaxAllowedSingleHit(int value) {
    _ceiling.value = value;
  }

  /// Corrompe la máscara del techo a propósito (solo tests de anti-tamper).
  void debugCorruptCeiling(int delta) => _ceiling.debugAlterMask(delta);

  void _recordRejection(double raw) {
    if (_rejections < maxRecordedRejections) {
      _rejections++;
    } else {
      _rejections = 1;
    }
    _lastRejected = raw;
  }

  void _recordClamp(double raw) {
    if (_clamps < maxRecordedRejections) {
      _clamps++;
    } else {
      _clamps = 1;
    }
    _lastRejected = raw;
  }
}
