import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../data/database.dart';
import 'api_client.dart';
import 'datos_celular.dart';

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
      // Datos de otra organización en el celular: no se mezclan.
      final org = _organizacionId();
      final duena = await _db.leerAjuste(ClaveAjuste.organizacionDatos);
      if (org != null && duena != null && duena != org) {
        throw DatosDeOtraOrganizacion();
      }
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
          'cultivo': f.cultivo,
          'coordenadas': jsonDecode(f.coordenadasJson),
          'areaHa': f.areaHa,
          'geoHash': f.geoHash,
        },
    ],
    'versionesFinca': [
      for (final v in p.versionesFinca)
        {
          'fincaId': v.fincaId,
          'version': v.version,
          'coordenadas': jsonDecode(v.coordenadasJson),
          'areaHa': v.areaHa,
          'geoHash': v.geoHash,
        },
    ],
    'verificaciones': [
      for (final v in p.verificaciones)
        {
          'id': v.id,
          'fincaId': v.fincaId,
          'fecha': v.fecha.toUtc().toIso8601String(),
          'linderoCambio': v.linderoCambio,
          'versionFinca': v.versionFinca,
          'nota': v.nota,
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
    List<Map<String, dynamic>> lista(String clave) =>
        ((d[clave] as List?) ?? const []).cast<Map<String, dynamic>>();
    DateTime? fecha(Object? v) =>
        v == null ? null : DateTime.parse(v as String).toLocal();
    // "2026-10-01" → medianoche local de ese día (las temporadas son días en Nicaragua).
    DateTime dia(Object v) {
      final p = (v as String).split('-').map(int.parse).toList();
      return DateTime(p[0], p[1], p[2]);
    }

    final organizacion = d['organizacion'] as Map?;
    final cultivos = organizacion?['cultivos'] as List?;
    return DatosServidor(
      cultivos: cultivos?.cast<String>(),
      ajustes: organizacion == null
          ? null
          : {
              ClaveAjuste.eliminacionProgramada:
                  organizacion['eliminacionProgramada'] as String?,
              ClaveAjuste.solicitudesPendientes:
                  '${(d['solicitudesPendientes'] as int?) ?? 0}',
            },
      temporadas: [
        for (final t in lista('temporadas'))
          TemporadasCompanion(
            id: Value(t['id'] as String),
            nombre: Value(t['nombre'] as String),
            inicio: Value(dia(t['inicio']!)),
            fin: Value(dia(t['fin']!)),
            cultivo: Value(t['cultivo'] as String?),
          ),
      ],
      verificaciones: [
        for (final v in lista('verificaciones'))
          VerificacionesCompanion(
            id: Value(v['id'] as String),
            fincaId: Value(v['fincaId'] as String),
            temporadaId: Value(v['temporadaId'] as String?),
            fecha: Value(fecha(v['fecha'])!),
            linderoCambio: Value(v['linderoCambio'] as bool),
            versionFinca: Value(v['versionFinca'] as int),
            nota: Value(v['nota'] as String?),
            sincronizado: enviado,
          ),
      ],
      productores: [
        for (final p in (d['productores'] as List).cast<Map<String, dynamic>>())
          ProductoresCompanion(
            id: Value(p['id'] as String),
            nombre: Value(p['nombre'] as String),
            cedula: Value(p['cedula'] as String?),
            comunidad: Value(p['comunidad'] as String?),
            consentimientoFirmado: Value(p['consentimientoFirmado'] as bool),
            sincronizado: enviado,
            anonimizado: Value((p['anonimizado'] as bool?) ?? false),
            conservarHasta: Value(
              p['conservarHasta'] == null ? null : dia(p['conservarHasta']!),
            ),
          ),
      ],
      fincas: [
        for (final f in (d['fincas'] as List).cast<Map<String, dynamic>>())
          FincasCompanion(
            id: Value(f['id'] as String),
            productorId: Value(f['productorId'] as String),
            nombre: Value(f['nombre'] as String),
            cultivo: Value((f['cultivo'] as String?) ?? 'cafe'),
            coordenadasJson: Value(jsonEncode(f['coordenadas'])),
            areaHa: Value((f['areaHa'] as num).toDouble()),
            areaOficialHa: Value((f['areaOficialHa'] as num?)?.toDouble()),
            geoHash: Value(f['geoHash'] as String),
            attestationUid: Value(f['attestationUid'] as String?),
            version: Value((f['version'] as int?) ?? 1),
            deforestacion: Value(
              (f['deforestacion'] as String?) ?? 'pendiente',
            ),
            ultimoChequeo: Value(fecha(f['ultimoChequeo'])),
            sincronizado: enviado,
          ),
      ],
      entregas: [
        for (final e in (d['entregas'] as List).cast<Map<String, dynamic>>())
          EntregasCompanion(
            id: Value(e['id'] as String),
            fincaId: Value(e['fincaId'] as String),
            temporadaId: Value(e['temporadaId'] as String?),
            kg: Value((e['kg'] as num).toDouble()),
            estado: Value(e['estado'] as String),
            fecha: Value(DateTime.parse(e['fecha'] as String).toLocal()),
            attestationUid: Value(e['attestationUid'] as String?),
            loteCodigo: Value(e['loteCodigo'] as String?),
            corregida: Value((e['corregida'] as bool?) ?? false),
            sincronizado: enviado,
          ),
      ],
    );
  }
}
