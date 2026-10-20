import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_client.dart' show apiUrl;

/// Página pública del verificador (Firebase Hosting). El QR lleva
/// `$verificadorUrl/v/{uid}`.
const verificadorUrl = String.fromEnvironment(
  'VERIFICADOR_URL',
  defaultValue: 'https://trazacafe-dev.web.app',
);

String enlaceVerificador(String uid) => '$verificadorUrl/v/$uid';

/// Red de EAS donde se firma (`EAS_RED`, como en la API).
class RedEas {
  const RedEas({
    required this.nombre,
    required this.rpc,
    required this.explorador,
    required this.dePrueba,
  });

  final String nombre;
  final String rpc;
  final String explorador;

  /// OP Sepolia: red de pruebas, sin valor legal todavía.
  final bool dePrueba;

  static const sepolia = RedEas(
    nombre: 'OP Sepolia',
    rpc: 'https://sepolia.optimism.io',
    explorador: 'https://optimism-sepolia.easscan.org',
    dePrueba: true,
  );
  static const mainnet = RedEas(
    nombre: 'OP Mainnet',
    rpc: 'https://mainnet.optimism.io',
    explorador: 'https://optimism.easscan.org',
    dePrueba: false,
  );

  static const actual =
      String.fromEnvironment('EAS_RED', defaultValue: 'optimism-sepolia') ==
          'optimism'
      ? mainnet
      : sepolia;

  String attestation(String uid) => '$explorador/attestation/view/$uid';
}

/// Contrato de EAS (predeploy del OP Stack).
const easAddress = '0x4200000000000000000000000000000000000021';

/// Dirección de la clave de Cloud KMS que firma todas las attestations de
/// TrazaCafé. Va fija en la página: si la API mintiera, la firma no
/// coincidiría.
const atestadorOficial = '0xbfc2333a01536edfdb3e6ab987c544cdeac8cb99';

/// UIDs de los esquemas (`schemas/schemas.json`, iguales en todas las redes).
const esquemaUid = {
  'Exportacion':
      '0xfb1981ed1027dd1c46f750ca0147f5f2fe3187a684a8473a6744dfb7f10a260a',
  'Lote': '0x83d740de1bca1fc94b25ffa7c4a2edc0fbeaf7ec40a5c4b55e2586a28e2d5fda',
};

/// Una attestation según la API: UID, transacción y cuándo se firmó.
class Firma {
  Firma({required this.uid, this.txHash, this.firmadaEn});

  static Firma? desdeJson(Object? j) {
    if (j is! Map || j['uid'] == null) return null;
    return Firma(
      uid: j['uid'] as String,
      txHash: j['txHash'] as String?,
      firmadaEn: _fecha(j['firmadaEn']),
    );
  }

  final String uid;
  final String? txHash;
  final DateTime? firmadaEn;
}

DateTime? _fecha(Object? v) => v == null ? null : DateTime.parse(v as String);
double _num(Object? v) => (v as num).toDouble();

/// Lo que devuelve `GET /v1/publico/:uid`: solo lo firmado y nada personal.
class CadenaPublica {
  CadenaPublica({
    required this.tipo,
    required this.uid,
    required this.organizacion,
    required this.cultivo,
    required this.exportacion,
    required this.lotes,
    required this.fincas,
  });

  factory CadenaPublica.desdeJson(Map<String, dynamic> j) {
    final x = j['exportacion'] as Map<String, dynamic>?;
    return CadenaPublica(
      tipo: j['tipo'] as String,
      uid: j['uid'] as String,
      organizacion: j['organizacion'] as String,
      cultivo: j['cultivo'] as String,
      exportacion: x == null
          ? null
          : ExportacionPublica(
              firma: Firma.desdeJson(x)!,
              contenedor: x['contenedor'] as String?,
              destino: x['destino'] as String,
              kg: _num(x['kg']),
              ddsRef: x['ddsRef'] as String?,
              fechaEmbarque: _fecha(x['fechaEmbarque']),
            ),
      lotes: [
        for (final l in (j['lotes'] as List).cast<Map<String, dynamic>>())
          LotePublico(
            firma: Firma.desdeJson(l),
            codigo: l['codigo'] as String,
            temporada: l['temporada'] as String,
            kg: _num(l['kg']),
            estado: l['estado'] as String,
            beneficio: l['beneficio'] as String,
            proceso: l['proceso'] as String?,
          ),
      ],
      fincas: [
        for (final f in (j['fincas'] as List).cast<Map<String, dynamic>>())
          FincaPublica(
            alias: f['alias'] as String,
            firma: Firma.desdeJson(f['firma']),
            version: f['version'] as int,
            areaHa: _num(f['areaHa']),
            lat: _num((f['ubicacion'] as Map)['lat']),
            lon: _num((f['ubicacion'] as Map)['lon']),
            deforestacion: f['deforestacion'] as String,
            chequeo: f['chequeo'] == null
                ? null
                : (
                    firma: Firma.desdeJson(f['chequeo'])!,
                    resultado: f['chequeo']['resultado'] as String,
                    fuente: f['chequeo']['fuente'] as String,
                    fecha: _fecha(f['chequeo']['fecha'])!,
                  ),
            visita: f['visita'] == null
                ? null
                : (
                    firma: Firma.desdeJson(f['visita'])!,
                    fecha: _fecha(f['visita']['fecha'])!,
                  ),
            kg: _num(f['kg']),
            entregas: [
              for (final e
                  in (f['entregas'] as List).cast<Map<String, dynamic>>())
                (
                  firma: Firma.desdeJson(e),
                  kg: _num(e['kg']),
                  estado: e['estado'] as String,
                  fecha: _fecha(e['fecha'])!,
                ),
            ],
          ),
      ],
    );
  }

  /// `Exportacion` (QR del contenedor) o `Lote` (QR del saco).
  final String tipo;
  final String uid;
  final String organizacion;
  final String cultivo;
  final ExportacionPublica? exportacion;
  final List<LotePublico> lotes;
  final List<FincaPublica> fincas;
}

class ExportacionPublica {
  ExportacionPublica({
    required this.firma,
    required this.contenedor,
    required this.destino,
    required this.kg,
    required this.ddsRef,
    required this.fechaEmbarque,
  });

  final Firma firma;
  final String? contenedor;
  final String destino;
  final double kg;
  final String? ddsRef;
  final DateTime? fechaEmbarque;
}

class LotePublico {
  LotePublico({
    required this.firma,
    required this.codigo,
    required this.temporada,
    required this.kg,
    required this.estado,
    required this.beneficio,
    required this.proceso,
  });

  final Firma? firma;
  final String codigo;
  final String temporada;
  final double kg;
  final String estado;
  final String beneficio;
  final String? proceso;
}

class FincaPublica {
  FincaPublica({
    required this.alias,
    required this.firma,
    required this.version,
    required this.areaHa,
    required this.lat,
    required this.lon,
    required this.deforestacion,
    required this.chequeo,
    required this.visita,
    required this.kg,
    required this.entregas,
  });

  /// "Finca 1", "Finca 2"…: sin nombre de la finca ni del productor.
  final String alias;
  final Firma? firma;
  final int version;
  final double areaHa;

  /// Redondeadas a ~1 km.
  final double lat;
  final double lon;
  final String deforestacion;
  final ({Firma firma, String resultado, String fuente, DateTime fecha})?
  chequeo;
  final ({Firma firma, DateTime fecha})? visita;
  final double kg;
  final List<({Firma? firma, double kg, String estado, DateTime fecha})>
  entregas;
}

/// Attestation leída directamente del contrato de EAS (`getAttestation`).
class AttestationEnCadena {
  AttestationEnCadena({
    required this.uid,
    required this.schema,
    required this.time,
    required this.revocationTime,
    required this.attester,
    required this.data,
  });

  /// Decodifica la respuesta ABI de `getAttestation(bytes32)`: una tupla
  /// dinámica (uid, schema, time, expirationTime, revocationTime, refUID,
  /// recipient, attester, revocable, data).
  factory AttestationEnCadena.decodificar(String hex) {
    final abi = Abi(hex);
    final t = abi.entero(0).toInt();
    final inicioData = t + abi.entero(9, t).toInt();
    final largo = abi.enteroEn(inicioData).toInt();
    return AttestationEnCadena(
      uid: abi.bytes32(0, t),
      schema: abi.bytes32(1, t),
      time: abi.entero(2, t).toInt(),
      revocationTime: abi.entero(4, t).toInt(),
      attester: '0x${abi.bytes32(7, t).substring(26)}',
      data: Abi.desdeBytes(abi.trozo(inicioData + 32, largo)),
    );
  }

  final String uid;
  final String schema;

  /// Segundos desde 1970.
  final int time;
  final int revocationTime;
  final String attester;
  final Abi data;

  bool get existe => uid != '0x${'0' * 64}';
}

/// Lector mínimo de datos ABI (palabras de 32 bytes, textos y bytes32[]).
class Abi {
  Abi(String hex) : _b = _hexABytes(hex);
  Abi.desdeBytes(this._b);

  final Uint8List _b;

  static Uint8List _hexABytes(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    return Uint8List.fromList([
      for (var i = 0; i + 1 < h.length; i += 2)
        int.parse(h.substring(i, i + 2), radix: 16),
    ]);
  }

  Uint8List trozo(int desde, int largo) =>
      Uint8List.sublistView(_b, desde, desde + largo);

  String _hex(Uint8List b) =>
      '0x${b.map((x) => x.toRadixString(16).padLeft(2, '0')).join()}';

  /// Palabra [i] (de 32 bytes) a partir del byte [base].
  BigInt entero(int i, [int base = 0]) => enteroEn(base + 32 * i);
  BigInt enteroEn(int byte) =>
      BigInt.parse(_hex(trozo(byte, 32)).substring(2), radix: 16);
  String bytes32(int i, [int base = 0]) => _hex(trozo(base + 32 * i, 32));

  /// `string` cuyo desplazamiento está en la palabra [i].
  String texto(int i) {
    final inicio = entero(i).toInt();
    final largo = enteroEn(inicio).toInt();
    return utf8.decode(trozo(inicio + 32, largo));
  }

  /// `bytes32[]` cuyo desplazamiento está en la palabra [i].
  List<String> listaBytes32(int i) {
    final inicio = entero(i).toInt();
    final n = enteroEn(inicio).toInt();
    return [for (var k = 0; k < n; k++) bytes32(k, inicio + 32)];
  }
}

/// Resultado de comparar lo que muestra la página con la blockchain.
class Comprobacion {
  Comprobacion({
    required this.existe,
    required this.firmanteOficial,
    required this.vigente,
    required this.esquemaCorrecto,
    required this.diferencias,
    required this.firmadaEn,
  });

  final bool existe;
  final bool firmanteOficial;

  /// No revocada.
  final bool vigente;
  final bool esquemaCorrecto;

  /// Datos de la página que no coinciden con lo firmado (vacío = todo igual).
  final List<String> diferencias;
  final DateTime? firmadaEn;

  bool get valida =>
      existe &&
      firmanteOficial &&
      vigente &&
      esquemaCorrecto &&
      diferencias.isEmpty;
}

/// Compara los datos de la API con lo firmado en la attestation escaneada.
Comprobacion comprobar(CadenaPublica c, AttestationEnCadena a) {
  if (!a.existe) {
    return Comprobacion(
      existe: false,
      firmanteOficial: false,
      vigente: false,
      esquemaCorrecto: false,
      diferencias: const [],
      firmadaEn: null,
    );
  }
  final d = a.data;
  final diferencias = <String>[];
  final esquemaCorrecto = a.schema.toLowerCase() == esquemaUid[c.tipo];
  void igual(String que, Object? pagina, Object? firmado) {
    if (pagina != firmado) diferencias.add(que);
  }

  // Texto ordenado: dos Set de Dart con lo mismo no son `==`.
  String conjunto(Iterable<String?> uids) => ([
    for (final u in uids)
      if (u != null) u.toLowerCase(),
  ]..sort()).join(',');
  // Los datos solo se leen con el esquema esperado; si no se pueden leer
  // (datos de otro tipo o mal formados), no coinciden.
  try {
    if (!esquemaCorrecto) {
      // Ya se reporta como tipo de registro equivocado.
    } else if (c.tipo == 'Exportacion' && c.exportacion != null) {
      final x = c.exportacion!;
      igual('cultivo', c.cultivo, d.texto(1));
      igual(
        'lotes',
        conjunto(c.lotes.map((l) => l.firma?.uid)),
        conjunto(d.listaBytes32(2)),
      );
      igual('kg', BigInt.from((x.kg * 100).round()), d.entero(3));
      igual('contenedor', x.contenedor ?? '', d.texto(4));
      igual('destino', x.destino, d.texto(5));
      igual('DDS', x.ddsRef ?? '', d.texto(6));
    } else if (c.tipo == 'Lote' && c.lotes.length == 1) {
      final l = c.lotes.single;
      igual('cultivo', c.cultivo, d.texto(1));
      igual('temporada', l.temporada, d.texto(2));
      igual(
        'entregas',
        conjunto(c.fincas.expand((f) => f.entregas).map((e) => e.firma?.uid)),
        conjunto(d.listaBytes32(3)),
      );
      igual('kg', BigInt.from((l.kg * 100).round()), d.entero(4));
      igual('estado', l.estado, d.texto(5));
      igual('beneficio', l.beneficio, d.texto(6));
      igual('proceso', l.proceso ?? '', d.texto(7));
    } else {
      diferencias.add('tipo');
    }
  } catch (_) {
    diferencias.add('datos');
  }
  return Comprobacion(
    existe: true,
    firmanteOficial: a.attester.toLowerCase() == atestadorOficial,
    vigente: a.revocationTime == 0,
    esquemaCorrecto: esquemaCorrecto,
    diferencias: diferencias,
    firmadaEn: DateTime.fromMillisecondsSinceEpoch(a.time * 1000),
  );
}

class NoEncontrado implements Exception {
  NoEncontrado(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Consulta la API (sin sesión) y, aparte, la blockchain por su RPC público,
/// para que el comprador no tenga que confiar solo en nuestra API.
class VerificadorService {
  VerificadorService({
    http.Client? cliente,
    String baseUrl = apiUrl,
    this.red = RedEas.actual,
  }) : _cliente = cliente ?? http.Client(),
       _base = Uri.parse(baseUrl);

  final http.Client _cliente;
  final Uri _base;
  final RedEas red;

  Future<CadenaPublica> cadena(String uid) async {
    final r = await _cliente.get(_base.resolve('/v1/publico/$uid'));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode == 404 || r.statusCode == 400) {
      throw NoEncontrado(
        (j as Map)['mensaje'] as String? ?? 'Código no encontrado.',
      );
    }
    if (r.statusCode != 200) {
      throw Exception('El servidor respondió ${r.statusCode}.');
    }
    return CadenaPublica.desdeJson(j as Map<String, dynamic>);
  }

  /// `getAttestation(uid)` directo al contrato de EAS.
  Future<AttestationEnCadena> attestation(String uid) async {
    final r = await _cliente.post(
      Uri.parse(red.rpc),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'eth_call',
        'params': [
          {'to': easAddress, 'data': '0xa3112a64${uid.substring(2)}'},
          'latest',
        ],
      }),
    );
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final resultado = j['result'];
    if (resultado is! String) {
      throw Exception('La blockchain no respondió: ${j['error']}');
    }
    return AttestationEnCadena.decodificar(resultado);
  }
}
