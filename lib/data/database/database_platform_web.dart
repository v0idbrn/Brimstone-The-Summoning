import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Backend SQLite para el navegador.
///
/// Usa `sqflite_common_ffi_web`, que ejecuta SQLite compilado a WebAssembly y
/// persiste en IndexedDB. No toca `dart:io` ni `dart:ffi`, así que
/// `flutter build web --release` compila sin dependencias nativas. Los assets
/// `web/sqlite3.wasm` y `web/sqflite_sw.js` se generan con
/// `dart run sqflite_common_ffi_web:setup`.
void configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}

/// En web la base vive en IndexedDB bajo este nombre lógico.
Future<String> platformDatabasePath() async => 'brimstone.db';

/// En web no hay sistema de archivos: las rutas de test caen a nombres lógicos.
String platformTempDirectory() => '';
