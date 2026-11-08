/// Ajustes globales de rendimiento (RAM/GPU) del cliente.
///
/// Se persisten en la tabla `player_stats` (clave [lowSpecKey]) y los lee
/// [CombatScreen] al montar el combate para decidir cuántas partículas y
/// textos flotantes se permiten, y si se dibujan animaciones decorativas.
library;

class PerformanceSettings {
  PerformanceSettings._();

  /// Clave de persistencia en `player_stats`.
  static const String lowSpecKey = 'lowSpecMode';

  static bool _lowSpec = false;

  /// `true` cuando el jugador activó el Modo Gama Baja.
  static bool get lowSpecMode => _lowSpec;

  /// Activa o desactiva el modo sin persistir (la persistencia vive en el
  /// repositorio, para que el dominio no dependa de SQLite).
  static void setLowSpecMode(bool value) {
    _lowSpec = value;
  }

  /// Restaura el modo desde un valor persistido (0/1).
  static void restoreFromStorage({int? flag}) {
    _lowSpec = flag == 1;
  }

  /// Vuelve al valor por defecto (tests).
  static void reset() {
    _lowSpec = false;
  }

  /// Ráfagas de partículas simultáneas: 24 normal / 10 gama baja (~40%).
  static int get maxParticleBursts => _lowSpec ? 10 : 24;

  /// Anillos dibujados por ráfaga: 4 normal / 2 gama baja.
  static int get ringsPerBurst => _lowSpec ? 2 : 4;

  /// Escala visual del halo: 1.0 normal / 0.6 gama baja.
  static double get particleScale => _lowSpec ? 0.6 : 1.0;

  /// Textos flotantes de daño simultáneos: 12 normal / 6 gama baja.
  static int get maxFloatingTexts => _lowSpec ? 6 : 12;

  /// Halos y sombras secundarias (costosos en GPU) activos.
  static bool get enableSecondaryGlow => !_lowSpec;

  /// Animaciones decorativas del fondo del arena.
  static bool get enableDecorativeBackground => !_lowSpec;
}
