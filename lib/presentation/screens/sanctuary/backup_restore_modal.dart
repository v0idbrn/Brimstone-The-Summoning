import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/controllers/meta_controller.dart';

/// Modal de Backup / Restaurar. Exporta todo el progreso de SQLite como JSON
/// + Base64 al portapapeles e importa desde un backup pegado, sin crashear
/// ante entradas inválidas.
class BackupRestoreModal extends ConsumerWidget {
  const BackupRestoreModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      backgroundColor: const Color(0xFF14090D),
      title: const Text(
        'Backup / Restaurar',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exportar / importar todo el progreso (oro, esquirlas, colección, '
              'runas, escuadrón, juramentos y récord del Abismo).',
              style:
                  TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _export(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4FFFA3),
                      side: const BorderSide(color: Color(0xFF4FFFA3)),
                    ),
                    child: const Text(
                      'COPIAR BACKUP',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _import(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFC93C),
                      side: const BorderSide(color: Color(0xFFFFC93C)),
                    ),
                    child: const Text(
                      'PEGAR Y RESTAURAR',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'CERRAR',
            style: TextStyle(
                color: Color(0xFFB16EFF), fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(playerRepositoryProvider);
      final data = await repo.exportBackup();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final base64 = base64Encode(utf8.encode(json));
      await Clipboard.setData(ClipboardData(text: base64));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup copiado al portapapeles.'),
            backgroundColor: Color(0xFF4FFFA3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final clipboard = await Clipboard.getData('text/plain');
      final raw = clipboard?.text;
      if (raw == null || raw.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El portapapeles está vacío.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final jsonBytes = base64Decode(raw);
      final jsonString = utf8.decode(jsonBytes);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final repo = ref.read(playerRepositoryProvider);
      await repo.importBackup(data);
      // Recargar estado en memoria.
      await ref.read(profileProvider.notifier).load();
      await ref.read(collectionProvider.notifier).load();
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restaurado correctamente.'),
            backgroundColor: Color(0xFF4FFFA3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup inválido: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
