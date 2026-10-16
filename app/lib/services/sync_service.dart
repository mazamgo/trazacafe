import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../data/database.dart';
import 'api_client.dart';

class ResultadoSync {
  ResultadoSync({this.enviados = 0, this.fotosSubidas = 0, this.errorFotos});

  /// Registros enviados a la API.
  final int enviados;
  final int fotosSubidas;

  /// Primer error al subir fotos; se reintenta en la próxima sincronización.
  final String? errorFotos;
}

/// Sube un archivo a Cloud Storage. La implementación real usa Firebase
/// Storage (`FirebaseSubidor` en providers.dart); en pruebas, uno falso.
abstract class SubidorArchivos {
  Future<void> subir(String rutaStorage, File archivo);
}

/// Ruta de la foto en Storage. La API usa la misma (backend/src/almacen.ts).
String rutaStorageFoto(String organizacionId, String fotoId) =>
    'organizaciones/$organizacionId/fotos/$fotoId.jpg';

/// Sincronización completa:
/// 1. envía lo pendiente y lo marca como enviado solo si la API lo aceptó;
/// 2. sube los archivos de las fotos y pide a la API que confirme su hash;
/// 3. descarga lo de toda la organización (lo que registró el equipo).
/// Si algo falla, lo que no terminó se reintenta la próxima vez.
class SyncService {
  SyncService(this._db, this._api, this._subidor, this._organizacionId);

  final AppDatabase _db;
  final ApiClient _api;
  final SubidorArchivos _subidor;
  final String? Function() _organizacionId;
  bool _enCurso = false;

  Future<ResultadoSync> sincronizar() async {
    if (_enCurso) return ResultadoSync();
    _enCurso = true;
    try {
      final pendientes = await _db.pendientes();
      if (!pendientes.vacio) {
        await _api.sync(payload(pendientes));
        await _db.marcarSincronizados(pendientes);
      }
      final (subidas, errorFotos) = await _subirFotos();
      await _descargar();
      return ResultadoSync(
        enviados: pendientes.total,
        fotosSubidas: subidas,
        errorFotos: errorFotos,
      );
    } finally {
      _enCurso = false;
    }
  }

  Future<(int, String?)> _subirFotos() async {
    final org = _organizacionId();
    if (org == null) return (0, null);
    var subidas = 0;
    String? primerError;
    for (final foto in await _db.fotosPorSubir()) {
      final archivo = File(foto.ruta);
      try {
        if (!await archivo.exists()) {
          primerError ??= 'Falta el archivo de una foto en el celular.';
          continue;
        }
        final ruta = rutaStorageFoto(org, foto.id);
        try {
          await _subidor.subir(ruta, archivo);
        } catch (_) {
          // Puede que ya esté subida (las reglas no dejan reemplazarla); la
          // API dirá si el archivo que hay en Storage es el correcto.
        }
        await _api.confirmarFoto(foto.id);
        await _db.marcarFotoSubida(foto.id);
        subidas++;
      } catch (e) {
        primerError ??= '$e';
      }
    }
    return (subidas, primerError);
  }

  Future<void> _descargar() async {
    final datos = await _api.datos();
    final rutas = await _db.aplicarDatosServidor(desdeServidor(datos));
    for (final ruta in rutas) {
      try {
        await File(ruta).delete();
      } on FileSystemException {
        // Ya no estaba.
      }
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
        'entregas': [
          for (final e in p.entregas)
            {
              'id': e.id,
              'fincaId': e.fincaId,
              'kg': e.kg,
              'estado': e.estado,
              // Con zona horaria, para que el servidor guarde el instante exacto.
              'fecha': e.fecha.toUtc().toIso8601String(),
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

  /// Convierte la respuesta de `GET /v1/datos` en filas locales ya sincronizadas.
  static DatosServidor desdeServidor(Map<String, dynamic> d) {
    const enviado = Value(true);
    return DatosServidor(
      [
        for (final p in (d['productores'] as List).cast<Map<String, dynamic>>())
          ProductoresCompanion(
            id: Value(p['id'] as String),
            nombre: Value(p['nombre'] as String),
            cedula: Value(p['cedula'] as String?),
            comunidad: Value(p['comunidad'] as String?),
            consentimientoFirmado: Value(p['consentimientoFirmado'] as bool),
            sincronizado: enviado,
          ),
      ],
      [
        for (final f in (d['fincas'] as List).cast<Map<String, dynamic>>())
          FincasCompanion(
            id: Value(f['id'] as String),
            productorId: Value(f['productorId'] as String),
            nombre: Value(f['nombre'] as String),
            coordenadasJson: Value(jsonEncode(f['coordenadas'])),
            areaHa: Value((f['areaHa'] as num).toDouble()),
            areaOficialHa: Value((f['areaOficialHa'] as num?)?.toDouble()),
            geoHash: Value(f['geoHash'] as String),
            attestationUid: Value(f['attestationUid'] as String?),
            sincronizado: enviado,
          ),
      ],
      [
        for (final e in (d['entregas'] as List).cast<Map<String, dynamic>>())
          EntregasCompanion(
            id: Value(e['id'] as String),
            fincaId: Value(e['fincaId'] as String),
            kg: Value((e['kg'] as num).toDouble()),
            estado: Value(e['estado'] as String),
            fecha: Value(DateTime.parse(e['fecha'] as String).toLocal()),
            attestationUid: Value(e['attestationUid'] as String?),
            sincronizado: enviado,
          ),
      ],
    );
  }
}
