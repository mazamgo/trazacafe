import 'dart:io';

import 'package:drift/drift.dart';

import '../data/database.dart';
import 'api_client.dart';

/// Corrige o anula datos con errores (un cero de más, la fecha equivocada).
///
/// Mismo patrón que `FincasService.cambiarCultivo`: si el dato todavía no se
/// envió, se corrige solo en el celular (nunca llegó al servidor); si ya se
/// envió, primero en la API (necesita señal) y después en el celular. Si la
/// API lo rechaza (está en un lote, es de otro técnico...), el celular no
/// cambia y el error trae el motivo.
class CorreccionesService {
  CorreccionesService(this._db, this._api);

  final AppDatabase _db;
  final ApiClient _api;

  /// En un lote o firmada en la blockchain ya no se corrige.
  static String? bloqueoEntrega(Entrega e) {
    if (e.loteCodigo != null) {
      return 'Esta entrega está en el lote ${e.loteCodigo}: para corregirla, '
          'primero hay que deshacer el lote.';
    }
    if (e.attestationUid != null) {
      return 'Esta entrega ya está firmada en la blockchain: no se puede corregir.';
    }
    return null;
  }

  Future<String> _cultivoDe(String fincaId) async => (await (_db.select(
    _db.fincas,
  )..where((f) => f.id.equals(fincaId))).getSingle()).cultivo;

  /// [motivo] es obligatorio en la API si cambian los kg o la fecha.
  Future<void> corregirEntrega(
    Entrega e, {
    double? kg,
    String? estado,
    DateTime? fecha,
    String? motivo,
  }) async {
    if (!e.sincronizado) {
      final nuevaFecha = fecha ?? e.fecha;
      final temporada = await _db.temporadaDe(
        nuevaFecha,
        cultivo: await _cultivoDe(e.fincaId),
      );
      await (_db.update(_db.entregas)..where((x) => x.id.equals(e.id))).write(
        EntregasCompanion(
          kg: Value(kg ?? e.kg),
          estado: Value(estado ?? e.estado),
          fecha: Value(nuevaFecha),
          temporadaId: Value(temporada?.id),
        ),
      );
      return;
    }
    final r = await _api.corregirEntrega(e.id, {
      if (kg != null && kg != e.kg) 'kg': kg,
      if (estado != null && estado != e.estado) 'estado': estado,
      if (fecha != null && fecha != e.fecha)
        'fecha': fecha.toUtc().toIso8601String(),
      'motivo': ?motivo,
    });
    await (_db.update(_db.entregas)..where((x) => x.id.equals(e.id))).write(
      EntregasCompanion(
        kg: Value((r['kg'] as num).toDouble()),
        estado: Value(r['estado'] as String),
        fecha: Value(DateTime.parse(r['fecha'] as String).toLocal()),
        temporadaId: Value(r['temporadaId'] as String?),
        corregida: const Value(true),
      ),
    );
  }

  /// La entrega deja de contar. En el servidor queda marcada como anulada
  /// (con el motivo); en el celular desaparece.
  Future<void> anularEntrega(Entrega e, String motivo) async {
    if (e.sincronizado) await _api.anularEntrega(e.id, motivo);
    await (_db.delete(_db.entregas)..where((x) => x.id.equals(e.id))).go();
  }

  Future<void> corregirProductor(
    Productor p, {
    String? nombre,
    String? cedula,
    String? comunidad,
  }) async {
    if (p.sincronizado) {
      await _api.corregirProductor(p.id, {
        if (nombre != null && nombre != p.nombre) 'nombre': nombre,
        if (cedula != p.cedula) 'cedula': cedula,
        if (comunidad != p.comunidad) 'comunidad': comunidad,
      });
    }
    // Sin enviar: el productor viaja completo en la próxima sincronización.
    await (_db.update(_db.productores)..where((x) => x.id.equals(p.id))).write(
      ProductoresCompanion(
        nombre: Value(nombre ?? p.nombre),
        cedula: Value(cedula),
        comunidad: Value(comunidad),
      ),
    );
  }

  /// [areaHa] solo en fincas de un punto (en un polígono sale del lindero).
  Future<void> corregirFinca(
    Finca f, {
    String? nombre,
    double? areaHa,
    String? motivo,
  }) async {
    if (f.sincronizado) {
      await _api.corregirFinca(f.id, {
        if (nombre != null && nombre != f.nombre) 'nombre': nombre,
        if (areaHa != null && areaHa != f.areaHa) 'areaHa': areaHa,
        'motivo': ?motivo,
      });
    }
    await (_db.update(_db.fincas)..where((x) => x.id.equals(f.id))).write(
      FincasCompanion(
        nombre: Value(nombre ?? f.nombre),
        areaHa: Value(areaHa ?? f.areaHa),
        // En un punto, el área oficial es la declarada.
        areaOficialHa: Value(areaHa ?? f.areaOficialHa),
      ),
    );
  }

  /// Quita una foto equivocada, también su archivo del celular.
  Future<void> eliminarFoto(Foto foto) async {
    if (foto.sincronizado) await _api.eliminarFoto(foto.id);
    await (_db.delete(_db.fotos)..where((x) => x.id.equals(foto.id))).go();
    try {
      await File(foto.ruta).delete();
    } on FileSystemException {
      // Ya no estaba.
    }
  }

  /// [fecha] lleva [motivo]; la nota se puede corregir siempre.
  Future<void> corregirVisita(
    Verificacion v, {
    String? nota,
    DateTime? fecha,
    String? motivo,
  }) async {
    if (v.sincronizado) {
      await _api.corregirVisita(v.id, {
        if (nota != v.nota) 'nota': nota,
        if (fecha != null && fecha != v.fecha)
          'fecha': fecha.toUtc().toIso8601String(),
        'motivo': ?motivo,
      });
    }
    final nuevaFecha = fecha ?? v.fecha;
    final temporada = await _db.temporadaDe(
      nuevaFecha,
      cultivo: await _cultivoDe(v.fincaId),
    );
    await (_db.update(
      _db.verificaciones,
    )..where((x) => x.id.equals(v.id))).write(
      VerificacionesCompanion(
        nota: Value(nota),
        fecha: Value(nuevaFecha),
        temporadaId: Value(temporada?.id),
      ),
    );
  }

  /// Anula una visita sin lindero nuevo; sus fotos quedan en el celular.
  Future<void> anularVisita(Verificacion v, String motivo) async {
    if (v.linderoCambio) {
      throw StateError(
        'Esta visita registró un lindero nuevo: no se puede anular.',
      );
    }
    if (v.sincronizado) await _api.anularVisita(v.id, motivo);
    await (_db.delete(
      _db.verificaciones,
    )..where((x) => x.id.equals(v.id))).go();
  }
}
