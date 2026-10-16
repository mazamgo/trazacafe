import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';

/// Foto tomada pero todavía sin guardar en la base (el registro al que
/// pertenece puede no existir aún).
class FotoTomada {
  FotoTomada(this.id, this.ruta, this.sha256);
  final String id;
  final String ruta;
  final String sha256;
}

class FotosService {
  FotosService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Abre la cámara y copia la foto a la carpeta privada de la app.
  /// Devuelve `null` si el técnico cancela.
  Future<FotoTomada?> tomar() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 75,
    );
    if (x == null) return null;

    final bytes = await x.readAsBytes();
    final id = const Uuid().v4();
    final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'fotos'),
    );
    await dir.create(recursive: true);
    final destino = File(p.join(dir.path, '$id.jpg'));
    await destino.writeAsBytes(bytes, flush: true);
    return FotoTomada(id, destino.path, '0x${sha256.convert(bytes)}');
  }

  static FotosCompanion registro(
    FotoTomada foto, {
    required String entidadTipo,
    required String entidadId,
    required String tipo,
  }) => FotosCompanion.insert(
    id: foto.id,
    entidadTipo: entidadTipo,
    entidadId: entidadId,
    tipo: tipo,
    ruta: foto.ruta,
    sha256: foto.sha256,
  );
}
