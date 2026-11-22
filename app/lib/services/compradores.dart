import 'package:latlong2/latlong.dart';

import 'red_proveedores.dart' show puntosDeGeoJson;

/// Vínculo exportadora → importador (portal del comprador).
class Comprador {
  Comprador.desdeJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      soyExportadora = j['soy'] == 'exportadora',
      organizacion = (j['organizacion'] as Map)['nombre'] as String,
      estado = j['estado'] as String,
      contenedores = j['contenedores'] as int;

  final String id;
  final bool soyExportadora;

  /// La otra organización.
  final String organizacion;
  final String estado;
  final int contenedores;

  bool get activo => estado == 'activo';
  bool get pendiente => estado == 'pendiente';
}

/// Contenedor comprado, como lo ve el importador.
class ContenedorComprado {
  ContenedorComprado.desdeJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      codigo = j['codigo'] as String,
      contenedor = j['contenedor'] as String?,
      exportadora = j['exportadora'] as String,
      cultivo = j['cultivo'] as String,
      destino = j['destino'] as String,
      kg = (j['kg'] as num).toDouble(),
      attestationUid = j['attestationUid'] as String?,
      ddsRef = j['ddsRef'] as String?,
      fincas = j['fincas'] as int,
      fincasVerdes = j['fincasVerdes'] as int,
      alertas = j['alertas'] as int;

  final String id;
  final String codigo;
  final String? contenedor;
  final String exportadora;
  final String cultivo;
  final String destino;
  final double kg;
  final String? attestationUid;
  final String? ddsRef;
  final int fincas;
  final int fincasVerdes;
  final int alertas;
}

/// Finca de origen de un contenedor comprado (sin nombres).
class FincaComprada {
  FincaComprada.desdeJson(Map<String, dynamic> j)
    : nombre = j['nombre'] as String,
      proveedor = j['proveedor'] as String?,
      puntos = puntosDeGeoJson(j['geometria'] as Map<String, dynamic>),
      areaOficialHa = (j['areaOficialHa'] as num).toDouble(),
      deforestacion = j['deforestacion'] as String,
      ultimoChequeo = j['ultimoChequeo'] == null
          ? null
          : DateTime.parse(j['ultimoChequeo'] as String).toLocal();

  final String nombre;
  final String? proveedor;
  final List<LatLng> puntos;
  final double areaOficialHa;
  final String deforestacion;
  final DateTime? ultimoChequeo;
}

class AlertaComprador {
  AlertaComprador.desdeJson(Map<String, dynamic> j)
    : contenedor = j['contenedor'] as String,
      codigo = j['codigo'] as String,
      finca = j['finca'] as String,
      resultado = j['resultado'] as String,
      detectadaEn = DateTime.parse(j['detectadaEn'] as String).toLocal();

  final String contenedor;
  final String codigo;
  final String finca;
  final String resultado;
  final DateTime detectadaEn;
}
