import 'dart:math' as math;

/// Entero enmascarado en RAM para dificultar la edición de memoria.
///
/// El valor nunca se guarda en claro: se almacena como `value ^ key` junto a un
/// dígito verificador derivado de ambos. Si un atacante con un editor de
/// memoria cambia `_masked` sin recalcular el checksum, la lectura lanza
/// [StateError] ("Memory tampering detected") en lugar de devolver un valor
/// inflado.
///
/// Los valores se limitan al rango de 32 bits con signo (0 .. 2^31-1), que
/// cubre con holgura oro, esquirlas, niveles y daño máximo, y garantiza el
/// mismo comportamiento en la VM de Dart y en el navegador (bitwise JS).
class SecureInt {
  /// Crea un entero protegido con [value].
  ///
  /// [key] permite fijar la máscara en tests; por defecto es aleatoria por
  /// instancia.
  SecureInt(int value, {int? key})
      : _key = (key ?? math.Random.secure().nextInt(0x7FFFFFFF)) | 0x01000001 {
    this.value = value;
  }

  static const int maxValue = 0x7FFFFFFF;

  /// Máscara XOR de esta instancia (nunca se expone).
  final int _key;

  int _masked = 0;
  int _checksum = 0;

  /// Valor real; lanza [StateError] si la memoria fue alterada.
  int get value {
    if (!isValid) {
      throw StateError('Memory tampering detected');
    }
    return (_masked ^ _key) & maxValue;
  }

  set value(int next) {
    if (next < 0 || next > maxValue) {
      throw RangeError.range(next, 0, maxValue, 'value');
    }
    _masked = (next ^ _key) & maxValue;
    _checksum = _checksumFor(_masked, _key);
  }

  /// `true` si el par (máscara, checksum) sigue siendo consistente.
  bool get isValid => _checksum == _checksumFor(_masked, _key);

  /// Suma un delta y devuelve el nuevo valor (saturado en 0).
  int add(int delta) {
    final next = value + delta;
    value = next < 0 ? 0 : next;
    return value;
  }

  /// Incrementa en uno.
  int increment() => add(1);

  /// Suma un delta acotándolo a [maxValue] (para contadores de daño).
  int addClamped(int delta, int ceiling) {
    final next = value + delta;
    value = next < 0
        ? 0
        : next > ceiling
            ? ceiling
            : next;
    return value;
  }

  /// Rompe el checksum a propósito (solo tests de anti-tamper).
  void debugAlterMask(int delta) {
    _masked = (_masked + delta) & maxValue;
  }

  @override
  bool operator ==(Object other) => other is SecureInt && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SecureInt(${isValid ? value : 'corrupt'})';

  static int _checksumFor(int masked, int key) {
    final mixed = (masked ^ key) & maxValue;
    final rotated = ((mixed << 13) | (mixed >> 19)) & maxValue;
    return (mixed ^ rotated ^ 0x9E3779B9) & maxValue;
  }
}
