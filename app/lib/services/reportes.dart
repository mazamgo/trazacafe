import 'package:latlong2/latlong.dart';

import 'red_proveedores.dart' show puntosDeGeoJson;

/// Reporte de una temporada (`GET /v1/reportes`): visitas, estado satelital,
/// alertas, kg por cultivo y lotes. Solo administradores.
class Reporte {
  Reporte({
    required this.temporadaNombre,
    required this.resumen,
    required this.satelite,
    required this.alertas,
    required this.sinVisita,
    required this.visitas,
    required this.kg,
    required this.lotes,
  });

  factory Reporte.desdeJson(Map<String, dynamic> j) => Reporte(
    temporadaNombre: (j['temporada'] as Map)['nombre'] as String,
    resumen: ResumenReporte.desdeJson(j['resumen'] as Map<String, dynamic>),
    satelite: {
      for (final e in (j['satelite'] as Map).entries)
        e.key as String: e.value as int,
    },
    alertas: [
      for (final f in j['alertas'] as List)
        FincaReporte.desdeJson(f as Map<String, dynamic>),
    ],
    sinVisita: [
      for (final f in (j['sinVisita'] as List).cast<Map>())
        (
          nombre: f['nombre'] as String,
          productorNombre: f['productorNombre'] as String,
          comunidad: f['comunidad'] as String?,
        ),
    ],
    visitas: [
      for (final v in (j['visitas'] as List).cast<Map>())
        (email: v['email'] as String?, visitas: v['visitas'] as int),
    ],
    kg: [
      for (final k in (j['kg'] as List).cast<Map>())
        KgReporte(
          cultivo: k['cultivo'] as String,
          estado: k['estado'] as String,
          kg: (k['kg'] as num).toDouble(),
          kgEnLotes: (k['kgEnLotes'] as num).toDouble(),
          kgLibres: (k['kgLibres'] as num).toDouble(),
          kgExportables: (k['kgExportables'] as num).toDouble(),
          estadoExportable: k['estadoExportable'] as String,
          entregas: k['entregas'] as int,
        ),
    ],
    lotes: (
      abiertos: (j['lotes'] as Map)['abiertos'] as int,
      cerrados: (j['lotes'] as Map)['cerrados'] as int,
      vendidos: (j['lotes'] as Map)['vendidos'] as int,
      enContenedor: (j['lotes'] as Map)['enContenedor'] as int,
    ),
  );

  final String temporadaNombre;
  final ResumenReporte resumen;

  /// Fincas por estado satelital: verde, amarillo, rojo, pendiente.
  final Map<String, int> satelite;

  /// Fincas en rojo, amarillo o sin chequeo, las más graves primero.
  final List<FincaReporte> alertas;
  final List<({String nombre, String productorNombre, String? comunidad})>
  sinVisita;

  /// Visitas por persona; `email` es `null` si ya no está en el equipo.
  final List<({String? email, int visitas})> visitas;
  final List<KgReporte> kg;
  final ({int abiertos, int cerrados, int vendidos, int enContenedor}) lotes;
}

class ResumenReporte {
  ResumenReporte.desdeJson(Map<String, dynamic> j)
    : productores = j['productores'] as int,
      fincas = j['fincas'] as int,
      areaOficialHa = (j['areaOficialHa'] as num).toDouble(),
      conVisita = j['conVisita'] as int,
      porcentajeVisita = j['porcentajeVisita'] as int,
      verdes = j['verdes'] as int,
      porcentajeVerde = j['porcentajeVerde'] as int,
      kgEntregados = (j['kgEntregados'] as num).toDouble(),
      entregas = j['entregas'] as int;

  final int productores;
  final int fincas;
  final double areaOficialHa;
  final int conVisita;
  final int porcentajeVisita;
  final int verdes;
  final int porcentajeVerde;
  final double kgEntregados;
  final int entregas;
}

class FincaReporte {
  FincaReporte.desdeJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      nombre = j['nombre'] as String,
      productorNombre = j['productorNombre'] as String,
      comunidad = j['comunidad'] as String?,
      puntos = puntosDeGeoJson(j['geometria'] as Map<String, dynamic>),
      areaOficialHa = (j['areaOficialHa'] as num).toDouble(),
      deforestacion = j['deforestacion'] as String,
      ultimoChequeo = j['ultimoChequeo'] == null
          ? null
          : DateTime.parse(j['ultimoChequeo'] as String).toLocal(),
      fuente = j['fuente'] as String?,
      areaAfectadaHa = (j['areaAfectadaHa'] as num?)?.toDouble(),
      conVisita = j['conVisita'] as bool;

  final String id;
  final String nombre;
  final String productorNombre;
  final String? comunidad;
  final List<LatLng> puntos;
  final double areaOficialHa;
  final String deforestacion;
  final DateTime? ultimoChequeo;
  final String? fuente;
  final double? areaAfectadaHa;
  final bool conVisita;
}

class KgReporte {
  KgReporte({
    required this.cultivo,
    required this.estado,
    required this.kg,
    required this.kgEnLotes,
    required this.kgLibres,
    required this.kgExportables,
    required this.estadoExportable,
    required this.entregas,
  });

  final String cultivo;
  final String estado;
  final double kg;
  final double kgEnLotes;
  final double kgLibres;

  /// Equivalente en [estadoExportable] (café oro, cacao seco).
  final double kgExportables;
  final String estadoExportable;
  final int entregas;
}
