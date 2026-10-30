import 'dart:convert';

import 'package:http/http.dart' as http;

import 'red_proveedores.dart';

export 'red_proveedores.dart';

/// URL de la API. En el emulador de Android, 10.0.2.2 es el localhost de la
/// computadora. Para Cloud Run: `flutter run --dart-define=API_URL=https://...`
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

/// Lo que escribió un productor en la página de eliminación de datos.
class SolicitudEliminacion {
  SolicitudEliminacion({
    required this.id,
    required this.nombre,
    required this.contacto,
    required this.creadaEn,
    this.cedula,
    this.comunidad,
    this.mensaje,
  });

  factory SolicitudEliminacion.desdeJson(Map<String, dynamic> j) =>
      SolicitudEliminacion(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        cedula: j['cedula'] as String?,
        comunidad: j['comunidad'] as String?,
        contacto: j['contacto'] as String,
        mensaje: j['mensaje'] as String?,
        creadaEn: DateTime.parse(j['creadaEn'] as String).toLocal(),
      );

  final String id;
  final String nombre;
  final String? cedula;
  final String? comunidad;
  final String contacto;
  final String? mensaje;
  final DateTime creadaEn;
}

/// Qué pasó al eliminar a un productor.
class ResumenEliminacion {
  ResumenEliminacion({
    required this.anonimizado,
    required this.fincasBorradas,
    required this.fincasConservadas,
    this.conservarHasta,
  });

  factory ResumenEliminacion.desdeJson(Map<String, dynamic> j) =>
      ResumenEliminacion(
        anonimizado: j['productor'] == 'anonimizado',
        fincasBorradas: j['fincasBorradas'] as int,
        fincasConservadas: j['fincasConservadas'] as int,
        conservarHasta: j['conservarHasta'] == null
            ? null
            : DateTime.parse(j['conservarHasta'] as String),
      );

  /// `true` si quedan fincas sin datos personales que el EUDR obliga a guardar.
  final bool anonimizado;
  final int fincasBorradas;
  final int fincasConservadas;
  final DateTime? conservarHasta;
}

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

  /// Alias ("Finca 3F2A") en un lote comprado si la proveedora no comparte nombres.
  final String fincaNombre;

  /// `null` en un lote comprado si la proveedora no comparte nombres.
  final String? productorNombre;
  final double kg;
  final String estado;
  final DateTime fecha;
}

/// Venta de un lote a una exportadora (o compra, en un lote recibido).
class VentaLote {
  VentaLote({
    required this.vinculoId,
    required this.cliente,
    required this.recibido,
    required this.kgEnviados,
    required this.fechaEnvio,
    required this.kgRecibidos,
    required this.fechaRecibido,
    required this.enContenedor,
  });

  factory VentaLote.desdeJson(Map<String, dynamic> j) => VentaLote(
    vinculoId: j['vinculoId'] as String,
    cliente: j['cliente'] as String,
    recibido: j['estado'] == 'recibido',
    kgEnviados: (j['kgEnviados'] as num).toDouble(),
    fechaEnvio: DateTime.parse(j['fechaEnvio'] as String),
    kgRecibidos: (j['kgRecibidos'] as num?)?.toDouble(),
    fechaRecibido: j['fechaRecibido'] == null
        ? null
        : DateTime.parse(j['fechaRecibido'] as String),
    enContenedor: j['enContenedor'] as bool? ?? false,
  );

  final String vinculoId;
  final String cliente;
  final bool recibido;
  final double kgEnviados;
  final DateTime fechaEnvio;
  final double? kgRecibidos;
  final DateTime? fechaRecibido;

  /// Ya va en un contenedor de la exportadora: la venta no se deshace.
  final bool enContenedor;
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
    required this.attestationUid,
    required this.creadoEn,
    required this.entregas,
    this.exportacionCodigo,
    this.proveedor,
    this.venta,
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
    attestationUid: j['attestationUid'] as String?,
    exportacionCodigo: j['exportacionCodigo'] as String?,
    proveedor: j['proveedor'] as String?,
    venta: j['venta'] == null
        ? null
        : VentaLote.desdeJson(j['venta'] as Map<String, dynamic>),
    creadoEn: DateTime.parse(j['creadoEn'] as String).toLocal(),
    entregas: [
      for (final e in (j['entregas'] as List? ?? const []).cast<Map>())
        EntregaDeLote(
          fincaNombre: e['fincaNombre'] as String,
          productorNombre: e['productorNombre'] as String?,
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

  /// UID de su attestation: el QR del saco apunta a ella.
  final String? attestationUid;

  /// Ya está en la blockchain: no se puede deshacer.
  bool get atestado => attestationUid != null;

  /// Contenedor (de esta organización) en que va, o `null` si está libre.
  final String? exportacionCodigo;

  /// Lote comprado: la organización que lo vendió; `null` si es propio.
  final String? proveedor;

  /// Venta a una exportadora (en un lote propio) o compra (en uno comprado).
  final VentaLote? venta;

  /// Propio y vendido a otra organización: ya no se corrige ni se pone en
  /// un contenedor propio.
  bool get vendido => proveedor == null && venta != null;

  /// Kg con que cuenta en un contenedor: los recibidos si se compró.
  double get kgEnContenedor =>
      proveedor != null ? venta?.kgRecibidos ?? kg : kg;
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
    required this.attestationUid,
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
      attestationUid: j['attestationUid'] as String?,
      kg: (j['kg'] as num).toDouble(),
      lotes: [
        for (final l in (j['lotes'] as List).cast<Map>())
          (
            codigo: l['codigo'] as String,
            kg: (l['kg'] as num).toDouble(),
            estado: l['estado'] as String,
            temporada: l['temporadaNombre'] as String,
            proveedor: l['proveedor'] as String?,
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

  /// UID de su attestation: el QR del verificador apunta a ella.
  final String? attestationUid;

  /// Ya está en la blockchain: ni la DDS se puede cambiar.
  bool get atestada => attestationUid != null;
  final double kg;

  /// `proveedor`: el lote se compró a otra organización.
  final List<
    ({
      String codigo,
      double kg,
      String estado,
      String temporada,
      String? proveedor,
    })
  >
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
      _pedirJson('POST', '/v1/sync', payload, reintentable: true);

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
  Future<Map<String, dynamic>> chequearFinca(String fincaId) => _pedirJson(
    'POST',
    '/v1/fincas/${Uri.encodeComponent(fincaId)}/chequeo',
    const <String, dynamic>{},
    reintentable: true,
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
  Future<void> confirmarFoto(String fotoId) => _pedirJson(
    'POST',
    '/v1/fotos/${Uri.encodeComponent(fotoId)}/subida',
    const <String, dynamic>{},
    reintentable: true,
  );

  /// Activa la invitación del correo con el que se inició sesión. Lleva `{}`
  /// porque el frontal de Cloud Run rechaza POST sin cuerpo (411).
  Future<void> activar() => _pedirJson(
    'POST',
    '/v1/activar',
    const <String, dynamic>{},
    reintentable: true,
  );

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

  // Correcciones (plan de correcciones): solo mientras el dato no esté en un
  // lote, en un contenedor o firmado. Los kg, áreas y fechas llevan motivo.

  /// Corrige kg, estado o fecha de una entrega ya enviada. Devuelve la
  /// entrega como quedó (la temporada puede cambiar con la fecha).
  Future<Map<String, dynamic>> corregirEntrega(
    String id,
    Map<String, Object?> cambios,
  ) => _pedir('PATCH', '/v1/entregas/${Uri.encodeComponent(id)}', cambios);

  /// Anula una entrega ya enviada. No se repite sola si se corta la conexión.
  Future<void> anularEntrega(String id, String motivo) => _pedirJson(
    'POST',
    '/v1/entregas/${Uri.encodeComponent(id)}/anular',
    {'motivo': motivo},
    reintentable: false,
  );

  /// Corrige peso, código, beneficio o proceso de un lote (administradores).
  Future<Lote> corregirLote(String id, Map<String, Object?> cambios) async =>
      Lote.desdeJson(
        await _pedir('PATCH', '/v1/lotes/${Uri.encodeComponent(id)}', cambios),
      );

  Future<void> corregirProductor(String id, Map<String, Object?> cambios) =>
      _pedir('PATCH', '/v1/productores/${Uri.encodeComponent(id)}', cambios);

  /// Nombre de la finca y, en las de un punto, el área declarada.
  Future<void> corregirFinca(String id, Map<String, Object?> cambios) =>
      _pedir('PATCH', '/v1/fincas/${Uri.encodeComponent(id)}', cambios);

  /// Quita una foto equivocada (y su archivo en Storage).
  Future<void> eliminarFoto(String id) => _pedirJson(
    'DELETE',
    '/v1/fotos/${Uri.encodeComponent(id)}',
    null,
    reintentable: false,
  );

  Future<void> corregirVisita(String id, Map<String, Object?> cambios) =>
      _pedir('PATCH', '/v1/verificaciones/${Uri.encodeComponent(id)}', cambios);

  Future<void> anularVisita(String id, String motivo) => _pedirJson(
    'POST',
    '/v1/verificaciones/${Uri.encodeComponent(id)}/anular',
    {'motivo': motivo},
    reintentable: false,
  );

  /// Nombre o fechas de una temporada (administradores). Las fechas solo si
  /// no tiene lotes; las entregas y visitas se reasignan solas.
  Future<void> corregirTemporada(String id, Map<String, Object?> cambios) =>
      _pedir('PATCH', '/v1/temporadas/${Uri.encodeComponent(id)}', cambios);

  Future<void> eliminarTemporada(String id) => _pedirJson(
    'DELETE',
    '/v1/temporadas/${Uri.encodeComponent(id)}',
    null,
    reintentable: false,
  );

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

  // Red de proveedores (Fase 2b).

  /// Exportadora: sus proveedoras y los lotes que le enviaron sin recibir.
  Future<({List<Vinculo> proveedores, List<LotePorRecibir> porRecibir})>
  proveedores() async {
    final r = await _pedir('GET', '/v1/proveedores');
    return (
      proveedores: [
        for (final v in (r['proveedores'] as List).cast<Map<String, dynamic>>())
          Vinculo.desdeJson(v),
      ],
      porRecibir: [
        for (final l in (r['porRecibir'] as List).cast<Map<String, dynamic>>())
          LotePorRecibir.desdeJson(l),
      ],
    );
  }

  /// Invita a la organización del administrador con ese correo.
  Future<void> invitarProveedor(String email) =>
      _pedir('POST', '/v1/proveedores', {'email': email});

  /// Termina el vínculo con una proveedora (o cancela la invitación).
  Future<void> terminarProveedor(String id) =>
      _pedir('DELETE', '/v1/proveedores/${Uri.encodeComponent(id)}');

  /// Confirma los kg recibidos; devuelve el aviso si no coinciden.
  Future<AvisoLote?> recibirLote(
    String loteId, {
    required double kg,
    required DateTime fecha,
  }) async {
    final r = await _pedirJson(
      'POST',
      '/v1/proveedores/lotes/${Uri.encodeComponent(loteId)}/recibir',
      {'kgRecibidos': kg, 'fecha': _dia(fecha)},
      reintentable: true,
    );
    final a = r['aviso'] as Map?;
    return a == null
        ? null
        : AvisoLote(a['codigo'] as String, a['mensaje'] as String);
  }

  Future<RevisionProveedor> revisionProveedor(String id) async =>
      RevisionProveedor.desdeJson(
        await _pedir(
          'GET',
          '/v1/proveedores/${Uri.encodeComponent(id)}/revision',
        ),
      );

  /// Cooperativa: sus clientes, con las invitaciones por responder.
  Future<List<Vinculo>> clientes() async {
    final r = await _pedir('GET', '/v1/clientes');
    return [
      for (final v in (r['clientes'] as List).cast<Map<String, dynamic>>())
        Vinculo.desdeJson(v),
    ];
  }

  Future<void> responderCliente(
    String id, {
    required bool aceptar,
    bool comparteNombres = false,
  }) => _pedir(
    'POST',
    '/v1/clientes/${Uri.encodeComponent(id)}/${aceptar ? 'aceptar' : 'rechazar'}',
    {if (aceptar) 'comparteNombres': comparteNombres},
  );

  Future<void> compartirNombres(String id, bool comparte) => _pedir(
    'PATCH',
    '/v1/clientes/${Uri.encodeComponent(id)}',
    {'comparteNombres': comparte},
  );

  Future<void> terminarCliente(String id) =>
      _pedir('DELETE', '/v1/clientes/${Uri.encodeComponent(id)}');

  /// Vende el lote a un cliente activo; devuelve el lote actualizado.
  Future<Lote> venderLote(
    String loteId, {
    required String vinculoId,
    required double kg,
    required DateTime fecha,
  }) async => Lote.desdeJson(
    await _pedir('POST', '/v1/lotes/${Uri.encodeComponent(loteId)}/venta', {
      'vinculoId': vinculoId,
      'kg': kg,
      'fecha': _dia(fecha),
    }),
  );

  Future<void> deshacerVenta(String loteId) =>
      _pedir('DELETE', '/v1/lotes/${Uri.encodeComponent(loteId)}/venta');

  Future<List<Observacion>> observaciones() async {
    final r = await _pedir('GET', '/v1/observaciones');
    return [
      for (final o in (r['observaciones'] as List).cast<Map<String, dynamic>>())
        Observacion.desdeJson(o),
    ];
  }

  /// La exportadora observa una finca o un lote de su proveedora.
  Future<void> observar({
    String? fincaId,
    String? loteId,
    required String texto,
  }) => _pedir('POST', '/v1/observaciones', {
    'fincaId': ?fincaId,
    'loteId': ?loteId,
    'texto': texto,
  });

  Future<void> responderObservacion(String id, String texto) => _pedir(
    'POST',
    '/v1/observaciones/${Uri.encodeComponent(id)}/respuesta',
    {'texto': texto},
  );

  Future<AvisosRed> avisosRed() async =>
      AvisosRed.desdeJson(await _pedir('GET', '/v1/red/avisos'));

  /// Día local como AAAA-MM-DD.
  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Solicitudes de productores que pidieron borrar sus datos (administradores).
  Future<List<SolicitudEliminacion>> solicitudesEliminacion() async {
    final r = await _pedir('GET', '/v1/solicitudes-eliminacion');
    return [
      for (final s in r['solicitudes'] as List)
        SolicitudEliminacion.desdeJson(s as Map<String, dynamic>),
    ];
  }

  /// Aprueba la solicitud: elimina (o anonimiza) al [productorId] elegido.
  Future<ResumenEliminacion> aprobarSolicitud(
    String id,
    String productorId,
  ) async => ResumenEliminacion.desdeJson(
    await _pedir(
      'POST',
      '/v1/solicitudes-eliminacion/${Uri.encodeComponent(id)}/aprobar',
      {'productorId': productorId},
    ),
  );

  Future<void> rechazarSolicitud(String id, String motivo) => _pedir(
    'POST',
    '/v1/solicitudes-eliminacion/${Uri.encodeComponent(id)}/rechazar',
    {'motivo': motivo},
  );

  /// Elimina los datos de un productor que lo pidió en persona (administradores).
  Future<ResumenEliminacion> eliminarProductor(
    String id, {
    String? motivo,
  }) async => ResumenEliminacion.desdeJson(
    await _pedir('DELETE', '/v1/productores/${Uri.encodeComponent(id)}', {
      'motivo': ?motivo,
    }),
  );

  /// Elimina la cuenta de quien inició sesión (y su acceso a la organización).
  Future<void> eliminarCuenta() => _pedir('DELETE', '/v1/cuenta');

  /// Programa la eliminación de la organización; devuelve cuándo se ejecuta.
  Future<DateTime> programarEliminacionOrganizacion() async {
    final r = await _pedir(
      'POST',
      '/v1/organizacion/eliminacion',
      const <String, dynamic>{},
    );
    return DateTime.parse(r['eliminacionProgramada'] as String).toLocal();
  }

  Future<void> cancelarEliminacionOrganizacion() =>
      _pedir('DELETE', '/v1/organizacion/eliminacion');

  /// Envía la petición. Si la conexión se cae antes de llegar la respuesta
  /// (p. ej. "Connection closed before full header was received": el celular
  /// reusó una conexión que ya se cerraba, o la señal parpadeó), la repite una
  /// vez, pero solo si repetirla no tiene efectos dobles ([reintentable]).
  Future<http.Response> _enviar(
    http.Request Function() crear, {
    required bool reintentable,
  }) async {
    for (var intento = 1; ; intento++) {
      try {
        return await http.Response.fromStream(await _cliente.send(crear()));
      } on http.ClientException {
        if (reintentable && intento == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          continue;
        }
        throw ApiError(
          0,
          'Se cortó la conexión con el servidor antes de recibir la respuesta; '
          'la acción pudo haberse hecho. Revisa la señal y vuelve a intentar.',
        );
      }
    }
  }

  /// GET de un archivo (PDF, GeoJSON): devuelve los bytes tal cual.
  Future<List<int>> _descargar(String ruta) async {
    final t = await token();
    if (t == null) throw ApiError(401, 'Inicia sesión para continuar.');
    final res = await _enviar(
      () =>
          http.Request('GET', _base.resolve(ruta))
            ..headers['Authorization'] = 'Bearer $t',
      reintentable: true,
    );
    if (res.statusCode >= 300) {
      final json = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiError(res.statusCode, _mensaje(res.statusCode, json));
    }
    return res.bodyBytes;
  }

  /// [reintentable]: se puede repetir sin efectos dobles. Por defecto, las
  /// lecturas y ediciones (GET, PUT, PATCH); un POST o DELETE solo si se indica
  /// (crear un lote dos veces daría "ya existe", y borrar dos veces, 404).
  Future<Map<String, dynamic>> _pedir(
    String metodo,
    String ruta, [
    Object? cuerpo,
  ]) => _pedirJson(
    metodo,
    ruta,
    cuerpo,
    reintentable: const {'GET', 'PUT', 'PATCH'}.contains(metodo),
  );

  Future<Map<String, dynamic>> _pedirJson(
    String metodo,
    String ruta,
    Object? cuerpo, {
    required bool reintentable,
  }) async {
    final t = await token();
    if (t == null) throw ApiError(401, 'Inicia sesión para continuar.');

    http.Request crear() {
      final req = http.Request(metodo, _base.resolve(ruta))
        ..headers['Authorization'] = 'Bearer $t';
      if (cuerpo != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(cuerpo);
      }
      return req;
    }

    final res = await _enviar(crear, reintentable: reintentable);
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
      404 => propio ?? 'No encontrado.',
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
