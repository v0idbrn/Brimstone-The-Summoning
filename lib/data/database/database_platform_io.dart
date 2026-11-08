import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Backend SQLite para Android, escritorio y tests (dart:io + FFI).
void configureDatabaseFactory() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Ruta del archivo de progreso en plataformas nativas.
Future<String> platformDatabasePath() async {
  final docs = await getApplicationDocumentsDirectory();
  return p.join(docs.path, 'brimstone.db');
}

/// Carpeta temporal nativa (tests paralelos).
String platformTempDirectory() => Directory.systemTemp.path;
