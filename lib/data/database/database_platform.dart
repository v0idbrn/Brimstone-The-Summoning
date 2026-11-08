/// Selección de backend SQLite en tiempo de compilación.
///
/// En navegador se importa la implementación WebAssembly/IndexedDB; en el
/// resto de plataformas, la nativa con FFI. El código que consume este archivo
/// nunca toca `dart:io` directamente.
library;

export 'database_platform_io.dart'
    if (dart.library.js_interop) 'database_platform_web.dart';
