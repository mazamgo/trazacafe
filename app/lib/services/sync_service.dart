import 'dart:convert';

import '../data/database.dart';
import 'api_client.dart';

class ResultadoSync {
  ResultadoSync(this.enviados);
  final int enviados;
}

/// Envía a la API todo lo que está pendiente en la base local y lo marca como
/// sincronizado solo si la API lo aceptó. Si falla, nada cambia y se reintenta
/// en la próxima sincronización.
class SyncService {
  SyncService(this._db, this._api);

  final AppDatabase _db;
  final ApiClient _api;
  bool _enCurso = false;

  Future<ResultadoSync> sincronizar() async {
    if (_enCurso) return ResultadoSync(0);
    _enCurso = true;
    try {
      final pendientes = await _db.pendientes();
      if (pendientes.vacio) return ResultadoSync(0);

      await _api.sync(payload(pendientes));
      await _db.marcarSincronizados(pendientes);
      return ResultadoSync(pendientes.total);
    } finally {
      _enCurso = false;
    }
  }

  /// Formato que espera `backend/src/sync.ts`.
  static Map<String, dynamic> payload(Pendientes p) => {
        'productores': [
          for (final x in p.productores)
            {
              'id': x.id,
              'nombre': x.nombre,
              'cedula': x.cedula,
              'comunidad': x.comunidad,
              'consentimientoFirmado': x.consentimientoFirmado,
            },
        ],
        'fincas': [
          for (final f in p.fincas)
            {
              'id': f.id,
              'productorId': f.productorId,
              'nombre': f.nombre,
              'coordenadas': jsonDecode(f.coordenadasJson),
              'areaHa': f.areaHa,
              'geoHash': f.geoHash,
            },
        ],
        'fotos': [
          for (final f in p.fotos)
            {
              'id': f.id,
              'entidadTipo': f.entidadTipo,
              'entidadId': f.entidadId,
              'tipo': f.tipo,
              'sha256': f.sha256,
            },
        ],
      };
}
