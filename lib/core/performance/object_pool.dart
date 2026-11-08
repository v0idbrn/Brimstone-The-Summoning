/// Estructuras de memoria de capacidad fija para el bucle de combate.
///
/// El juego corre durante horas en dispositivos de 1–2 GB de RAM: cualquier
/// lista que crezca con cada impacto termina en un OOM silencioso. Un
/// [FixedRingBuffer] reserva sus `capacity` ranuras una sola vez y, cuando se
/// llena, **recicla** la entrada más antigua en O(1) sin reasignar memoria.
library;

/// Búfer circular de capacidad fija, pre-alojado y reciclable.
///
/// - `add` nunca asigna memoria nueva ni supera [capacity].
/// - Al llenarse sobreescribe la entrada más antigua (FIFO) y cuenta el
///   reciclaje en [overwrites], útil para telemetría de rendimiento.
/// - Implementa [Iterable] para poder usarse en `for (final x in buffer)`.
class FixedRingBuffer<T> extends Iterable<T> {
  FixedRingBuffer(this.capacity) : _slots = List<T?>.filled(capacity, null) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'debe ser > 0');
    }
  }

  /// Número máximo de elementos vivos (nunca cambia).
  final int capacity;

  final List<T?> _slots;

  /// Índice físico del elemento más antiguo.
  int _start = 0;
  int _length = 0;
  int _overwrites = 0;

  @override
  int get length => _length;

  @override
  bool get isEmpty => _length == 0;

  @override
  bool get isNotEmpty => _length != 0;

  /// `true` cuando ya se recicló al menos una entrada.
  bool get isFull => _length == capacity;

  /// Entradas descartadas por desbordamiento desde la creación/limpieza.
  int get overwrites => _overwrites;

  /// Ranuras libres antes de empezar a reciclar.
  int get remaining => capacity - _length;

  @override
  Iterator<T> get iterator => _FixedRingIterator<T>(this);

  /// Acceso indexado en orden de inserción (0 = más antiguo).
  T operator [](int index) {
    if (index < 0 || index >= _length) {
      throw RangeError.index(index, this, 'index', null, _length);
    }
    return _slots[(_start + index) % capacity] as T;
  }

  @override
  T get first {
    if (_length == 0) throw StateError('No element');
    return this[0];
  }

  @override
  T get last {
    if (_length == 0) throw StateError('No element');
    return this[_length - 1];
  }

  /// Primer elemento o `null` si está vacío.
  T? get firstOrNull => _length == 0 ? null : this[0];

  /// Último elemento o `null` si está vacío.
  T? get lastOrNull => _length == 0 ? null : this[_length - 1];

  /// Inserta [value], reciclando la entrada más antigua si está lleno.
  void add(T value) {
    if (_length < capacity) {
      _slots[(_start + _length) % capacity] = value;
      _length++;
      return;
    }
    _slots[_start] = value;
    _start = (_start + 1) % capacity;
    _overwrites++;
  }

  void addAll(Iterable<T> values) {
    for (final value in values) {
      add(value);
    }
  }

  /// Elimina y devuelve el elemento más antiguo (sin asignar memoria).
  T? removeFirst() {
    if (_length == 0) return null;
    final value = _slots[_start] as T;
    _slots[_start] = null;
    _start = (_start + 1) % capacity;
    _length--;
    if (_length == 0) _start = 0;
    return value;
  }

  /// Filtra en sitio conservando el orden (sin listas temporales).
  void removeWhere(bool Function(T value) test) {
    var write = 0;
    for (var read = 0; read < _length; read++) {
      final value = _slots[(_start + read) % capacity] as T;
      if (test(value)) continue;
      _slots[(_start + write) % capacity] = value;
      write++;
    }
    for (var i = write; i < _length; i++) {
      _slots[(_start + i) % capacity] = null;
    }
    _length = write;
    if (_length == 0) _start = 0;
  }

  /// Vacía el búfer conservando la capacidad reservada.
  void clear() {
    for (var i = 0; i < _length; i++) {
      _slots[(_start + i) % capacity] = null;
    }
    _start = 0;
    _length = 0;
  }

  @override
  List<T> toList({bool growable = true}) {
    final out = <T>[];
    for (final value in this) {
      out.add(value);
    }
    return growable ? out : List<T>.unmodifiable(out);
  }

  @override
  String toString() => 'FixedRingBuffer<$T>(length: $_length/$capacity)';
}

class _FixedRingIterator<T> implements Iterator<T> {
  _FixedRingIterator(this._buffer);

  final FixedRingBuffer<T> _buffer;
  int _index = -1;

  @override
  T get current => _buffer[_index];

  @override
  bool moveNext() {
    if (_index + 1 >= _buffer.length) return false;
    _index++;
    return true;
  }
}
