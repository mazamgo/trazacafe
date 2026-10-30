import 'package:latlong2/latlong.dart';

import 'api_client.dart' show AvisoLote;

/// Red de proveedores (Fase 2b): la exportadora invita a las cooperativas que
/// le venden, la cooperativa le vende lotes y la exportadora los recibe y los
/// pone en sus contenedores. Todo es en línea y solo de administradores.

/// Tipos de organización que compran lotes (invitan proveedores).
const tiposCliente = {'exportadora', 'beneficio'};

/// Tipos que venden lotes a otras (tienen clientes).
const tiposProveedora = {'cooperativa', 'beneficio', 'otra'};

/// Vínculo entre una proveedora (cooperativa) y su cliente (exportadora).
class Vinculo {
  Vinculo({
    required this.id,
    required this.soyCliente,
    required this.organizacion,
    required this.estado,
    required this.comparteNombres,
    required this.invitadoEn,
    required this.lotesEnviados,
    required this.lotesRecibidos,
  });

  factory Vinculo.desdeJson(Map<String, dynamic> j) => Vinculo(
    id: j['id'] as String,
    soyCliente: j['soy'] == 'cliente',
    organizacion: (j['organizacion'] as Map)['nombre'] as String,
    estado: j['estado'] as String,
    comparteNombres: j['comparteNombres'] as bool,
    invitadoEn: DateTime.parse(j['invitadoEn'] as String).toLocal(),
    lotesEnviados: j['lotesEnviados'] as int,
    lotesRecibidos: j['lotesRecibidos'] as int,
  );

  final String id;

  /// `true` si la otra organización le vende a esta.
  final bool soyCliente;

  /// Nombre de la otra organización.
  final String organizacion;

  /// `pendiente`, `activo`, `rechazado` o `terminado`.
  final String estado;

  /// La proveedora comparte los nombres de fincas y productores (Ley 787).
  final bool comparteNombres;
  final DateTime invitadoEn;

  /// Enviados y todavía no recibidos.
  final int lotesEnviados;
  final int lotesRecibidos;

  bool get pendiente => estado == 'pendiente';
  bool get activo => estado == 'activo';
}

/// Lote que una proveedora le envió a la exportadora y falta recibir.
class LotePorRecibir {
  LotePorRecibir({
    required this.id,
    required this.codigo,
    required this.cultivo,
    required this.estado,
    required this.temporadaNombre,
    required this.proveedor,
    required this.kgEnviados,
    required this.fechaEnvio,
  });

  factory LotePorRecibir.desdeJson(Map<String, dynamic> j) => LotePorRecibir(
    id: j['id'] as String,
    codigo: j['codigo'] as String,
    cultivo: j['cultivo'] as String,
    estado: j['estado'] as String,
    temporadaNombre: j['temporadaNombre'] as String,
    proveedor: j['proveedor'] as String,
    kgEnviados: (j['kgEnviados'] as num).toDouble(),
    fechaEnvio: DateTime.parse(j['fechaEnvio'] as String),
  );

  final String id;
  final String codigo;
  final String cultivo;
  final String estado;
  final String temporadaNombre;
  final String proveedor;
  final double kgEnviados;
  final DateTime fechaEnvio;
}

/// Finca de origen de los lotes de una proveedora, para la revisión.
class FincaRevisada {
  FincaRevisada({
    required this.id,
    required this.nombre,
    required this.productorNombre,
    required this.comunidad,
    required this.puntos,
    required this.areaOficialHa,
    required this.deforestacion,
    required this.ultimoChequeo,
    required this.conVisita,
    required this.ultimaVisita,
    required this.attestationUid,
    required this.lotes,
  });

  factory FincaRevisada.desdeJson(Map<String, dynamic> j) => FincaRevisada(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    productorNombre: j['productorNombre'] as String?,
    comunidad: j['comunidad'] as String?,
    puntos: puntosDeGeoJson(j['geometria'] as Map<String, dynamic>),
    areaOficialHa: (j['areaOficialHa'] as num).toDouble(),
    deforestacion: j['deforestacion'] as String,
    ultimoChequeo: _fecha(j['ultimoChequeo']),
    conVisita: j['conVisita'] as bool,
    ultimaVisita: _fecha(j['ultimaVisita']),
    attestationUid: j['attestationUid'] as String?,
    lotes: (j['lotes'] as List? ?? const []).cast<String>(),
  );

  final String id;

  /// Nombre, o alias ("Finca 3F2A") si la proveedora no comparte nombres.
  final String nombre;
  final String? productorNombre;
  final String? comunidad;

  /// Un punto (finca de menos de 4 ha) o el anillo del polígono.
  final List<LatLng> puntos;
  final double areaOficialHa;
  final String deforestacion;
  final DateTime? ultimoChequeo;

  /// Tiene visita de verificación en la temporada de sus lotes.
  final bool conVisita;
  final DateTime? ultimaVisita;
  final String? attestationUid;

  /// Códigos de los lotes vendidos en que va.
  final List<String> lotes;
}

class LoteRevisado {
  LoteRevisado({
    required this.id,
    required this.codigo,
    required this.temporadaNombre,
    required this.estado,
    required this.kgEnviados,
    required this.kgRecibidos,
    required this.recibido,
    required this.avisos,
    required this.attestationUid,
  });

  factory LoteRevisado.desdeJson(Map<String, dynamic> j) => LoteRevisado(
    id: j['id'] as String,
    codigo: j['codigo'] as String,
    temporadaNombre: j['temporadaNombre'] as String,
    estado: j['estado'] as String,
    kgEnviados: (j['kgEnviados'] as num).toDouble(),
    kgRecibidos: (j['kgRecibidos'] as num?)?.toDouble(),
    recibido: j['venta'] == 'recibido',
    avisos: [
      for (final a in (j['avisos'] as List? ?? const []).cast<Map>())
        AvisoLote(a['codigo'] as String, a['mensaje'] as String),
    ],
    attestationUid: j['attestationUid'] as String?,
  );

  final String id;
  final String codigo;
  final String temporadaNombre;
  final String estado;
  final double kgEnviados;
  final double? kgRecibidos;
  final bool recibido;
  final List<AvisoLote> avisos;
  final String? attestationUid;
}

/// Lo que una proveedora le vendió a la exportadora, de solo lectura.
class RevisionProveedor {
  RevisionProveedor({
    required this.vinculo,
    required this.lotes,
    required this.fincas,
    required this.verdes,
    required this.conVisita,
    required this.areaOficialHa,
  });

  factory RevisionProveedor.desdeJson(Map<String, dynamic> j) {
    final r = j['resumen'] as Map<String, dynamic>;
    return RevisionProveedor(
      vinculo: Vinculo.desdeJson(j['vinculo'] as Map<String, dynamic>),
      lotes: [
        for (final l in (j['lotes'] as List).cast<Map<String, dynamic>>())
          LoteRevisado.desdeJson(l),
      ],
      fincas: [
        for (final f in (j['fincas'] as List).cast<Map<String, dynamic>>())
          FincaRevisada.desdeJson(f),
      ],
      verdes: r['verdes'] as int,
      conVisita: r['conVisita'] as int,
      areaOficialHa: (r['areaOficialHa'] as num).toDouble(),
    );
  }

  final Vinculo vinculo;
  final List<LoteRevisado> lotes;
  final List<FincaRevisada> fincas;
  final int verdes;
  final int conVisita;
  final double areaOficialHa;
}

/// Observación de la exportadora sobre una finca o un lote de su proveedora.
class Observacion {
  Observacion({
    required this.id,
    required this.hecha,
    required this.cliente,
    required this.proveedora,
    required this.fincaNombre,
    required this.loteCodigo,
    required this.texto,
    required this.creadoEn,
    required this.respuesta,
  });

  factory Observacion.desdeJson(Map<String, dynamic> j) => Observacion(
    id: j['id'] as String,
    hecha: j['hecha'] as bool,
    cliente: j['cliente'] as String,
    proveedora: j['proveedora'] as String,
    fincaNombre: j['fincaNombre'] as String?,
    loteCodigo: j['loteCodigo'] as String?,
    texto: j['texto'] as String,
    creadoEn: DateTime.parse(j['creadoEn'] as String).toLocal(),
    respuesta: j['respuesta'] as String?,
  );

  final String id;

  /// La hizo esta organización (exportadora); si no, se la hicieron.
  final bool hecha;
  final String cliente;
  final String proveedora;
  final String? fincaNombre;
  final String? loteCodigo;
  final String texto;
  final DateTime creadoEn;
  final String? respuesta;

  /// "Finca El Roble" o "Lote CAFE-001".
  String get sobre => fincaNombre ?? 'Lote $loteCodigo';
}

/// Lo pendiente en la red, para los avisos de la pantalla de inicio.
class AvisosRed {
  AvisosRed({
    required this.invitaciones,
    required this.lotesPorRecibir,
    required this.observacionesSinResponder,
  });

  factory AvisosRed.desdeJson(Map<String, dynamic> j) => AvisosRed(
    invitaciones: [
      for (final i in (j['invitaciones'] as List).cast<Map>())
        i['organizacion'] as String,
    ],
    lotesPorRecibir: j['lotesPorRecibir'] as int,
    observacionesSinResponder: j['observacionesSinResponder'] as int,
  );

  /// Nombres de las exportadoras que invitaron a esta organización.
  final List<String> invitaciones;
  final int lotesPorRecibir;
  final int observacionesSinResponder;

  bool get vacio =>
      invitaciones.isEmpty &&
      lotesPorRecibir == 0 &&
      observacionesSinResponder == 0;
}

/// Puntos de una geometría GeoJSON: el punto, o el anillo exterior.
List<LatLng> puntosDeGeoJson(Map<String, dynamic> g) {
  LatLng punto(List c) =>
      LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
  final c = g['coordinates'] as List;
  return switch (g['type']) {
    'Point' => [punto(c)],
    'Polygon' => [for (final p in c.first as List) punto(p as List)],
    'MultiPolygon' => [
      for (final p in (c.first as List).first as List) punto(p as List),
    ],
    _ => const [],
  };
}

DateTime? _fecha(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();
