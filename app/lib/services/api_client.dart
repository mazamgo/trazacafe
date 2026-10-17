import 'dart:convert';

import 'package:http/http.dart' as http;

/// URL de la API. En el emulador de Android, 10.0.2.2 es el localhost de la
/// computadora. Para Cloud Run: `flutter run --dart-define=API_URL=https://...`
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

class Invitacion {
  Invitacion({required this.email, required this.rol, required this.activa});

  factory Invitacion.desdeJson(Map<String, dynamic> j) => Invitacion(
    email: j['email'] as String,
    rol: j['rol'] as String,
    activa: j['usuarioUid'] != null,
  );

  final String email;

  /// `admin` o `tecnico`.
  final String rol;

  /// `true` cuando la persona ya entró con Google y activó su acceso.
  final bool activa;
}

/// Entrega de la organización para armar un lote (`GET /v1/lotes/disponibles`).
class EntregaDisponible {
  EntregaDisponible({
    required this.id,
    required this.fincaNombre,
    required this.productorNombre,
    required this.kg,
    required this.estado,
    required this.fecha,
    required this.deforestacion,
    required this.motivo,
  });

  factory EntregaDisponible.desdeJson(Map<String, dynamic> j) =>
      EntregaDisponible(
        id: j['id'] as String,
        fincaNombre: j['fincaNombre'] as String,
        productorNombre: j['productorNombre'] as String,
        kg: (j['kg'] as num).toDouble(),
        estado: j['estado'] as String,
        fecha: DateTime.parse(j['fecha'] as String).toLocal(),
        deforestacion: j['deforestacion'] as String,
        motivo: j['motivo'] as String?,
      );

  final String id;
  final String fincaNombre;
  final String productorNombre;
  final double kg;
  final String estado;
  final DateTime fecha;
  final String deforestacion;

  /// Por qué no puede ir en el lote, o `null` si puede.
  final String? motivo;
}

/// Aviso guardado con un lote (volumen, rendimiento por ha, satélite).
class AvisoLote {
  AvisoLote(this.codigo, this.mensaje);
  final String codigo;
  final String mensaje;
}

/// Entrega dentro de un lote ya armado.
class EntregaDeLote {
  EntregaDeLote({
    required this.fincaNombre,
    required this.productorNombre,
    required this.kg,
    required this.estado,
    required this.fecha,
  });
  final String fincaNombre;
  final String productorNombre;
  final double kg;
  final String estado;
  final DateTime fecha;
}

class Lote {
  Lote({
    required this.id,
    required this.codigo,
    required this.cultivo,
    required this.temporadaNombre,
    required this.estado,
    required this.kg,
    required this.kgEsperados,
    required this.beneficio,
    required this.proceso,
    required this.avisos,
    required this.atestado,
    required this.creadoEn,
    required this.entregas,
    this.exportacionCodigo,
  });

  factory Lote.desdeJson(Map<String, dynamic> j) => Lote(
    id: j['id'] as String,
    codigo: j['codigo'] as String,
    cultivo: j['cultivo'] as String,
    temporadaNombre: j['temporadaNombre'] as String,
    estado: j['estado'] as String,
    kg: (j['kg'] as num).toDouble(),
    kgEsperados: (j['kgEsperados'] as num).toDouble(),
    beneficio: j['beneficio'] as String,
    proceso: j['proceso'] as String?,
    avisos: [
      for (final a in (j['avisos'] as List? ?? const []).cast<Map>())
        AvisoLote(a['codigo'] as String, a['mensaje'] as String),
    ],
    atestado: j['attestationUid'] != null,
    exportacionCodigo: j['exportacionCodigo'] as String?,
    creadoEn: DateTime.parse(j['creadoEn'] as String).toLocal(),
    entregas: [
      for (final e in (j['entregas'] as List? ?? const []).cast<Map>())
        EntregaDeLote(
          fincaNombre: e['fincaNombre'] as String,
          productorNombre: e['productorNombre'] as String,
          kg: (e['kg'] as num).toDouble(),
          estado: e['estado'] as String,
          fecha: DateTime.parse(e['fecha'] as String).toLocal(),
        ),
    ],
  );

  final String id;
  final String codigo;
  final String cultivo;
  final String temporadaNombre;
  final String estado;
  final double kg;

  /// Lo que deberían rendir sus entregas en [estado].
  final double kgEsperados;
  final String beneficio;
  final String? proceso;
  final List<AvisoLote> avisos;

  /// Ya está en la blockchain: no se puede deshacer.
  final bool atestado;

  /// Contenedor en que va, o `null` si está libre.
  final String? exportacionCodigo;
  final DateTime creadoEn;
  final List<EntregaDeLote> entregas;
}

/// Contenedor de exportación (`GET /v1/exportaciones`).
class Exportacion {
  Exportacion({
    required this.id,
    required this.codigo,
    required this.cultivo,
    required this.comprador,
    required this.destino,
    required this.contenedor,
    required this.fechaEmbarque,
    required this.ddsRef,
    required this.abierta,
    required this.atestada,
    required this.kg,
    required this.lotes,
    required this.entregas,
    required this.fincas,
    required this.areaOficialHa,
    required this.fincasSinVerde,
  });

  factory Exportacion.desdeJson(Map<String, dynamic> j) {
    final r = j['resumen'] as Map<String, dynamic>;
    return Exportacion(
      id: j['id'] as String,
      codigo: j['codigo'] as String,
      cultivo: j['cultivo'] as String,
      comprador: j['comprador'] as String,
      destino: j['destino'] as String,
      contenedor: j['contenedor'] as String?,
      fechaEmbarque: j['fechaEmbarque'] == null
          ? null
          : DateTime.parse(j['fechaEmbarque'] as String),
      ddsRef: j['ddsRef'] as String?,
      abierta: j['estado'] == 'abierta',
      atestada: j['attestationUid'] != null,
      kg: (j['kg'] as num).toDouble(),
      lotes: [
        for (final l in (j['lotes'] as List).cast<Map>())
          (
            codigo: l['codigo'] as String,
            kg: (l['kg'] as num).toDouble(),
            estado: l['estado'] as String,
            temporada: l['temporadaNombre'] as String,
          ),
      ],
      entregas: r['entregas'] as int,
      fincas: r['fincas'] as int,
      areaOficialHa: (r['areaOficialHa'] as num).toDouble(),
      fincasSinVerde: r['fincasSinVerde'] as int,
    );
  }

  final String id;
  final String codigo;
  final String cultivo;
  final String comprador;
  final String destino;

  /// Número ISO 6346; suele llegar después de armarlo.
  final String? contenedor;
  final DateTime? fechaEmbarque;

  /// Referencia de la declaración de diligencia debida en TRACES.
  final String? ddsRef;

  /// Abierta: se puede editar o deshacer.
  final bool abierta;

  /// Ya está en la blockchain: ni la DDS se puede cambiar.
  final bool atestada;
  final double kg;
  final List<({String codigo, double kg, String estado, String temporada})>
  lotes;
  final int entregas;
  final int fincas;
  final double areaOficialHa;

  /// Fincas de origen sin chequeo satelital verde (el paquete EUDR las pide).
  final int fincasSinVerde;
}

class ApiClient {
  ApiClient({
    required this.token,
    http.Client? cliente,
    String baseUrl = apiUrl,
  }) : _cliente = cliente ?? http.Client(),
       _base = Uri.parse(baseUrl);

  final Future<String?> Function() token;
  final http.Client _cliente;
  final Uri _base;

  /// Envía un lote de registros a `POST /v1/sync`.
  Future<Map<String, dynamic>> sync(Map<String, dynamic> payload) =>
      _pedir('POST', '/v1/sync', payload);

  /// Crea una temporada de cosecha (solo administradores). Fechas `AAAA-MM-DD`.
  /// Sin [cultivo], aplica a todos los cultivos de la organización.
  Future<void> crearTemporada(
    String nombre,
    String inicio,
    String fin, {
    String? cultivo,
  }) => _pedir('POST', '/v1/temporadas', {
    'nombre': nombre,
    'inicio': inicio,
    'fin': fin,
    'cultivo': ?cultivo,
  });

  /// Cambia los cultivos de la organización (solo administradores). La API
  /// no deja quitar uno que ya tiene fincas (409).
  Future<void> actualizarCultivos(List<String> cultivos) =>
      _pedir('PUT', '/v1/organizacion/cultivos', {'cultivos': cultivos});

  /// Revisa la finca por satélite ahora mismo (solo administradores).
  Future<Map<String, dynamic>> chequearFinca(String fincaId) => _pedir(
    'POST',
    '/v1/fincas/${Uri.encodeComponent(fincaId)}/chequeo',
    const <String, dynamic>{},
  );

  /// Cambia el cultivo de una finca ya enviada. La API lo rechaza (409) si
  /// la finca ya tiene entregas o está atestada.
  Future<void> cambiarCultivoFinca(String fincaId, String cultivo) => _pedir(
    'PUT',
    '/v1/fincas/${Uri.encodeComponent(fincaId)}/cultivo',
    {'cultivo': cultivo},
  );

  /// Productores, fincas y entregas de toda la organización.
  Future<Map<String, dynamic>> datos() => _pedir('GET', '/v1/datos');

  /// Pide a la API que compruebe el archivo de la foto ya subido a Storage.
  Future<void> confirmarFoto(String fotoId) => _pedir(
    'POST',
    '/v1/fotos/${Uri.encodeComponent(fotoId)}/subida',
    const <String, dynamic>{},
  );

  /// Activa la invitación del correo con el que se inició sesión. Lleva `{}`
  /// porque el frontal de Cloud Run rechaza POST sin cuerpo (411).
  Future<void> activar() =>
      _pedir('POST', '/v1/activar', const <String, dynamic>{});

  /// Borra en la API una finca que aún no se atestó. Si ya no existe allá, no
  /// es error: el objetivo es que desaparezca.
  Future<void> eliminarFinca(String id) async {
    try {
      await _pedir('DELETE', '/v1/fincas/${Uri.encodeComponent(id)}');
    } on ApiError catch (e) {
      if (e.status != 404) rethrow;
    }
  }

  /// Lotes de la organización (solo administradores).
  Future<List<Lote>> lotes() async {
    final r = await _pedir('GET', '/v1/lotes');
    return [
      for (final l in r['lotes'] as List)
        Lote.desdeJson(l as Map<String, dynamic>),
    ];
  }

  /// Entregas de un cultivo y temporada, con el motivo de las que no pueden
  /// ir en un lote.
  Future<List<EntregaDisponible>> entregasDisponibles(
    String cultivo,
    String temporadaId,
  ) async {
    final r = await _pedir(
      'GET',
      '/v1/lotes/disponibles?cultivo=${Uri.encodeQueryComponent(cultivo)}'
          '&temporadaId=${Uri.encodeQueryComponent(temporadaId)}',
    );
    return [
      for (final e in r['entregas'] as List)
        EntregaDisponible.desdeJson(e as Map<String, dynamic>),
    ];
  }

  /// Arma un lote. La API lo rechaza (422) si alguna entrega no cumple las
  /// reglas EUDR; los avisos vienen en el lote creado.
  Future<Lote> crearLote({
    required String codigo,
    required String cultivo,
    required String temporadaId,
    required String estado,
    required double kg,
    required List<String> entregas,
    String? beneficio,
    String? proceso,
  }) async => Lote.desdeJson(
    await _pedir('POST', '/v1/lotes', {
      'codigo': codigo,
      'cultivo': cultivo,
      'temporadaId': temporadaId,
      'estado': estado,
      'kg': kg,
      'entregas': entregas,
      'beneficio': ?beneficio,
      'proceso': ?proceso,
    }),
  );

  /// Deshace un lote que aún no está en la blockchain.
  Future<void> eliminarLote(String id) =>
      _pedir('DELETE', '/v1/lotes/${Uri.encodeComponent(id)}');

  /// Contenedores de la organización (solo administradores).
  Future<List<Exportacion>> exportaciones() async {
    final r = await _pedir('GET', '/v1/exportaciones');
    return [
      for (final x in r['exportaciones'] as List)
        Exportacion.desdeJson(x as Map<String, dynamic>),
    ];
  }

  /// Arma un contenedor con lotes de un mismo cultivo.
  Future<Exportacion> crearExportacion({
    required String codigo,
    required String comprador,
    required String destino,
    required List<String> lotes,
    String? contenedor,
    String? fechaEmbarque,
  }) async => Exportacion.desdeJson(
    await _pedir('POST', '/v1/exportaciones', {
      'codigo': codigo,
      'comprador': comprador,
      'destino': destino,
      'lotes': lotes,
      'contenedor': ?contenedor,
      'fechaEmbarque': ?fechaEmbarque,
    }),
  );

  /// Corrige o completa datos de un contenedor abierto. Un valor `null` en
  /// [cambios] borra ese dato.
  Future<Exportacion> cambiarExportacion(
    String id,
    Map<String, Object?> cambios,
  ) async => Exportacion.desdeJson(
    await _pedir(
      'PATCH',
      '/v1/exportaciones/${Uri.encodeComponent(id)}',
      cambios,
    ),
  );

  /// Cierra el paquete EUDR. La API responde 409 con los motivos si falta
  /// el número de contenedor o hay fincas sin chequeo satelital verde.
  Future<Exportacion> cerrarExportacion(String id) async =>
      Exportacion.desdeJson(
        await _pedir(
          'POST',
          '/v1/exportaciones/${Uri.encodeComponent(id)}/cerrar',
          const <String, dynamic>{},
        ),
      );

  /// GeoJSON de las fincas de origen para la DDS en TRACES. Los nombres de
  /// los productores (datos personales) solo van si [conProductores].
  Future<List<int>> geojsonExportacion(
    String id, {
    bool conProductores = false,
  }) => _descargar(
    '/v1/exportaciones/${Uri.encodeComponent(id)}/geojson'
    '${conProductores ? '?productores=1' : ''}',
  );

  /// PDF del paquete EUDR para el comprador.
  Future<List<int>> pdfExportacion(String id) =>
      _descargar('/v1/exportaciones/${Uri.encodeComponent(id)}/pdf');

  /// Deshace un contenedor abierto; sus lotes quedan libres.
  Future<void> eliminarExportacion(String id) =>
      _pedir('DELETE', '/v1/exportaciones/${Uri.encodeComponent(id)}');

  Future<List<Invitacion>> invitaciones() async {
    final r = await _pedir('GET', '/v1/invitaciones');
    return [
      for (final i in r['invitaciones'] as List)
        Invitacion.desdeJson(i as Map<String, dynamic>),
    ];
  }

  Future<void> invitar(String email, String rol) =>
      _pedir('POST', '/v1/invitaciones', {'email': email, 'rol': rol});

  Future<void> quitarAcceso(String email) =>
      _pedir('DELETE', '/v1/invitaciones/${Uri.encodeComponent(email)}');

  /// GET de un archivo (PDF, GeoJSON): devuelve los bytes tal cual.
  Future<List<int>> _descargar(String ruta) async {
    final t = await token();
    if (t == null) throw ApiError(401, 'Inicia sesión para continuar.');
    final req = http.Request('GET', _base.resolve(ruta))
      ..headers['Authorization'] = 'Bearer $t';
    final res = await http.Response.fromStream(await _cliente.send(req));
    if (res.statusCode >= 300) {
      final json = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiError(res.statusCode, _mensaje(res.statusCode, json));
    }
    return res.bodyBytes;
  }

  Future<Map<String, dynamic>> _pedir(
    String metodo,
    String ruta, [
    Object? cuerpo,
  ]) async {
    final t = await token();
    if (t == null) throw ApiError(401, 'Inicia sesión para continuar.');

    final req = http.Request(metodo, _base.resolve(ruta))
      ..headers['Authorization'] = 'Bearer $t';
    if (cuerpo != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(cuerpo);
    }
    final res = await http.Response.fromStream(await _cliente.send(req));
    final json = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 300) {
      throw ApiError(res.statusCode, _mensaje(res.statusCode, json));
    }
    return json;
  }

  static String _mensaje(int status, Map<String, dynamic> cuerpo) {
    final propio = cuerpo['mensaje'] as String?;
    final detalles = (cuerpo['detalles'] as List?)
        ?.map((d) => (d as Map)['message'])
        .whereType<String>()
        .toSet()
        .join('; ');
    return switch (status) {
      401 => 'La sesión venció. Vuelve a iniciar sesión.',
      403 || 409 => propio ?? cuerpo['error'] as String? ?? 'Sin permiso.',
      404 => 'No encontrado.',
      422 => propio ?? 'Datos rechazados: ${detalles ?? cuerpo['error']}',
      _ => 'Error del servidor ($status).',
    };
  }
}

class ApiError implements Exception {
  ApiError(this.status, this.mensaje);
  final int status;
  final String mensaje;

  @override
  String toString() => mensaje;
}
