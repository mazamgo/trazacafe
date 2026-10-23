import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../data/database.dart';

/// Los datos del celular son de una sola organización. Si entra alguien de
/// otra (celular compartido o heredado), no debe ver lo de la anterior ni
/// enviarlo a la suya.
class DatosCelular {
  DatosCelular(this._db);

  final AppDatabase _db;

  /// Deja el celular listo para [organizacionId] al entrar:
  /// - si los datos ya son suyos, o el celular no tiene dueña (instalación
  ///   nueva o datos de antes de esta versión), la anota y sigue;
  /// - si son de otra organización y ya se enviaron todos, los borra (están
  ///   en el servidor) y la nueva descarga los suyos al sincronizar;
  /// - si son de otra y quedan sin enviar, no borra nada y devuelve cuántos
  ///   son, para que la pantalla pregunte qué hacer.
  ///
  /// Devuelve 0 cuando el celular está listo.
  Future<int> prepararPara(String organizacionId) async {
    final duena = await _db.leerAjuste(ClaveAjuste.organizacionDatos);
    if (duena == organizacionId) return 0;
    if (duena != null) {
      // También cuentan las fotos cuyo archivo no se ha subido a Storage.
      final sinEnviar =
          (await _db.pendientes()).total + (await _db.fotosPorSubir()).length;
      if (sinEnviar > 0) return sinEnviar;
      await _borrarTodo();
    }
    await _db.guardarAjuste(ClaveAjuste.organizacionDatos, organizacionId);
    return 0;
  }

  /// Descarta lo que dejó la otra organización, aunque no se haya enviado.
  Future<void> borrarPara(String organizacionId) async {
    await _borrarTodo();
    await _db.guardarAjuste(ClaveAjuste.organizacionDatos, organizacionId);
  }

  Future<void> _borrarTodo() async =>
      borrarArchivosLocales(await _db.borrarTodoLocal());
}

/// Borra del celular los archivos de fotos (las rutas que devuelve la base).
Future<void> borrarArchivosLocales(List<String> rutas) async {
  if (kIsWeb) return;
  for (final ruta in rutas) {
    try {
      await File(ruta).delete();
    } on FileSystemException {
      // Ya no estaba.
    }
  }
}

/// La sesión es de una organización y los datos del celular de otra: no se
/// sincroniza para no mezclarlos.
class DatosDeOtraOrganizacion implements Exception {
  @override
  String toString() =>
      'Este celular tiene datos de otra organización. Cierra sesión y vuelve '
      'a entrar para resolverlo.';
}
