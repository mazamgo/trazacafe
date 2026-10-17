import 'dart:io';

import '../data/database.dart';
import 'api_client.dart';

/// Correcciones sobre fincas ya registradas.
class FincasService {
  FincasService(this._db, this._api);

  final AppDatabase _db;
  final ApiClient _api;

  /// Una finca atestada ya está en la blockchain: no se borra, se revoca.
  static bool sePuedeEliminar(Finca f) => f.attestationUid == null;

  /// Solo sin entregas: las entregas usan los estados del cultivo de la finca.
  static bool sePuedeCambiarCultivo(Finca f, {required bool tieneEntregas}) =>
      f.attestationUid == null && !tieneEntregas;

  /// Cambia el cultivo. Si la finca ya se había enviado, primero lo cambia
  /// en la API (necesita señal); si la API lo rechaza, el celular no cambia.
  Future<void> cambiarCultivo(Finca f, String cultivo) async {
    if (f.sincronizado) await _api.cambiarCultivoFinca(f.id, cultivo);
    await _db.cambiarCultivoLocal(f.id, cultivo);
  }

  /// Borra la finca. Si ya se había enviado, primero la borra en la API (y
  /// para eso necesita señal); si la API falla, la finca se queda en el
  /// celular para no dejar ambos lados distintos.
  Future<void> eliminar(Finca f) async {
    if (!sePuedeEliminar(f)) {
      throw StateError(
        'La finca ya está atestada; hay que revocar su attestation.',
      );
    }
    if (f.sincronizado) await _api.eliminarFinca(f.id);
    final rutas = await _db.eliminarFincaLocal(f.id);
    for (final ruta in rutas) {
      try {
        await File(ruta).delete();
      } on FileSystemException {
        // El archivo ya no estaba; no impide borrar la finca.
      }
    }
  }
}
