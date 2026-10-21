import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../data/database.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'sync_service.dart';
import 'verificador_service.dart' show verificadorUrl;

/// Página pública para pedir que se borren los datos (requisito de Google
/// Play). La misma app Flutter Web la sirve en Firebase Hosting.
String get enlaceEliminarDatos => '$verificadorUrl/eliminar-datos';
String get enlacePrivacidad => '$verificadorUrl/privacidad';

/// Quedan datos sin enviar y no hubo señal para mandarlos antes de borrar.
class PendientesSinEnviar implements Exception {
  PendientesSinEnviar(this.total, this.causa);
  final int total;
  final Object causa;

  @override
  String toString() =>
      'Hay $total registros sin enviar y no se pudieron sincronizar ($causa).';
}

/// Eliminación de datos desde la app: la cuenta propia, un productor o la
/// organización. Las reglas (qué se borra y qué se conserva 5 años por el
/// EUDR) están en la API (backend/src/eliminacion.ts).
class EliminacionService {
  EliminacionService(this._db, this._api, this._sync, this._auth);

  final AppDatabase _db;
  final ApiClient _api;
  final SyncService _sync;
  final AuthService _auth;

  /// Elimina la cuenta: primero envía lo pendiente (es de la organización),
  /// luego pide a la API que la borre y deja el celular sin datos ni sesión.
  /// Sin señal para enviar lo pendiente lanza [PendientesSinEnviar], salvo
  /// con [descartarPendientes].
  Future<void> eliminarMiCuenta({bool descartarPendientes = false}) async {
    final pendientes = (await _db.pendientes()).total;
    if (pendientes > 0 && !descartarPendientes) {
      try {
        await _sync.sincronizar();
      } catch (e) {
        throw PendientesSinEnviar(pendientes, e);
      }
    }
    await _api.eliminarCuenta();
    await _borrarArchivos(await _db.borrarTodoLocal());
    await _auth.cerrarSesion();
  }

  /// Elimina a un productor (o lo anonimiza si el EUDR obliga a guardar
  /// fincas) y actualiza el celular.
  Future<ResumenEliminacion> eliminarProductor(
    String productorId, {
    String? motivo,
  }) async {
    final r = await _api.eliminarProductor(productorId, motivo: motivo);
    await _sync.sincronizar();
    return r;
  }

  Future<ResumenEliminacion> aprobarSolicitud(
    String solicitudId,
    String productorId,
  ) async {
    final r = await _api.aprobarSolicitud(solicitudId, productorId);
    await _sync.sincronizar();
    return r;
  }

  Future<void> rechazarSolicitud(String solicitudId, String motivo) async {
    await _api.rechazarSolicitud(solicitudId, motivo);
    await _sync.sincronizar();
  }

  Future<void> programarEliminacionOrganizacion() async {
    await _api.programarEliminacionOrganizacion();
    await _sync.sincronizar();
  }

  Future<void> cancelarEliminacionOrganizacion() async {
    await _api.cancelarEliminacionOrganizacion();
    await _sync.sincronizar();
  }

  static Future<void> _borrarArchivos(List<String> rutas) async {
    if (kIsWeb) return;
    for (final ruta in rutas) {
      try {
        await File(ruta).delete();
      } on FileSystemException {
        // Ya no estaba.
      }
    }
  }
}

/// Cooperativa que el productor puede elegir en la página pública.
class OrganizacionPublica {
  const OrganizacionPublica(this.id, this.nombre);
  final String id;
  final String nombre;
}

/// Llamadas sin sesión de la página pública de eliminación de datos.
class EliminacionPublica {
  EliminacionPublica({http.Client? cliente, String baseUrl = apiUrl})
    : _cliente = cliente ?? http.Client(),
      _base = Uri.parse(baseUrl);

  final http.Client _cliente;
  final Uri _base;

  Future<List<OrganizacionPublica>> organizaciones() async {
    final res = await _cliente.get(_base.resolve('/v1/publico/organizaciones'));
    if (res.statusCode != 200) throw ApiError(res.statusCode, _error(res));
    return [
      for (final o
          in (jsonDecode(res.body) as Map<String, dynamic>)['organizaciones']
              as List)
        OrganizacionPublica(o['id'] as String, o['nombre'] as String),
    ];
  }

  /// [organizacionId] `null` = el productor no sabe cuál es su cooperativa.
  Future<void> pedirEliminacion({
    required String? organizacionId,
    required String nombre,
    required String contacto,
    String? cedula,
    String? comunidad,
    String? mensaje,
    String sitio = '',
  }) async {
    final res = await _cliente.post(
      _base.resolve('/v1/publico/solicitudes-eliminacion'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'organizacionId': organizacionId,
        'nombre': nombre,
        'contacto': contacto,
        'cedula': ?cedula,
        'comunidad': ?comunidad,
        'mensaje': ?mensaje,
        if (sitio.isNotEmpty) 'sitio': sitio,
      }),
    );
    if (res.statusCode != 201) throw ApiError(res.statusCode, _error(res));
  }

  static String _error(http.Response res) {
    try {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['mensaje'] is String) return j['mensaje'] as String;
    } catch (_) {}
    return res.statusCode == 429
        ? 'Ya enviaste varias solicitudes. Intenta de nuevo en una hora.'
        : 'No se pudo enviar (error ${res.statusCode}). Intenta más tarde.';
  }
}
