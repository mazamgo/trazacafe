import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Comparte un archivo generado por la API (PDF, GeoJSON) con las apps del
/// celular: WhatsApp, correo, Drive... En pruebas se usa uno falso.
abstract class Compartidor {
  Future<void> compartir({
    required String nombre,
    required List<int> bytes,
    required String tipo,
    required String asunto,
  });
}

/// Lo guarda en la carpeta temporal de la app y abre el menú de compartir.
class CompartidorSistema implements Compartidor {
  @override
  Future<void> compartir({
    required String nombre,
    required List<int> bytes,
    required String tipo,
    required String asunto,
  }) async {
    final carpeta = await getTemporaryDirectory();
    final archivo = File(p.join(carpeta.path, nombre));
    await archivo.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(archivo.path, mimeType: tipo)],
        subject: asunto,
        title: asunto,
      ),
    );
  }
}
